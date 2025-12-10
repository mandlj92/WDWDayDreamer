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
    
    // MARK: - Public Access Methods
    
    // Provide access to Firestore for ScenarioManager
    func getFirestoreReference() -> Firestore {
        return db
    }
    
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
    
    // Helper to get current user's display name
    var currentUserDisplayName: String {
        Auth.auth().currentUser?.displayName ?? "User"
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
    
    // MARK: - Stories Management
    
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
                
                // Get author - try new format first, then legacy
                let author: StoryAuthor
                if let authorId = data["authorId"] as? String,
                   let authorName = data["authorName"] as? String {
                    author = StoryAuthor(userId: authorId, displayName: authorName)
                } else if let legacyAuthor = data["author"] as? String {
                    // Legacy migration support
                    author = StoryAuthor(legacyValue: legacyAuthor) ?? StoryAuthor(userId: "unknown", displayName: "Unknown")
                } else {
                    author = StoryAuthor(userId: self.userId, displayName: self.currentUserDisplayName)
                }
                
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
            "authorId": story.assignedAuthor.userId,
            "authorName": story.assignedAuthor.displayName,
            "isFavorite": story.isFavorite
        ]

        if let partnershipId = story.partnershipId {
            firebaseData["partnershipId"] = partnershipId
        }
        
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
    
    func clearStoryHistory(partnershipId: String, completion: @escaping (Bool) -> Void) {
        guard ensureAuthenticated() else {
            completion(false)
            return
        }

        // Clear stories for this partnership
        db.collection("partnerships")
            .document(partnershipId)
            .collection("stories")
            .getDocuments { [weak self] snapshot, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            if let error = error {
                print("Error fetching shared stories: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("No shared stories found")
                completion(true)
                return
            }
            
            // Use batched writes for better performance
            let batch = self.db.batch()

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            var didQueueDeletion = false

            // Add delete operations to batch, skipping today's prompt so the active
            // story remains available for determining the next author.
            for document in documents {
                var shouldSkip = false

                if let timestamp = document.data()["date"] as? Timestamp {
                    let documentDate = calendar.startOfDay(for: timestamp.dateValue())
                    shouldSkip = documentDate == todayStart
                } else if let idDate = DateFormatter.shared.date(from: document.documentID) {
                    shouldSkip = calendar.isDate(idDate, inSameDayAs: todayStart)
                }

                if shouldSkip {
                    print("Skipping deletion of today's prompt (\(document.documentID)) to preserve active story")
                    continue
                }

                batch.deleteDocument(document.reference)
                didQueueDeletion = true
            }

            guard didQueueDeletion else {
                print("No historical shared stories to delete (today's prompt preserved)")
                completion(true)
                return
            }

            // Commit the batch
            batch.commit { error in
                if let error = error {
                    print("Error clearing partnership stories: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("Partnership stories cleared successfully (today's prompt preserved)")
                    completion(true)
                }
            }
        }
    }

    // MARK: - Partnership Story Fetching

    func fetchPartnershipStories(partnershipId: String, completion: @escaping ([DaydreamStory]) -> Void) {
        guard ensureAuthenticated() else {
            completion([])
            return
        }

        db.collection("partnerships")
            .document(partnershipId)
            .collection("stories")
            .order(by: "date", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching partnership stories: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let stories = documents.compactMap { doc -> DaydreamStory? in
                    let data = doc.data()
                    guard let dateTimestamp = data["date"] as? Timestamp,
                          let itemsDict = data["items"] as? [String: String] else {
                        return nil
                    }

                    var items: [Category: String] = [:]
                    for (key, value) in itemsDict {
                        if let category = Category(rawValue: key) {
                            items[category] = value
                        }
                    }

                    // Get author - try new format first, then legacy
                    let author: StoryAuthor
                    if let authorId = data["authorId"] as? String,
                       let authorName = data["authorName"] as? String {
                        author = StoryAuthor(userId: authorId, displayName: authorName)
                    } else if let legacyAuthor = data["author"] as? String {
                        author = StoryAuthor(legacyValue: legacyAuthor) ?? StoryAuthor(userId: "unknown", displayName: "Unknown")
                    } else {
                        author = StoryAuthor(userId: self.userId, displayName: self.currentUserDisplayName)
                    }

                    return DaydreamStory(
                        id: UUID(),
                        dateAssigned: dateTimestamp.dateValue(),
                        items: items,
                        assignedAuthor: author,
                        partnershipId: partnershipId,
                        storyText: data["text"] as? String,
                        isFavorite: data["isFavorite"] as? Bool ?? false
                    )
                }

                completion(stories)
            }
    }
    
    // MARK: - Daily Prompt Management (Partnership-based)

    func saveDailyPrompt(_ prompt: DaydreamStory, partnershipId: String, completion: @escaping (Bool) -> Void) {
        guard ensureAuthenticated() else {
            completion(false)
            return
        }

        // Convert to Firebase-friendly format
        var firebaseData: [String: Any] = [
            "date": Timestamp(date: prompt.dateAssigned),
            "authorId": prompt.assignedAuthor.userId,
            "authorName": prompt.assignedAuthor.displayName,
            "isFavorite": prompt.isFavorite,
            "partnershipId": partnershipId
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

        // Save to partnership's stories collection
        let dateKey = DateFormatter.shared.string(from: prompt.dateAssigned)
        let partnershipRef = db.collection("partnerships")
            .document(partnershipId)
            .collection("stories")
            .document(dateKey)

        partnershipRef.setData(firebaseData, merge: true) { error in
            if let error = error {
                print("❌ Error saving partnership story: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Partnership story saved")
                completion(true)
            }
        }
    }
    
    func determineNextAuthor(partnership: StoryPartnership, currentUserId: String, partnerProfile: UserProfile, completion: @escaping (StoryAuthor) -> Void) {
        guard ensureAuthenticated() else {
            completion(StoryAuthor(userId: currentUserId, displayName: currentUserDisplayName))
            return
        }

        // Check if partnership has a nextAuthorId set
        if let nextAuthorId = partnership.nextAuthorId {
            let displayName = nextAuthorId == currentUserId ? currentUserDisplayName : partnerProfile.displayName
            completion(StoryAuthor(userId: nextAuthorId, displayName: displayName))
            return
        }

        // Check the most recent story in this partnership
        db.collection("partnerships")
            .document(partnership.id)
            .collection("stories")
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error determining next author: \(error.localizedDescription)")
                    // Default to current user
                    completion(StoryAuthor(userId: currentUserId, displayName: self.currentUserDisplayName))
                    return
                }

                if let document = snapshot?.documents.first,
                   let lastAuthorId = document.data()["authorId"] as? String {
                    // Alternate from the last author
                    let nextAuthorId = lastAuthorId == partnership.user1Id ? partnership.user2Id : partnership.user1Id
                    let displayName = nextAuthorId == currentUserId ? self.currentUserDisplayName : partnerProfile.displayName
                    completion(StoryAuthor(userId: nextAuthorId, displayName: displayName))
                } else {
                    // No previous stories, start with user1
                    let displayName = partnership.user1Id == currentUserId ? self.currentUserDisplayName : partnerProfile.displayName
                    completion(StoryAuthor(userId: partnership.user1Id, displayName: displayName))
                }
            }
    }
    
    // MARK: - Story Completion Tracking
    
    func markStoryAsCompleted(_ story: DaydreamStory, partnershipId: String, completion: @escaping (Bool, String?) -> Void) {
        guard ensureAuthenticated(), let storyText = story.storyText else {
            completion(false, "Missing story text or not authenticated")
            return
        }

        // Update the partnership story document with the completed text
        let dateKey = DateFormatter.shared.string(from: story.dateAssigned)
        let storyRef = db.collection("partnerships")
            .document(partnershipId)
            .collection("stories")
            .document(dateKey)

        // Use transaction to prevent race conditions with optimistic locking
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let document: DocumentSnapshot
            do {
                try document = transaction.getDocument(storyRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            // Check if document exists and get current version
            let currentVersion = document.data()?["version"] as? Int ?? 0
            let storyVersion = story.version ?? 0

            // If versions don't match, there's a conflict
            if document.exists && currentVersion > storyVersion {
                print("⚠️ Version conflict detected: current=\(currentVersion), story=\(storyVersion)")
                errorPointer?.pointee = NSError(
                    domain: "StoryWriteError",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "Story was modified by another user"]
                )
                return nil
            }

            // Increment version and update
            let newVersion = currentVersion + 1
            let now = Date()

            let updateData: [String: Any] = [
                "text": storyText,
                "authorId": story.assignedAuthor.userId,
                "authorName": story.assignedAuthor.displayName,
                "completedAt": Timestamp(date: now),
                "lastModified": Timestamp(date: now),
                "version": newVersion
            ]

            transaction.setData(updateData, forDocument: storyRef, merge: true)

            // Update partnership's lastStoryDate
            let partnershipRef = self.db.collection("partnerships").document(partnershipId)
            transaction.updateData([
                "lastStoryDate": Timestamp(date: story.dateAssigned)
            ], forDocument: partnershipRef)

            return newVersion

        }) { (object, error) in
            if let error = error {
                let nsError = error as NSError
                if nsError.code == 409 {
                    // Conflict detected
                    print("❌ Conflict error: Story was modified by another user")
                    completion(false, "conflict")
                } else {
                    print("❌ Error updating partnership story: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            } else {
                print("✅ Partnership story marked as completed with version \(object ?? 0)")
                completion(true, nil)
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
    
    // MARK: - System Testing
    
    // Test Firebase connection and permissions
    func testFirebaseConnection(completion: @escaping (Bool, String) -> Void) {
        guard ensureAuthenticated() else {
            completion(false, "User not authenticated")
            return
        }
        
        print("🧪 Testing Firebase connection...")
        
        // Test 1: Try to read user settings
        let userSettingsRef = db.collection("userSettings").document(userId)
        userSettingsRef.getDocument { snapshot, error in
            if let error = error {
                print("❌ Firebase connection test failed: \(error.localizedDescription)")
                completion(false, "Connection failed: \(error.localizedDescription)")
                return
            }
            
            print("✅ Firebase connection test passed!")
            
            // Test 2: Try to write a test document
            let testData = [
                "testTimestamp": Timestamp(date: Date()),
                "testString": "Firebase connection working!",
                "userEmail": self.currentUserEmail,
                "offlinePersistenceEnabled": true
            ]
            
            self.db.collection("connectionTest").document(self.userId).setData(testData) { error in
                if let error = error {
                    print("❌ Firebase write test failed: \(error.localizedDescription)")
                    completion(false, "Write test failed: \(error.localizedDescription)")
                } else {
                    print("✅ Firebase write test passed!")
                    completion(true, "All Firebase tests passed! Offline persistence enabled.")
                }
            }
        }
    }
}
