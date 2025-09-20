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
            saveUserSettings()
            rebuildDeck()
        }
    }
    @Published var tripDate: Date?
    
    // MARK: - Private Properties
    private var deck: [DaydreamStory] = []
    private var deckIndex = 0
    private var firebaseService = FirebaseDataService.shared
    private var historyListener: ListenerRegistration?
    private var completionListener: ListenerRegistration?
    
    // MARK: - Initialization & Setup
    
    init() {
        fetchUserSettings()
        rebuildDeck()
        fetchStoryHistory()
        fetchFavorites()
        generateOrUpdateDailyPrompt()
        setupListeners()
    }
    
    deinit {
        historyListener?.remove()
        completionListener?.remove()
    }
    
    private func setupListeners() {
        // Listen for changes in shared stories
        historyListener = firebaseService.listenForSharedStoryChanges {
            self.fetchStoryHistory()
        }
        
        // Listen for story completion by the other user
        completionListener = firebaseService.listenForStoryCompletion { authorName in
            NotificationManager.shared.sendLocalCompletionNotification(from: authorName)
        }
    }
    
    // MARK: - Deck Management
    
    private func rebuildDeck() {
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
    }
    
    private func cartesianProduct<T>(_ arrays: [[T]]) -> [[T]] {
        guard let first = arrays.first else { return [[]] }
        let rest = Array(arrays.dropFirst())
        let restProd = cartesianProduct(rest)
        return first.flatMap { x in restProd.map { [x] + $0 } }
    }
    
    /// Generate a new prompt and move to the next item in the deck
    func next() {
        guard !deck.isEmpty else { return }
        
        if deckIndex >= deck.count {
            deck.shuffle()
            deckIndex = 0
        }
        
        var story = deck[deckIndex]
        deckIndex += 1
        
        // Set the current date
        story.dateAssigned = Date()
        
        // Determine whose turn it is next
        firebaseService.determineNextAuthor { nextAuthor in
            story.assignedAuthor = nextAuthor
            
            // Update the current prompt and local history
            DispatchQueue.main.async {
                self.currentStoryPrompt = story
                self.storyHistory.insert(story, at: 0)
            }
            
            // Save to Firebase
            self.firebaseService.saveDailyPrompt(story) { success in
                if !success {
                    print("Failed to save daily prompt")
                }
            }
            
            // Save to history collection
            self.firebaseService.saveStory(story, toCollection: "history") { success in
                if !success {
                    print("Failed to save story to history")
                }
            }
        }
    }
    
    // MARK: - User Settings
    
    private func fetchUserSettings() {
        firebaseService.fetchUserSettings { categories in
            DispatchQueue.main.async {
                self.enabledCategories = categories
            }
        }
    }
    
    private func saveUserSettings() {
        firebaseService.saveUserSettings(enabledCategories: enabledCategories) { success in
            if !success {
                print("Failed to save user settings")
            }
        }
    }
    
    // MARK: - Story History & Favorites
    
    func fetchStoryHistory() {
        firebaseService.fetchStoryHistory { stories in
            DispatchQueue.main.async {
                self.storyHistory = stories
            }
        }
    }
    
    func fetchFavorites() {
        firebaseService.fetchFavorites { favStories in
            DispatchQueue.main.async {
                self.favorites = favStories
            }
        }
    }
    
    func toggleFavorite() {
        guard var story = currentStoryPrompt else { return }
        
        story.isFavorite.toggle()
        
        if story.isFavorite {
            // Add to favorites
            firebaseService.saveStory(story, toCollection: "favorites") { success in
                if success {
                    DispatchQueue.main.async {
                        // Add to local favorites if not already there
                        if !self.favorites.contains(where: { $0.id == story.id }) {
                            self.favorites.insert(story, at: 0)
                        }
                    }
                }
            }
        } else {
            // Remove from favorites
            firebaseService.removeFavorite(storyId: story.id) { success in
                if success {
                    DispatchQueue.main.async {
                        // Remove from local favorites
                        self.favorites.removeAll { $0.id == story.id }
                    }
                }
            }
        }
        
        // Update in history
        if let index = storyHistory.firstIndex(where: { $0.id == story.id }) {
            storyHistory[index].isFavorite = story.isFavorite
        }
        
        // Update current prompt
        currentStoryPrompt = story
    }
    
    func removeFavorite(at offsets: IndexSet) {
        // Get the stories to be removed
        let storiesToRemove = offsets.map { favorites[$0] }
        
        // Remove from Firestore and update local state
        for story in storiesToRemove {
            firebaseService.removeFavorite(storyId: story.id) { success in
                if success {
                    DispatchQueue.main.async {
                        // Update isFavorite in history
                        if let index = self.storyHistory.firstIndex(where: { $0.id == story.id }) {
                            self.storyHistory[index].isFavorite = false
                        }
                        
                        // Update current prompt if needed
                        if self.currentStoryPrompt?.id == story.id {
                            self.currentStoryPrompt?.isFavorite = false
                        }
                    }
                }
            }
        }
        
        // Remove from the local favorites array
        favorites.remove(atOffsets: offsets)
    }
    
    func clearHistory() {
        firebaseService.clearStoryHistory { success in
            if success {
                DispatchQueue.main.async {
                    // Keep today's prompt in history if it exists
                    if let currentPrompt = self.currentStoryPrompt {
                        self.storyHistory = [currentPrompt]
                    } else {
                        self.storyHistory = []
                    }
                }
            }
        }
    }
    
    // MARK: - Daily Prompt Management
    
    func generateOrUpdateDailyPrompt() {
        // First check locally if we already have today's prompt
        if let existingPrompt = storyHistory.first(where: { $0.isToday }) {
            DispatchQueue.main.async {
                self.currentStoryPrompt = existingPrompt
            }
            return
        }
        
        // If not found locally, check Firestore
        firebaseService.fetchDailyPrompt { prompt in
            if let prompt = prompt {
                // Found today's prompt
                DispatchQueue.main.async {
                    self.currentStoryPrompt = prompt
                    // Add to history if not already there
                    if !self.storyHistory.contains(where: { $0.isToday }) {
                        self.storyHistory.insert(prompt, at: 0)
                    }
                }
            } else {
                // No prompt for today, create a new one
                self.next()
            }
        }
    }
    
    // MARK: - Story Writing
    
    func saveStoryText(_ text: String, for storyId: UUID) {
        guard !text.isEmpty else { return }
        
        // Update in-memory models
        if let index = storyHistory.firstIndex(where: { $0.id == storyId }) {
            storyHistory[index].storyText = text
            
            if currentStoryPrompt?.id == storyId {
                currentStoryPrompt?.storyText = text
            }
            
            if let favIndex = favorites.firstIndex(where: { $0.id == storyId }) {
                favorites[favIndex].storyText = text
            }
            
            // Mark as completed and update shared stories
            let story = storyHistory[index]
            firebaseService.markStoryAsCompleted(story) { success in
                if success {
                    // Force a refresh of the story history
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.fetchStoryHistory()
                    }
                }
            }
        }
    }
    
    // MARK: - Public Helpers
    
    /// Check if it's the current user's turn to write the story
    func isCurrentUsersTurn() -> Bool {
        guard let prompt = currentStoryPrompt else { return false }
        
        let isJon = firebaseService.isCurrentUserJon
        
        return (isJon && prompt.assignedAuthor == .user) ||
               (!isJon && prompt.assignedAuthor == .wife)
    }
}
