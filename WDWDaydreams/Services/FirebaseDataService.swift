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
        
        // Clear shared stories (affects both users)
        db.collection("sharedStories").getDocuments { [weak self] snapshot, error in
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
            
            // Add delete operations to batch
            for document in documents {
                batch.deleteDocument(document.reference)
            }
            
            // Commit the batch
            batch.commit { error in
                if let error = error {
                    print("Error clearing shared stories: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("Shared stories cleared successfully")
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Daily Prompt Management
    
    func saveDailyPrompt(_ prompt: DaydreamStory, completion: @escaping (Bool) -> Void) {
        guard ensureAuthenticated() else {
            completion(false)
            return
        }
        
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
        
        // Save to shared stories to make it immediately visible to both users
        let dateKey = DateFormatter.shared.string(from: prompt.dateAssigned)
        let sharedRef = db.collection("sharedStories").document(dateKey)
        
        sharedRef.setData(firebaseData, merge: true) { error in
            if let error = error {
                print("❌ Error saving shared prompt: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Shared prompt saved for both users")
                completion(true)
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
                completion(true)
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
