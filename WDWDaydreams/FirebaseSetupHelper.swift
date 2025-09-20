import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirebaseSetupHelper {
    static let shared = FirebaseSetupHelper()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func ensureDatabaseSetup(completion: @escaping (Bool) -> Void) {
        // This function checks if the necessary collections and documents exist
        // If not, it creates them
        
        guard let currentUser = Auth.auth().currentUser else {
            print("No user logged in")
            completion(false)
            return
        }
        
        let userId = currentUser.uid
        
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
            // We don't need to create documents here, just ensure the structure
            
            // This is a test document we'll delete right after to ensure the collection exists
            let historyRef = self.db.collection("userStories")
                .document(userId)
                .collection("history")
                .document("test")
            
            historyRef.setData(["test": true]) { error in
                if let error = error {
                    print("Error creating test history document: \(error.localizedDescription)")
                } else {
                    // Delete the test document
                    historyRef.delete()
                }
                
                // Create test favorites document
                let favoritesRef = self.db.collection("userStories")
                    .document(userId)
                    .collection("favorites")
                    .document("test")
                
                favoritesRef.setData(["test": true]) { error in
                    if let error = error {
                        print("Error creating test favorites document: \(error.localizedDescription)")
                    } else {
                        // Delete the test document
                        favoritesRef.delete()
                    }
                    
                    // Ensure daily prompts collection
                    let dailyPromptRef = self.db.collection("dailyPrompts").document(userId)
                    
                    // Check if there's already a daily prompt
                    dailyPromptRef.getDocument { snapshot, error in
                        // We don't need to create it here, the ScenarioManager will do that
                        // We just need to make sure the structure exists
                        
                        print("Firebase database structure verified")
                        completion(true)
                    }
                }
            }
        }
    }
}
