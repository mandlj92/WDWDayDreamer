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
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        let userId = currentUser.uid
        
        // 1. Check and create user settings
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

            // Create default user settings
            let settings: [String: Any] = [
                "enabledCategories": ["park", "ride", "food"] // Default categories
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
}
