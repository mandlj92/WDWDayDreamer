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
    
    // MARK: - User Settings
    
    func fetchUserSettings(completion: @escaping ([Category]) -> Void) {
        guard ensureAuthenticated() else {
            completion(Category.allCases)
            return
        }
        
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
        guard ensureAuthenticated() else {
            completion(false)
            return
        }
        
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
        guard ensureAuthenticated() else {
            completion([])
            return
        }
        
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
    
    // Continue with the rest of your existing methods...
    // (I'll keep the existing implementations for brevity, but they should all include the ensureAuthenticated() check)
    
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
    
    // Add the rest of your existing methods here with the ensureAuthenticated() checks...
}
