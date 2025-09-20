import Foundation
import FirebaseAuth
import FirebaseCore

final class AuthViewModel: ObservableObject {
    @Published private(set) var isAuthenticated: Bool
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private let firebaseService: FirebaseDataService
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init(firebaseService: FirebaseDataService = .shared) {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        self.firebaseService = firebaseService
        self.isAuthenticated = Auth.auth().currentUser != nil
        
        // Debug: Print current auth state
        print("🔐 AuthViewModel init - isAuthenticated: \(isAuthenticated)")
        if let user = Auth.auth().currentUser {
            print("🔐 Current user: \(user.email ?? "no email") - UID: \(user.uid)")
        } else {
            print("🔐 No current user found")
        }

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                print("🔐 Auth state changed - User: \(user?.email ?? "nil")")
                self?.isAuthenticated = user != nil
                if let user = user {
                    print("🔐 User authenticated: \(user.email ?? "no email") - UID: \(user.uid)")
                }
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func login(email: String, password: String) {
        print("🔐 Attempting login with email: \(email)")
        isLoading = true
        errorMessage = ""

        firebaseService.loginUser(email: email, password: password) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                print("🔐 Login result - Success: \(success), Error: \(error ?? "none")")

                if let error = error {
                    self.errorMessage = error
                    print("🔐 Login failed: \(error)")
                } else if !success {
                    self.errorMessage = "Login failed. Please try again."
                    print("🔐 Login failed: Unknown reason")
                } else {
                    print("🔐 Login successful!")
                    if let user = Auth.auth().currentUser {
                        print("🔐 Authenticated user: \(user.email ?? "no email") - UID: \(user.uid)")
                    }
                }
            }
        }
    }

    func signOut() {
        print("🔐 Attempting sign out")
        if !firebaseService.signOutUser() {
            errorMessage = "Unable to sign out. Please try again."
        }
    }
}
