import FirebaseAuth

// This is a helper class that you can use to create the accounts
// You only need to run this once
class AccountSetupHelper {
    static func createAccounts(completion: @escaping (Bool, String?) -> Void) {
        // Replace with your preferred email and password
        let yourEmail = "jonathanfmandl@gmail.com"
        let yourPassword = "Yunchie309!"
        let wifeEmail = "carolnyingrid9@gmail.com"
        let wifePassword = "Dancing006!!!"
        
        // Create your account first
        Auth.auth().createUser(withEmail: yourEmail, password: yourPassword) { result, error in
            if let error = error {
                if error.localizedDescription.contains("already in use") {
                    print("Your account already exists")
                    // Continue to create wife's account
                    createWifeAccount()
                } else {
                    print("Error creating your account: \(error.localizedDescription)")
                    completion(false, "Error creating your account: \(error.localizedDescription)")
                }
            } else {
                print("Your account created successfully")
                // Continue to create wife's account
                createWifeAccount()
            }
        }
        
        // Helper function to create wife's account
        func createWifeAccount() {
            Auth.auth().createUser(withEmail: wifeEmail, password: wifePassword) { result, error in
                if let error = error {
                    if error.localizedDescription.contains("already in use") {
                        print("Wife account already exists")
                        completion(true, "Both accounts ready")
                    } else {
                        print("Error creating wife account: \(error.localizedDescription)")
                        completion(false, "Error creating wife account: \(error.localizedDescription)")
                    }
                } else {
                    print("Wife account created successfully")
                    completion(true, "Both accounts created successfully")
                }
            }
        }
    }
}
