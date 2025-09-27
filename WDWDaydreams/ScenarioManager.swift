// ScenarioManager.swift
import Foundation
import Combine
import FirebaseFirestore

class ScenarioManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentStoryPrompt: DaydreamStory?
    @Published var storyHistory: [DaydreamStory] = []
    @Published var favorites: [DaydreamStory] = []
    @Published var enabledCategories: [Category] = [.park, .ride, .food] {
        didSet {
            if enabledCategories.isEmpty {
                print("⚠️ No categories enabled, reverting to defaults")
                enabledCategories = [.park, .ride, .food]
                return
            }
            if enabledCategories != oldValue {
                print("📝 Categories changed from \(oldValue.map{$0.rawValue}) to \(enabledCategories.map{$0.rawValue})")
                saveUserSettings()
                rebuildDeck()
            }
        }
    }
    @Published var tripDate: Date? {
        didSet {
            if tripDate != oldValue {
                print("📅 Trip date changed from \(oldValue?.description ?? "nil") to \(tripDate?.description ?? "nil")")
                saveUserSettings()
            }
        }
    }
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    private var deck: [DaydreamStory] = []
    private var deckIndex = 0
    private var firebaseService = FirebaseDataService.shared
    private var fcmService = FCMService.shared
    private var isGeneratingPrompt = false

    // --- FIX: Add properties to hold the listeners ---
    private var historyListener: ListenerRegistration?
    private var promptListener: ListenerRegistration?
    private var completionListener: ListenerRegistration?
    
    // MARK: - Initialization & Setup
    
    init() {
        print("🚀 ScenarioManager initializing...")
        fetchUserSettings()
        rebuildDeck()
        fetchFavorites()
        setupListeners() // Moved setupListeners here to attach them right away
    }
    
    deinit {
        // --- FIX: Ensure all listeners are removed ---
        historyListener?.remove()
        promptListener?.remove()
        completionListener?.remove()
    }
    
    private func setupListeners() {
        // --- FIX: Call the new 'listen' methods instead of 'fetch' ---
        historyListener = firebaseService.listenForStoryHistory { [weak self] stories in
            DispatchQueue.main.async {
                self?.storyHistory = stories
                
                // Also update the current prompt if it's part of the new history
                if let todayStory = stories.first(where: { $0.isToday }) {
                    self?.currentStoryPrompt = todayStory
                }
            }
        }

        promptListener = firebaseService.listenForDailyPrompt { [weak self] prompt in
            DispatchQueue.main.async {
                if let prompt = prompt {
                    self?.currentStoryPrompt = prompt
                } else {
                    // If no prompt exists for today, generate one
                    if self?.currentStoryPrompt == nil || !(self?.currentStoryPrompt?.isToday ?? false) {
                        self?.generateOrUpdateDailyPrompt()
                    }
                }
            }
        }

        completionListener = firebaseService.listenForStoryCompletion { authorName in
            NotificationManager.shared.sendLocalCompletionNotification(from: authorName)
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
        
        deck = combos.map { values in
            var dict: [Category: String] = [:]
            for (i, cat) in cats.enumerated() {
                dict[cat] = values[i]
            }
            
            return DaydreamStory(
                dateAssigned: Date(),
                items: dict,
                assignedAuthor: .user
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
    
    func next() {
        guard !isGeneratingPrompt else {
            print("⏳ Already generating a prompt, skipping...")
            return
        }
        
        isGeneratingPrompt = true
        isLoading = true
        
        print("🎲 Generating new prompt...")
        guard !deck.isEmpty else {
            print("❌ Deck is empty, rebuilding...")
            rebuildDeck()
            guard !deck.isEmpty else {
                print("❌ Still no deck after rebuild")
                isGeneratingPrompt = false
                isLoading = false
                return
            }
            return
        }
        
        if deckIndex >= deck.count {
            print("🔄 Reached end of deck, shuffling...")
            deck.shuffle()
            deckIndex = 0
        }
        
        var story = deck[deckIndex]
        deckIndex += 1
        
        story.dateAssigned = Date()
        
        print("🎯 Generated story with items: \(story.items)")
        
        firebaseService.determineNextAuthor { [weak self] nextAuthor in
            guard let self = self else { return }
            
            story.assignedAuthor = nextAuthor
            print("👤 Assigned to: \(nextAuthor.displayName)")
            
            DispatchQueue.main.async {
                self.currentStoryPrompt = story
                self.isLoading = false
                self.isGeneratingPrompt = false
            }
            
            self.firebaseService.saveDailyPrompt(story) { success in
                if !success {
                    print("❌ Failed to save daily prompt")
                } else {
                    print("✅ Daily prompt saved to Firebase")
                    
                    // Send FCM notification to partner about new prompt
                    let promptPreview = story.promptText
                    self.fcmService.notifyPartnerOfNewPrompt(
                        assignedAuthor: nextAuthor.displayName,
                        promptPreview: promptPreview
                    )
                }
            }
            
            self.firebaseService.saveStory(story, toCollection: "history") { success in
                if !success {
                    print("❌ Failed to save story to history")
                } else {
                    print("✅ Story saved to history collection")
                }
            }
        }
    }
    
    // MARK: - User Settings
    
    private func fetchUserSettings() {
        print("⚙️ Fetching user settings...")
        firebaseService.fetchUserSettings { [weak self] categories, tripDate in
            DispatchQueue.main.async {
                if self?.enabledCategories != categories {
                    self?.enabledCategories = categories
                    print("✅ Categories loaded: \(categories.map { $0.rawValue })")
                }
                
                if self?.tripDate != tripDate {
                    self?.tripDate = tripDate
                    print("✅ Trip date loaded: \(tripDate?.description ?? "nil")")
                }
            }
        }
    }
    
    private func saveUserSettings() {
        firebaseService.saveUserSettings(enabledCategories: enabledCategories, tripDate: tripDate) { success in
            if !success {
                print("❌ Failed to save user settings")
            } else {
                print("✅ User settings saved")
            }
        }
    }
    
    // MARK: - Story History & Favorites
    
    func fetchFavorites() {
        firebaseService.fetchFavorites { [weak self] favStories in
            DispatchQueue.main.async {
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
                    DispatchQueue.main.async {
                        if !(self?.favorites.contains(where: { $0.id == story.id }) ?? true) {
                            self?.favorites.insert(story, at: 0)
                        }
                    }
                }
            }
        } else {
            firebaseService.removeFavorite(storyId: story.id) { [weak self] success in
                if success {
                    DispatchQueue.main.async {
                        self?.favorites.removeAll { $0.id == story.id }
                    }
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
                    DispatchQueue.main.async {
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
    }
    
    func clearHistory() {
        firebaseService.clearStoryHistory { [weak self] success in
            if success {
                DispatchQueue.main.async {
                    if let currentPrompt = self?.currentStoryPrompt {
                        self?.storyHistory = [currentPrompt]
                    } else {
                        self?.storyHistory = []
                    }
                }
            }
        }
    }
    
    // MARK: - Daily Prompt Management
    
    func generateOrUpdateDailyPrompt() {
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
        next()
    }
    
    // MARK: - Story Writing
    
    func saveStoryText(_ text: String, for storyId: UUID) {
        guard !text.isEmpty else { return }
        
        print("💾 Saving story text for story: \(storyId)")
        
        if let index = storyHistory.firstIndex(where: { $0.id == storyId }) {
            var storyToUpdate = storyHistory[index]
            storyToUpdate.storyText = text
            
            // This now triggers the notification in FirebaseDataService
            firebaseService.markStoryAsCompleted(storyToUpdate) { [weak self] success in
                if success {
                    print("✅ Story marked as completed and updated in shared stories")
                    
                    // Send FCM notification to partner about story completion
                    self?.fcmService.notifyPartnerOfStoryCompletion(
                        authorName: storyToUpdate.assignedAuthor.displayName,
                        storyPrompt: storyToUpdate.promptText
                    )
                } else {
                    print("❌ Failed to mark story as completed")
                }
            }
        }
    }
    
    // MARK: - Public Helpers
    
    func isCurrentUsersTurn() -> Bool {
        guard let prompt = currentStoryPrompt else { return false }
        
        let isJon = firebaseService.isCurrentUserJon
        
        return (isJon && prompt.assignedAuthor == .user) ||
               (!isJon && prompt.assignedAuthor == .wife)
    }
}
