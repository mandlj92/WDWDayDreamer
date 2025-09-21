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
        guard let currentUser = Auth.auth().currentUser else {
            print("⚠️ Warning: No authenticated user, returning empty string")
            return ""
        }
        return currentUser.uid
    }
    
    var currentUserEmail: String {
        Auth.auth().currentUser?.email ?? ""
    }
    
    var isCurrentUserJon: Bool {
        let email = currentUserEmail.lowercased()
        return email.contains("jon") || email.contains("jonathan")
    }
    
    // Safety check for authenticated operations
    private func ensureAuthenticated() -> Bool {
        guard Auth.auth().currentUser != nil else {
            print("❌ Operation attempted without authentication")
            return false
        }
        return true
    }
    
    // MARK: - Initial Setup
    
    func ensureDatabaseSetup(completion: @escaping (Bool) -> Void) {
        guard Auth.auth().currentUser != nil else {
            print("No user logged in")
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }

        let userSettingsRef = db.collection("userSettings").document(userId)
        userSettingsRef.getDocument { snapshot, error in
            if let error = error {
                print("Error checking user settings: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            guard snapshot?.exists != true else {
                DispatchQueue.main.async {
                    completion(true)
                }
                return
            }

            let settings: [String: Any] = [
                "enabledCategories": ["park", "ride", "food"],
                "tripDate": NSNull() // Explicitly set no trip date initially
            ]

            userSettingsRef.setData(settings, merge: true) { error in
                if let error = error {
                    print("Error creating user settings: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                } else {
                    print("Created default user settings")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                }
            }
        }
    }
    
    // MARK: - User Settings
    
    func fetchUserSettings(completion: @escaping ([Category], Date?) -> Void) {
        guard ensureAuthenticated() else {
            completion([.park, .ride, .food], nil) // Default categories, no trip date
            return
        }
        
        let ref = db.collection("userSettings").document(userId)
        ref.getDocument { snap, error in
            if let error = error {
                print("Error fetching user settings: \(error.localizedDescription)")
                completion([.park, .ride, .food], nil) // Default categories, no trip date
                return
            }
            
            var categories: [Category] = [.park, .ride, .food] // Default
            var tripDate: Date? = nil
            
            if let data = snap?.data() {
                // Parse categories
                if let categoryStrings = data["enabledCategories"] as? [String] {
                    let parsedCategories = categoryStrings.compactMap { Category(rawValue: $0) }
                    if !parsedCategories.isEmpty {
                        categories = parsedCategories
                    }
                }
                
                // Parse trip date
                if let tripTimestamp = data["tripDate"] as? Timestamp {
                    tripDate = tripTimestamp.dateValue()
                    print("✅ Loaded trip date: \(tripDate!)")
                } else {
                    print("ℹ️ No trip date found in settings")
                }
            }
            
            print("✅ Loaded user settings: categories=\(categories.map{$0.rawValue}), tripDate=\(tripDate?.description ?? "nil")")
            completion(categories, tripDate)
        }
    }
    
    func saveUserSettings(enabledCategories: [Category], tripDate: Date? = nil, completion: @escaping (Bool) -> Void) {
        guard ensureAuthenticated() else {
            completion(false)
            return
        }
        
        // Ensure we have at least one category enabled
        let categoriesToSave = enabledCategories.isEmpty ? [.park, .ride, .food] : enabledCategories
        
        // Convert enabledCategories to string array for Firestore
        let categoryStrings = categoriesToSave.map { $0.rawValue }
        
        // Create data dictionary
        var data: [String: Any] = [
            "enabledCategories": categoryStrings
        ]
        
        // Add trip date if provided (use NSNull() for nil to explicitly remove it)
        if let tripDate = tripDate {
            data["tripDate"] = Timestamp(date: tripDate)
        } else {
            data["tripDate"] = NSNull()
        }
        
        // Save to Firestore with merge to preserve other settings
        db.collection("userSettings")
           .document(userId)
           .setData(data, merge: true) { error in
               if let error = error {
                   print("Error saving user settings: \(error.localizedDescription)")
                   completion(false)
               } else {
                   print("✅ User settings saved: categories=\(categoryStrings), tripDate=\(tripDate?.description ?? "nil")")
                   completion(true)
               }
           }
    }
    
    // MARK: - Stories Management (NOW REAL-TIME)
    
    func listenForStoryHistory(completion: @escaping ([DaydreamStory]) -> Void) -> ListenerRegistration {
        guard ensureAuthenticated() else {
            // Return a dummy listener that does nothing
            return db.collection("dummy").addSnapshotListener { _, _ in }
        }
        
        print("👂 [Real-Time] Listening for shared stories...")
        let ref = db.collection("sharedStories").order(by: "date", descending: true)
        
        return ref.addSnapshotListener { snapshot, error in
            if let error = error {
                print("❌ Error listening for shared stories: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("❌ No documents found in sharedStories collection")
                completion([])
                return
            }
            
            print("📄 [Real-Time] Received \(documents.count) shared story documents")
            
            let stories = documents.compactMap { doc -> DaydreamStory? in
                let data = doc.data()
                guard let dateTimestamp = data["date"] as? Timestamp,
                      let itemsDict = data["items"] as? [String: String],
                      let authorString = data["author"] as? String,
                      let author = StoryAuthor(rawValue: authorString)
                else {
                    print("⚠️ Missing required fields in document: \(doc.documentID)")
                    return nil
                }
                
                var items: [Category: String] = [:]
                for (key, value) in itemsDict {
                    if let category = Category(rawValue: key) {
                        items[category] = value
                    }
                }
                
                return DaydreamStory(
                    id: UUID(), // Or use a persistent ID if you have one
                    dateAssigned: dateTimestamp.dateValue(),
                    items: items,
                    assignedAuthor: author,
                    storyText: data["text"] as? String,
                    isFavorite: false // Favorite status is managed per-user
                )
            }
            
            completion(stories)
        }
    }

    
    func fetchFavorites(completion: @escaping ([DaydreamStory]) -> Void) {
        guard ensureAuthenticated() else {
            completion([])
            return
        }
        
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
                let storyID = UUID(uuidString: doc.documentID) ?? UUID()

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
                    id: storyID,
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
        guard ensureAuthenticated() else {
            completion(false)
            return
        }
        
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
        guard ensureAuthenticated() else {
            completion(false)
            return
        }
        
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
        guard ensureAuthenticated() else {
            completion(false)
            return
        }
        
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
    
    func listenForDailyPrompt(completion: @escaping (DaydreamStory?) -> Void) -> ListenerRegistration {
        guard ensureAuthenticated() else {
            completion(nil)
            // Return a dummy listener that does nothing
            return db.collection("dummy").addSnapshotListener { _, _ in }
        }
        
        let docRef = db.collection("dailyPrompts").document(userId)
        
        return docRef.addSnapshotListener { snapshot, error in
            if let error = error {
                print("❌ Error listening for daily prompt: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = snapshot?.data(), let dateTimestamp = data["date"] as? Timestamp else {
                // No document exists for today
                completion(nil)
                return
            }
            
            let date = dateTimestamp.dateValue()
            
            if Calendar.current.isDateInToday(date) {
                // Found today's prompt, convert to DaydreamStory
                var items: [Category: String] = [:]
                if let itemsDict = data["items"] as? [String: String] {
                    for (key, value) in itemsDict {
                        if let category = Category(rawValue: key) {
                            items[category] = value
                        }
                    }
                }
                
                let authorString = data["author"] as? String ?? StoryAuthor.user.rawValue
                let author = StoryAuthor(rawValue: authorString) ?? .user
                
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
                // The prompt is from a previous day
                completion(nil)
            }
        }
    }

    
    func saveDailyPrompt(_ prompt: DaydreamStory, completion: @escaping (Bool) -> Void) {
        guard ensureAuthenticated() else {
            completion(false)
            return
        }
        
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
        guard ensureAuthenticated() else {
            completion(.user)
            return
        }
        
        // Check the most recent prompt in shared stories
        db.collection("sharedStories")
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error determining next author: \(error.localizedDescription)")
                    // Default based on which user is signed in to keep turn order stable
                    completion(self.isCurrentUserJon ? .user : .wife)
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
        guard ensureAuthenticated(), let storyText = story.storyText else {
            completion(false)
            return
        }
        
        // Update the shared story document with the new text
        let dateKey = DateFormatter.shared.string(from: story.dateAssigned)
        let sharedRef = db.collection("sharedStories").document(dateKey)
        
        let updateData: [String: Any] = [
            "text": storyText,
            "author": story.assignedAuthor.rawValue
        ]
        
        sharedRef.setData(updateData, merge: true) { error in
            if let error = error {
                print("❌ Error updating shared story: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Shared story updated for both users")
                // ** NEW: Trigger a local notification for the other user **
                NotificationManager.shared.sendLocalCompletionNotification(from: story.assignedAuthor.displayName)
                completion(true)
            }
        }
    }

    
    // MARK: - Listeners
    
    func listenForSharedStoryChanges(onChange: @escaping () -> Void) -> ListenerRegistration {
        guard ensureAuthenticated() else {
            // Return a dummy listener if not authenticated
            return db.collection("dummy").addSnapshotListener { _, _ in }
        }
        
        print("👂 Starting to listen for shared story changes")
        var lastChangeTime: Date = Date()
        
        return db.collection("sharedStories")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening for shared story changes: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                if !snapshot.documentChanges.isEmpty {
                    // Debounce rapid changes
                    let now = Date()
                    if now.timeIntervalSince(lastChangeTime) > 1.0 {
                        print("🔄 Detected \(snapshot.documentChanges.count) changes in shared stories")
                        lastChangeTime = now
                        // Notify listener
                        onChange()
                    } else {
                        print("🔄 Debouncing rapid changes...")
                    }
                }
            }
    }
    
    func listenForStoryCompletion(onCompleted: @escaping (String) -> Void) -> ListenerRegistration {
        guard ensureAuthenticated() else {
            // Return a dummy listener if not authenticated
            return db.collection("dummy").addSnapshotListener { _, _ in }
        }
        
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
        print("🔐 FirebaseDataService: Attempting login for \(email)")
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("🔐 FirebaseDataService: Login failed - \(error.localizedDescription)")
                completion(false, "Login failed: \(error.localizedDescription)")
            } else {
                print("🔐 FirebaseDataService: Login successful for \(email)")
                if let user = result?.user {
                    print("🔐 FirebaseDataService: User ID: \(user.uid)")
                }
                completion(true, nil)
            }
        }
    }
    
    func signOutUser() -> Bool {
        do {
            try Auth.auth().signOut()
            print("🔐 FirebaseDataService: Sign out successful")
            return true
        } catch {
            print("🔐 FirebaseDataService: Error signing out: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Test account creation methods removed for security
    // Note: No longer creating test accounts programmatically
    // All user accounts should be created through proper authentication flows
}
