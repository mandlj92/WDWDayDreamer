// Services/FirebaseDataService.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth

// Add DateFormatter extension for the shared instance
extension DateFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// A service class responsible for handling Firebase operations
class FirebaseDataService {
    static let shared = FirebaseDataService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - User Helpers
    
    var userId: String {
        Auth.auth().currentUser?.uid ?? "unknown"
    }
    
    var currentUserEmail: String {
        Auth.auth().currentUser?.email ?? ""
    }
    
    var isCurrentUserJon: Bool {
        let email = currentUserEmail.lowercased()
        return email.contains("jon") || email.contains("jonathan")
    }
    
    // MARK: - Initial Setup
    
    func ensureDatabaseSetup(completion: @escaping (Bool) -> Void) {
        guard Auth.auth().currentUser != nil else {
            print("No user logged in")
            completion(false)
            return
        }
        
        // 1. Check and create user settings
        let userSettingsRef = db.collection("userSettings").document(userId)
        userSettingsRef.getDocument { snapshot, error in
            if let error = error {
                print("Error checking user settings: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if snapshot?.exists != true {
                // Create default user settings
                let settings: [String: Any] = [
                    "enabledCategories": ["park", "ride", "food"] // Default categories
                ]
                
                userSettingsRef.setData(settings) { error in
                    if let error = error {
                        print("Error creating user settings: \(error.localizedDescription)")
                    } else {
                        print("Created default user settings")
                    }
                }
            }
            
            // 2. Ensure collections for user stories exist
            self.ensureCollectionExists("userStories/\(self.userId)/history") { success in
                guard success else {
                    completion(false)
                    return
                }
                
                self.ensureCollectionExists("userStories/\(self.userId)/favorites") { success in
                    guard success else {
                        completion(false)
                        return
                    }
                    
                    // Complete setup
                    print("Firebase database structure verified")
                    completion(true)
                }
            }
        }
    }
    
    private func ensureCollectionExists(_ path: String, completion: @escaping (Bool) -> Void) {
        // Create a test document we'll delete right after to ensure the collection exists
        let testDocRef = db.document("\(path)/test")
        
        testDocRef.setData(["test": true]) { error in
            if let error = error {
                print("Error creating test document: \(error.localizedDescription)")
                completion(false)
            } else {
                // Delete the test document
                testDocRef.delete { error in
                    if let error = error {
                        print("Error deleting test document: \(error.localizedDescription)")
                    }
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - User Settings
    
    func fetchUserSettings(completion: @escaping ([Category]) -> Void) {
        let ref = db.collection("userSettings").document(userId)
        ref.getDocument { snap, error in
            if let error = error {
                print("Error fetching user settings: \(error.localizedDescription)")
                completion(Category.allCases)
                return
            }
            
            if let data = snap?.data() {
                // Manual parsing of user settings
                if let categoryStrings = data["enabledCategories"] as? [String] {
                    let categories = categoryStrings.compactMap { Category(rawValue: $0) }
                    completion(categories.isEmpty ? Category.allCases : categories)
                    return
                }
            }
            
            // Default if no settings found
            completion(Category.allCases)
        }
    }
    
    func saveUserSettings(enabledCategories: [Category], completion: @escaping (Bool) -> Void) {
        // Convert enabledCategories to string array for Firestore
        let categoryStrings = enabledCategories.map { $0.rawValue }
        
        // Create data dictionary
        let data: [String: Any] = [
            "enabledCategories": categoryStrings
        ]
        
        // Save to Firestore
        db.collection("userSettings")
           .document(userId)
           .setData(data) { error in
               if let error = error {
                   print("Error saving user settings: \(error.localizedDescription)")
                   completion(false)
               } else {
                   completion(true)
               }
           }
    }
    
    // MARK: - Stories Management
    
    func fetchStoryHistory(completion: @escaping ([DaydreamStory]) -> Void) {
        print("📚 Fetching shared stories from Firestore...")
        let ref = db.collection("sharedStories")
            .order(by: "date", descending: true)
        
        ref.getDocuments { snap, error in
            if let error = error {
                print("❌ Error fetching shared stories: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snap?.documents else {
                print("❌ No documents found in sharedStories collection")
                completion([])
                return
            }
            
            print("📄 Found \(documents.count) shared story documents")
            
            var stories: [DaydreamStory] = []
            
            for doc in documents {
                let data = doc.data()
                print("📝 Processing document: \(doc.documentID) with data: \(data)")
                
                guard let dateTimestamp = data["date"] as? Timestamp,
                      let itemsDict = data["items"] as? [String: String],
                      let authorString = data["author"] as? String,
                      let author = StoryAuthor(rawValue: authorString)
                else {
                    print("⚠️ Missing required fields in document: \(doc.documentID)")
                    continue
                }
                
                var items: [Category: String] = [:]
                for (key, value) in itemsDict {
                    if let category = Category(rawValue: key) {
                        items[category] = value
                    }
                }
                
                let story = DaydreamStory(
                    id: UUID(),
                    dateAssigned: dateTimestamp.dateValue(),
                    items: items,
                    assignedAuthor: author,
                    storyText: data["text"] as? String,
                    isFavorite: false
                )
                
                stories.append(story)
                print("✅ Added story to history: \(story.promptText)")
            }
            
            completion(stories)
        }
    }
    
    func fetchFavorites(completion: @escaping ([DaydreamStory]) -> Void) {
        let ref = db.collection("userStories")
                    .document(userId)
                    .collection("favorites")
                    .order(by: "date", descending: true)
        
        ref.getDocuments { snap, error in
            if let error = error {
                print("Error fetching favorites: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snap?.documents else {
                completion([])
                return
            }
            
            // Process each document into a DaydreamStory
            var favStories: [DaydreamStory] = []
            
            for doc in documents {
                let data = doc.data()
                
                // Extract basic data
                guard let dateTimestamp = data["date"] as? Timestamp,
                      let itemsDict = data["items"] as? [String: String] else {
                    continue
                }
                
                // Convert string categories to Category enum
                var items: [Category: String] = [:]
                for (key, value) in itemsDict {
                    if let category = Category(rawValue: key) {
                        items[category] = value
                    }
                }
                
                // Get author or default to user
                let authorString = data["author"] as? String ?? StoryAuthor.user.rawValue
                let author = StoryAuthor(rawValue: authorString) ?? .user
                
                // Create DaydreamStory
                let story = DaydreamStory(
                    id: UUID(), // Generate new UUID
                    dateAssigned: dateTimestamp.dateValue(),
                    items: items,
                    assignedAuthor: author,
                    storyText: data["text"] as? String,
                    isFavorite: true // It's in favorites, so must be true
                )
                
                favStories.append(story)
            }
            
            completion(favStories)
        }
    }
    
    func saveStory(_ story: DaydreamStory, toCollection collection: String, completion: @escaping (Bool) -> Void) {
        // Convert to Firebase-friendly format
        var firebaseData: [String: Any] = [
            "date": Timestamp(date: story.dateAssigned),
            "author": story.assignedAuthor.rawValue,
            "isFavorite": story.isFavorite
        ]
        
        // Add items as a dictionary with string keys
        var itemsDict: [String: String] = [:]
        for (category, value) in story.items {
            itemsDict[category.rawValue] = value
        }
        firebaseData["items"] = itemsDict
        
        // Add story text if available
        if let text = story.storyText {
            firebaseData["text"] = text
        }
        
        // Add to Firestore
        let collectionRef = db.collection("userStories")
                             .document(userId)
                             .collection(collection)
        
        // Use story ID as document ID for favorites, or auto-generated for history
        let docRef = collection == "favorites" ?
                    collectionRef.document(story.id.uuidString) :
                    collectionRef.document()
        
        docRef.setData(firebaseData) { error in
            if let error = error {
                print("Error saving story to \(collection): \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func removeFavorite(storyId: UUID, completion: @escaping (Bool) -> Void) {
        let ref = db.collection("userStories")
                    .document(userId)
                    .collection("favorites")
                    .document(storyId.uuidString)
        
        ref.delete { error in
            if let error = error {
                print("Error removing favorite from Firestore: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func clearStoryHistory(completion: @escaping (Bool) -> Void) {
        // Get all history documents
        let historyRef = db.collection("userStories")
                           .document(userId)
                           .collection("history")
        
        historyRef.getDocuments { [weak self] snapshot, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            if let error = error {
                print("Error fetching history documents: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("No history documents found")
                completion(true)
                return
            }
            
            // Use batched writes for better performance with multiple deletions
            let batch = db.batch()
            
            // Add delete operations to batch
            for document in documents {
                batch.deleteDocument(document.reference)
            }
            
            // Commit the batch
            batch.commit { error in
                if let error = error {
                    print("Error clearing history: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("History cleared successfully")
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Daily Prompt Management
    
    func fetchDailyPrompt(completion: @escaping (DaydreamStory?) -> Void) {
        let docRef = db.collection("dailyPrompts").document(userId)
        docRef.getDocument { snap, error in
            if let error = error {
                print("Error fetching daily prompt: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let data = snap?.data(),
               let dateTimestamp = data["date"] as? Timestamp {
                
                // Get the date value first
                let date = dateTimestamp.dateValue()
                
                if Calendar.current.isDateInToday(date) {
                    // Found today's prompt in Firestore, convert to DaydreamStory
                    // Extract items
                    var items: [Category: String] = [:]
                    if let itemsDict = data["items"] as? [String: String] {
                        for (key, value) in itemsDict {
                            if let category = Category(rawValue: key) {
                                items[category] = value
                            }
                        }
                    }
                    
                    // Get author
                    let authorString = data["author"] as? String ?? StoryAuthor.user.rawValue
                    let author = StoryAuthor(rawValue: authorString) ?? .user
                    
                    // Create DaydreamStory
                    let prompt = DaydreamStory(
                        id: UUID(),
                        dateAssigned: date,
                        items: items,
                        assignedAuthor: author,
                        storyText: data["text"] as? String,
                        isFavorite: data["isFavorite"] as? Bool ?? false
                    )
                    
                    completion(prompt)
                } else {
                    // No prompt for today
                    completion(nil)
                }
            } else {
                // No document exists
                completion(nil)
            }
        }
    }
    
    func saveDailyPrompt(_ prompt: DaydreamStory, completion: @escaping (Bool) -> Void) {
        let docRef = db.collection("dailyPrompts").document(userId)
        
        // Convert to Firebase-friendly format
        var firebaseData: [String: Any] = [
            "date": Timestamp(date: prompt.dateAssigned),
            "author": prompt.assignedAuthor.rawValue,
            "isFavorite": prompt.isFavorite
        ]
        
        // Add items as a dictionary with string keys
        var itemsDict: [String: String] = [:]
        for (category, value) in prompt.items {
            itemsDict[category.rawValue] = value
        }
        firebaseData["items"] = itemsDict
        
        // Add story text if available
        if let text = prompt.storyText {
            firebaseData["text"] = text
        }
        
        // Save to Firestore
        docRef.setData(firebaseData) { error in
            if let error = error {
                print("Error saving daily prompt: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
                
                // Also save to shared stories to make it immediately visible to both users
                let dateKey = DateFormatter.shared.string(from: prompt.dateAssigned)
                let sharedRef = self.db.collection("sharedStories").document(dateKey)
                
                sharedRef.setData(firebaseData, merge: true) { error in
                    if let error = error {
                        print("❌ Error saving shared prompt: \(error.localizedDescription)")
                    } else {
                        print("✅ Shared prompt saved for both users")
                    }
                }
            }
        }
    }
    
    func determineNextAuthor(completion: @escaping (StoryAuthor) -> Void) {
        // Check the most recent prompt in shared stories
        db.collection("sharedStories")
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error determining next author: \(error.localizedDescription)")
                    // Default to alternating from user if there's an error
                    completion(StoryAuthor.user == .user ? .wife : .user)
                    return
                }
                
                if let document = snapshot?.documents.first,
                   let authorString = document.data()["author"] as? String,
                   let lastAuthor = StoryAuthor(rawValue: authorString) {
                    // Alternate from the last author
                    completion(lastAuthor == .user ? .wife : .user)
                } else {
                    // No previous stories, default to user
                    completion(.user)
                }
            }
    }
    
    // MARK: - Story Completion Tracking
    
    func markStoryAsCompleted(_ story: DaydreamStory, completion: @escaping (Bool) -> Void) {
        // Mark story as completed in Firestore
        let completeRef = db.collection("completedStories").document(userId)
        completeRef.setData([
            "date": Timestamp(date: Date()),
            "author": story.assignedAuthor.rawValue
        ]) { error in
            if let error = error {
                print("Error saving story completion info: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Marked story as completed for user \(self.userId)")
                
                // Update in shared stories
                let dateKey = DateFormatter.shared.string(from: story.dateAssigned)
                let sharedRef = self.db.collection("sharedStories").document(dateKey)
                
                var sharedData: [String: Any] = [
                    "date": Timestamp(date: story.dateAssigned),
                    "author": story.assignedAuthor.rawValue
                ]
                
                if let text = story.storyText {
                    sharedData["text"] = text
                }
                
                var sharedItems: [String: String] = [:]
                for (category, value) in story.items {
                    sharedItems[category.rawValue] = value
                }
                sharedData["items"] = sharedItems
                
                sharedRef.setData(sharedData, merge: true) { error in
                    if let error = error {
                        print("❌ Error saving shared story: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("✅ Shared story saved for both users")
                        completion(true)
                    }
                }
            }
        }
    }
    
    // MARK: - Listeners
    
    func listenForSharedStoryChanges(onChange: @escaping () -> Void) -> ListenerRegistration {
        print("👂 Starting to listen for shared story changes")
        return db.collection("sharedStories")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening for shared story changes: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                if !snapshot.documentChanges.isEmpty {
                    print("🔄 Detected \(snapshot.documentChanges.count) changes in shared stories")
                    // Notify listener
                    onChange()
                }
            }
    }
    
    func listenForStoryCompletion(onCompleted: @escaping (String) -> Void) -> ListenerRegistration {
        let currentAuthor = isCurrentUserJon ? StoryAuthor.user : StoryAuthor.wife
        
        // Listen to the shared stories collection
        return db.collection("sharedStories")
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    print("Error listening for story changes: \(error?.localizedDescription ?? "unknown error")")
                    return
                }
                
                snapshot.documentChanges.forEach { change in
                    if change.type == .added || change.type == .modified {
                        let data = change.document.data()
                        
                        guard let authorString = data["author"] as? String,
                              let author = StoryAuthor(rawValue: authorString),
                              let dateTimestamp = data["date"] as? Timestamp,
                              let _ = data["text"] as? String // Ensure text exists
                        else { return }
                        
                        // Only notify if this story was written by the other user and today
                        if author != currentAuthor && Calendar.current.isDateInToday(dateTimestamp.dateValue()) {
                            print("🔔 Showing notification for story by \(author.displayName)")
                            onCompleted(author.displayName)
                        }
                    }
                }
            }
    }
    
    // MARK: - Auth Operations
    
    func loginUser(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(false, "Login failed: \(error.localizedDescription)")
            } else {
                completion(true, nil)
            }
        }
    }
    
    func signOutUser() -> Bool {
        do {
            try Auth.auth().signOut()
            return true
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            return false
        }
    }
    
    func createTestAccounts(completion: @escaping (Bool, String?) -> Void) {
        // Create first test account
        Auth.auth().createUser(withEmail: "jon@example.com", password: "password123") { result, error in
            if let error = error {
                if error.localizedDescription.contains("already in use") {
                    print("Jon's account already exists")
                    self.createSecondAccount(completion: completion)
                } else {
                    print("Error creating first account: \(error.localizedDescription)")
                    completion(false, "Error creating accounts: \(error.localizedDescription)")
                }
            } else {
                print("First account created successfully")
                self.createSecondAccount(completion: completion)
            }
        }
    }
    
    private func createSecondAccount(completion: @escaping (Bool, String?) -> Void) {
        // Create second test account
        Auth.auth().createUser(withEmail: "carolyn@example.com", password: "password123") { result, error in
            if let error = error {
                if error.localizedDescription.contains("already in use") {
                    print("Carolyn's account already exists")
                    completion(true, "Accounts already exist")
                } else {
                    print("Error creating second account: \(error.localizedDescription)")
                    completion(false, "Error creating second account: \(error.localizedDescription)")
                }
            } else {
                print("Second account created successfully")
                completion(true, "Accounts created successfully")
            }
        }
    }
}
