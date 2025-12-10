// ScenarioManager.swift
import Foundation
import Combine
import FirebaseFirestore

@MainActor
class ScenarioManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentStoryPrompt: DaydreamStory?
    @Published var storyHistory: [DaydreamStory] = []
    @Published var favorites: [DaydreamStory] = []
    @Published var selectedPartnership: StoryPartnership?
    @Published var userPartnerships: [StoryPartnership] = []
    @Published var partnerProfiles: [String: UserProfile] = [:] // Map of userId to profile
    @Published var enabledCategories: [Category] = [.park, .ride, .food] {
        didSet {
            if enabledCategories.isEmpty {
                print("⚠️ No categories enabled, reverting to defaults")
                enabledCategories = [.park, .ride, .food]
                return
            }
            if enabledCategories != oldValue {
                print("📝 Categories changed from \(oldValue.map{$0.rawValue}) to \(enabledCategories.map{$0.rawValue})")
                savePartnershipSettings()
                rebuildDeck()
            }
        }
    }

    // MARK: - Achievements
    func checkAndAwardBadges() async {
        guard !currentUserId.isEmpty else { return }

        var toAward: [String] = []

        if totalStoriesCount >= 1 { toAward.append("first_story") }
        if totalStoriesCount >= 10 { toAward.append("ten_stories") }
        if currentStreak >= 7 { toAward.append("week_streak") }

        do {
            if let profile = try await userService.getUserProfile(userId: currentUserId) {
                var updatedAchievements = profile.achievements
                var changed = false
                for id in toAward {
                    if !updatedAchievements.contains(id) {
                        updatedAchievements.append(id)
                        changed = true
                    }
                }

                if changed {
                    // Build a new UserProfile with updated achievements and save
                    let updatedProfile = UserProfile(id: profile.id,
                                                     email: profile.email,
                                                     displayName: profile.displayName,
                                                     avatarURL: profile.avatarURL,
                                                     bio: profile.bio,
                                                     createdAt: profile.createdAt,
                                                     connectionIds: profile.connectionIds,
                                                     pendingInvitations: profile.pendingInvitations,
                                                     achievements: updatedAchievements,
                                                     preferences: profile.preferences)

                    try await userService.updateUserProfile(updatedProfile)

                    // Notify user about new badge(s)
                    let newly = toAward.filter { updatedAchievements.contains($0) }
                    if !newly.isEmpty {
                        let names = newly.map { id in Badge.allBadges.first(where: { $0.id == id })?.name ?? id }
                        let message = "Achievement unlocked: \(names.joined(separator: ", "))"
                        UIFeedbackCenter.shared.present(message: message, style: .success)
                    }
                }
            }
        } catch {
            print("⚠️ Failed to check/award badges: \(error)")
        }
    }
    @Published var tripDate: Date? {
        didSet {
            if tripDate != oldValue {
                print("📅 Trip date changed from \(oldValue?.description ?? "nil") to \(tripDate?.description ?? "nil")")
                savePartnershipSettings()
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var isLoadingPartnership: Bool = false

    // MARK: - Private Properties
    private var deck: [DaydreamStory] = []
    private var deckIndex = 0
    private var firebaseService = FirebaseDataService.shared
    private var palsService = PalsService()
    private var userService = UserService()
    private var fcmService = FCMService.shared
    private var isGeneratingPrompt = false
    private var currentUserId: String = ""

    // Consolidated listener for better performance
    private var dataListener: ListenerRegistration?

    private let completionNotificationDefaultsKey = "ScenarioManagerCompletionNotificationCache"
    private var completionNotificationCache: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(completionNotificationCache), forKey: completionNotificationDefaultsKey)
        }
    }
    private lazy var completionNotificationDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay]
        return formatter
    }()

    // MARK: - Initialization & Setup

    init() {
        print("🚀 ScenarioManager initializing...")
        loadCompletionNotificationCache()
    }

    deinit {
        // Clean up listeners
        dataListener?.remove()
    }

    func initialize(userId: String) async {
        self.currentUserId = userId
        await loadPartnerships()
        fetchFavorites()

        // If user has partnerships, select the first one by default
        if let firstPartnership = userPartnerships.first {
            await selectPartnership(firstPartnership)
        }
    }

    func loadPartnerships() async {
        guard !currentUserId.isEmpty else { return }

        do {
            userPartnerships = try await palsService.getUserPartnerships(userId: currentUserId)
            print("✅ Loaded \(userPartnerships.count) partnerships")

            // Load partner profiles
            for partnership in userPartnerships {
                if let partnerId = partnership.getPartnerId(for: currentUserId) {
                    if partnerProfiles[partnerId] == nil {
                        if let profile = try await userService.getUserProfile(userId: partnerId) {
                            partnerProfiles[partnerId] = profile
                        }
                    }
                }
            }
        } catch {
            print("❌ Error loading partnerships: \(error)")
        }
    }

    func selectPartnership(_ partnership: StoryPartnership) async {
        print("🔄 Selecting partnership...")
        isLoadingPartnership = true

        selectedPartnership = partnership

        // Load settings from partnership
        enabledCategories = partnership.enabledCategories.compactMap { Category(rawValue: $0) }
        if enabledCategories.isEmpty {
            enabledCategories = [.park, .ride, .food]
        }
        tripDate = partnership.sharedTripDate

        rebuildDeck()
        setupOptimizedListeners(for: partnership.id)
        fetchPartnershipStories(partnershipId: partnership.id)
        await generateOrUpdateDailyPrompt()

        isLoadingPartnership = false
        print("✅ Partnership selection complete")
    }

    private func setupOptimizedListeners(for partnershipId: String) {
        // Remove old listener
        dataListener?.remove()

        // Single listener for partnership stories with debouncing
        var lastProcessedTime = Date()
        let debounceInterval: TimeInterval = 0.5

        dataListener = firebaseService.getFirestoreReference()
            .collection("partnerships")
            .document(partnershipId)
            .collection("stories")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Error listening for partnership stories: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("❌ No documents found in partnership stories")
                    return
                }

                let now = Date()
                if now.timeIntervalSince(lastProcessedTime) < debounceInterval {
                    print("🔄 Debouncing rapid changes...")
                    return
                }
                lastProcessedTime = now

                print("📄 [Optimized] Received \(documents.count) partnership story documents")

                let stories = documents.compactMap { doc -> DaydreamStory? in
                    let data = doc.data()
                    guard let dateTimestamp = data["date"] as? Timestamp,
                          let itemsDict = data["items"] as? [String: String] else {
                        print("⚠️ Missing required fields in document: \(doc.documentID)")
                        return nil
                    }

                    var items: [Category: String] = [:]
                    for (key, value) in itemsDict {
                        if let category = Category(rawValue: key) {
                            items[category] = value
                        }
                    }

                    // Get author
                    let author: StoryAuthor
                    if let authorId = data["authorId"] as? String,
                       let authorName = data["authorName"] as? String {
                        author = StoryAuthor(userId: authorId, displayName: authorName)
                    } else if let legacyAuthor = data["author"] as? String {
                        author = StoryAuthor(legacyValue: legacyAuthor) ?? StoryAuthor(userId: "unknown", displayName: "Unknown")
                    } else {
                        author = StoryAuthor(userId: self.currentUserId, displayName: self.firebaseService.currentUserDisplayName)
                    }

                    // Get version and lastModified for optimistic locking
                    let version = data["version"] as? Int
                    let lastModified = (data["lastModified"] as? Timestamp)?.dateValue()

                    return DaydreamStory(
                        id: UUID(),
                        dateAssigned: dateTimestamp.dateValue(),
                        items: items,
                        assignedAuthor: author,
                        partnershipId: partnershipId,
                        storyText: data["text"] as? String,
                        isFavorite: false,
                        lastModified: lastModified,
                        version: version
                    )
                }

                Task { @MainActor in
                    self.storyHistory = stories

                    // Update current prompt if it's part of today's stories
                    if let todayStory = stories.first(where: { $0.isToday }) {
                        self.currentStoryPrompt = todayStory
                    }

                    // Check for story completions (for notifications)
                    self.checkForNewCompletions(in: stories)
                }
            }
    }

    private func checkForNewCompletions(in stories: [DaydreamStory]) {
        // Find recently completed stories by partner
        let recentCompletions = stories.filter { story in
            story.isWritten &&
            story.assignedAuthor.userId != currentUserId &&
            Calendar.current.isDateInToday(story.dateAssigned)
        }

        if let latestCompletion = recentCompletions.first(where: { completion in
            let key = completionNotificationKey(for: completion)
            return !completionNotificationCache.contains(key)
        }) {
            let key = completionNotificationKey(for: latestCompletion)
            NotificationManager.shared.sendLocalCompletionNotification(from: latestCompletion.assignedAuthor.displayName)
            completionNotificationCache.insert(key)

            // Trigger haptic feedback
            HapticManager.instance.notification(type: .success)
        }
    }

    // MARK: - Deck Management

    private func rebuildDeck() {
        guard !enabledCategories.isEmpty else {
            print("⚠️ Cannot rebuild deck with no categories")
            return
        }

        print("🔄 Rebuilding deck with categories: \(enabledCategories.map { $0.rawValue })")
        let cats = enabledCategories
        let lists = cats.map { DataModel.shared.list(for: $0) }
        let combos = cartesianProduct(lists)

        guard let partnership = selectedPartnership else {
            print("⚠️ No partnership selected")
            return
        }

        let currentAuthor = StoryAuthor(
            userId: currentUserId,
            displayName: firebaseService.currentUserDisplayName
        )

        deck = combos.map { values in
            var dict: [Category: String] = [:]
            for (i, cat) in cats.enumerated() {
                dict[cat] = values[i]
            }

            return DaydreamStory(
                dateAssigned: Date(),
                items: dict,
                assignedAuthor: currentAuthor,
                partnershipId: partnership.id
            )
        }

        deck.shuffle()
        deckIndex = 0
        print("🎯 Deck rebuilt with \(deck.count) combinations")
    }

    private func cartesianProduct<T>(_ arrays: [[T]]) -> [[T]] {
        guard let first = arrays.first else { return [[]] }
        let rest = Array(arrays.dropFirst())
        let restProd = cartesianProduct(rest)
        return first.flatMap { x in restProd.map { [x] + $0 } }
    }

    func next() async {
        guard !isGeneratingPrompt else {
            print("⏳ Already generating a prompt, skipping...")
            return
        }

        guard let partnership = selectedPartnership else {
            print("❌ No partnership selected")
            return
        }

        guard let partnerId = partnership.getPartnerId(for: currentUserId),
              let partnerProfile = partnerProfiles[partnerId] else {
            print("❌ Partner profile not found")
            return
        }

        isGeneratingPrompt = true
        isLoading = true

        print("🎲 Generating new prompt...")

        // Ensure we have a deck
        if deck.isEmpty {
            print("❌ Deck is empty, rebuilding...")
            rebuildDeck()

            // Check if rebuild was successful
            if deck.isEmpty {
                print("❌ Still no deck after rebuild")
                isGeneratingPrompt = false
                isLoading = false
                return
            }
        }

        // Reset deck if we've used all cards
        if deckIndex >= deck.count {
            print("🔄 Reached end of deck, shuffling...")
            deck.shuffle()
            deckIndex = 0
        }

        var story = deck[deckIndex]
        deckIndex += 1

        story.dateAssigned = Date()
        story.partnershipId = partnership.id

        print("🎯 Generated story with items: \(story.items)")

        firebaseService.determineNextAuthor(
            partnership: partnership,
            currentUserId: currentUserId,
            partnerProfile: partnerProfile
        ) { nextAuthor in
            Task { @MainActor in
                story.assignedAuthor = nextAuthor
                print("👤 Assigned to: \(nextAuthor.displayName)")

                self.currentStoryPrompt = story
                self.isLoading = false
                self.isGeneratingPrompt = false

                self.firebaseService.saveDailyPrompt(story, partnershipId: partnership.id) { success in
                    if !success {
                        print("❌ Failed to save daily prompt")
                    } else {
                        print("✅ Daily prompt saved to Firebase")

                        // Send FCM notification to partner about new prompt
                        let promptPreview = story.promptText
                        self.fcmService.notifyPartnerOfNewPrompt(
                            assignedAuthor: nextAuthor.displayName,
                            promptPreview: promptPreview,
                            partnerUserId: partnerId
                        )

                        // Trigger haptic feedback
                        HapticManager.instance.impact(style: .medium)
                    }
                }
            }
        }
    }

    // MARK: - Partnership Settings

    private func savePartnershipSettings() {
        guard let partnership = selectedPartnership else { return }

        var updatedPartnership = partnership
        updatedPartnership.enabledCategories = enabledCategories.map { $0.rawValue }
        updatedPartnership.sharedTripDate = tripDate

        Task {
            do {
                try await palsService.updatePartnership(updatedPartnership)
                print("✅ Partnership settings saved")
            } catch {
                print("❌ Failed to save partnership settings: \(error)")
            }
        }
    }

    // MARK: - Story History & Favorites

    func fetchPartnershipStories(partnershipId: String) {
        firebaseService.fetchPartnershipStories(partnershipId: partnershipId) { [weak self] stories in
            Task { @MainActor in
                self?.storyHistory = stories
                print("✅ Loaded \(stories.count) partnership stories")
            }
        }
    }

    func fetchFavorites() {
        firebaseService.fetchFavorites { [weak self] favStories in
            Task { @MainActor in
                self?.favorites = favStories
                print("⭐ Loaded \(favStories.count) favorite stories")
            }
        }
    }

    func toggleFavorite() {
        guard var story = currentStoryPrompt else { return }

        story.isFavorite.toggle()

        if story.isFavorite {
            firebaseService.saveStory(story, toCollection: "favorites") { [weak self] success in
                if success {
                    Task { @MainActor in
                        if !(self?.favorites.contains(where: { $0.id == story.id }) ?? true) {
                            self?.favorites.insert(story, at: 0)
                        }
                    }

                    // Trigger haptic feedback
                    HapticManager.instance.impact(style: .light)
                }
            }
        } else {
            firebaseService.removeFavorite(storyId: story.id) { [weak self] success in
                if success {
                    Task { @MainActor in
                        self?.favorites.removeAll { $0.id == story.id }
                    }

                    // Trigger haptic feedback
                    HapticManager.instance.impact(style: .light)
                }
            }
        }

        if let index = storyHistory.firstIndex(where: { $0.id == story.id }) {
            storyHistory[index].isFavorite = story.isFavorite
        }

        currentStoryPrompt = story
    }

    func removeFavorite(at offsets: IndexSet) {
        let storiesToRemove = offsets.map { favorites[$0] }

        for story in storiesToRemove {
            firebaseService.removeFavorite(storyId: story.id) { [weak self] success in
                if success {
                    Task { @MainActor in
                        if let index = self?.storyHistory.firstIndex(where: { $0.id == story.id }) {
                            self?.storyHistory[index].isFavorite = false
                        }

                        if self?.currentStoryPrompt?.id == story.id {
                            self?.currentStoryPrompt?.isFavorite = false
                        }
                    }
                }
            }
        }

        favorites.remove(atOffsets: offsets)

        // Trigger haptic feedback
        HapticManager.instance.impact(style: .light)
    }

    func clearHistory() {
        guard let partnershipId = selectedPartnership?.id else { return }

        firebaseService.clearStoryHistory(partnershipId: partnershipId) { [weak self] success in
            if success {
                Task { @MainActor in
                    if let currentPrompt = self?.currentStoryPrompt {
                        self?.storyHistory = [currentPrompt]
                    } else {
                        self?.storyHistory = []
                    }
                }

                // Trigger haptic feedback
                HapticManager.instance.notification(type: .warning)
            }
        }
    }

    // MARK: - Daily Prompt Management

    func generateOrUpdateDailyPrompt() async {
        guard !isGeneratingPrompt else {
            print("⏳ Already generating/updating prompt, skipping...")
            return
        }

        print("🔍 Checking for today's prompt...")

        if storyHistory.first(where: { $0.isToday }) != nil {
             print("✅ Prompt already exists for today.")
             return
        }

        print("🆕 No prompt for today, creating new one...")
        resetCompletionNotificationCache()
        await next()
    }

    // MARK: - Story Writing

    func saveStoryText(_ text: String, for storyId: UUID) {
        guard !text.isEmpty else { return }
        guard let partnershipId = selectedPartnership?.id else {
            print("❌ No partnership selected")
            return
        }

        print("💾 Saving story text for story: \(storyId)")

        if let index = storyHistory.firstIndex(where: { $0.id == storyId }) {
            // Keep a copy of the original story for rollback
            let originalStory = storyHistory[index]

            var storyToUpdate = storyHistory[index]
            storyToUpdate.storyText = text

            // Update local state immediately for better UX
            Task { @MainActor in
                self.storyHistory[index] = storyToUpdate
                if self.currentStoryPrompt?.id == storyId {
                    self.currentStoryPrompt = storyToUpdate
                }
            }

            // This triggers the notification in FirebaseDataService
            firebaseService.markStoryAsCompleted(storyToUpdate, partnershipId: partnershipId) { [weak self] success, errorMessage in
                if success {
                    print("✅ Story marked as completed and updated in partnership stories")

                    // Get partner ID for notification
                    if let partnership = self?.selectedPartnership,
                       let partnerId = partnership.getPartnerId(for: self?.currentUserId ?? "") {
                        // Send FCM notification to partner about story completion
                        self?.fcmService.notifyPartnerOfStoryCompletion(
                            authorName: storyToUpdate.assignedAuthor.displayName,
                            storyPrompt: storyToUpdate.promptText,
                            partnerUserId: partnerId
                        )
                    }

                    // Trigger haptic feedback
                    HapticManager.instance.notification(type: .success)
                    Task {
                        await self?.checkAndAwardBadges()
                    }
                } else {
                    print("❌ Failed to mark story as completed: \(errorMessage ?? "unknown error")")

                    // Trigger haptic feedback
                    HapticManager.instance.notification(type: .error)

                    DispatchQueue.main.async {
                        // Check if this is a conflict error
                        if errorMessage == "conflict" {
                            // Conflict - show special message
                            UIFeedbackCenter.shared.present(
                                message: "Your partner updated this story at the same time. Please refresh and try again.",
                                style: .warning
                            )

                            // Refresh to get latest version
                            Task {
                                await self?.refreshPartnershipData()
                            }
                        } else {
                            // Regular error handling
                            UIFeedbackCenter.shared.present(
                                message: "Failed to save story. Please check your connection and try again.",
                                style: .error
                            )
                        }

                        // Revert optimistic update
                        if let index = self?.storyHistory.firstIndex(where: { $0.id == storyToUpdate.id }) {
                            self?.storyHistory[index] = originalStory
                        }

                        // Also revert currentStoryPrompt if it was updated
                        if self?.currentStoryPrompt?.id == storyToUpdate.id {
                            self?.currentStoryPrompt = originalStory
                        }
                    }
                }
            }
        }
    }

    // MARK: - Public Helpers

    @MainActor
    func refreshPartnershipData() async {
        guard let partnership = selectedPartnership else { return }

        print("🔄 Refreshing partnership data...")
        isLoading = true

        // Re-fetch stories for current partnership
        fetchPartnershipStories(partnershipId: partnership.id)

        // Regenerate prompt if needed
        await generateOrUpdateDailyPrompt()

        isLoading = false
        print("✅ Partnership data refreshed")
    }

    @MainActor
    func refreshUserPartnerships() async {
        guard !currentUserId.isEmpty else { return }

        print("🔄 Refreshing user partnerships...")

        do {
            userPartnerships = try await palsService.getUserPartnerships(userId: currentUserId)
            print("✅ Refreshed \(userPartnerships.count) partnerships")

            // Reload partner profiles
            for partnership in userPartnerships {
                if let partnerId = partnership.getPartnerId(for: currentUserId) {
                    if partnerProfiles[partnerId] == nil {
                        if let profile = try await userService.getUserProfile(userId: partnerId) {
                            partnerProfiles[partnerId] = profile
                        }
                    }
                }
            }
        } catch {
            print("❌ Error refreshing partnerships: \(error)")
        }
    }

    // MARK: - Computed Stats
    var totalStoriesCount: Int {
        storyHistory.count
    }

    var totalWordsWritten: Int {
        storyHistory.compactMap { $0.storyText }
            .reduce(0) { $0 + $1.split(whereSeparator: { $0.isWhitespace }).count }
    }

    var favoriteCategory: String {
        var counts: [String: Int] = [:]
        for story in storyHistory {
            for (_, value) in story.items {
                counts[value, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? "None"
    }

    var currentStreak: Int {
        let sorted = storyHistory.sorted { $0.dateAssigned > $1.dateAssigned }
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())

        for story in sorted {
            let storyDay = Calendar.current.startOfDay(for: story.dateAssigned)
            if storyDay == checkDate || Calendar.current.dateComponents([.day], from: storyDay, to: checkDate).day == 1 {
                streak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if storyDay < checkDate {
                break
            }
        }

        return streak
    }

    func isCurrentUsersTurn() -> Bool {
        guard let prompt = currentStoryPrompt else { return false }
        return prompt.assignedAuthor.userId == currentUserId
    }
}

// MARK: - Notification Cache Helpers
extension ScenarioManager {
    private func loadCompletionNotificationCache() {
        if let storedKeys = UserDefaults.standard.array(forKey: completionNotificationDefaultsKey) as? [String] {
            completionNotificationCache = Set(storedKeys)
        }
    }

    private func resetCompletionNotificationCache() {
        completionNotificationCache.removeAll()
    }

    private func completionNotificationKey(for story: DaydreamStory) -> String {
        let startOfDay = Calendar.current.startOfDay(for: story.dateAssigned)
        return completionNotificationDateFormatter.string(from: startOfDay)
    }
}
