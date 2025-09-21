import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

final class AuthViewModel: NSObject, ObservableObject {
    @Published private(set) var isAuthenticated: Bool
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private let firebaseService: FirebaseDataService
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    // MARK: - Authorized Users
    private let authorizedEmails = [
        "jonathanfmandl@gmail.com",
        "carolyningrid9@gmail.com"  // Replace with your wife's actual email
    ]

    override init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        self.firebaseService = FirebaseDataService.shared
        self.isAuthenticated = Auth.auth().currentUser != nil
        
        super.init()
        
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
    
    // MARK: - Authorization Check
    private func isAuthorizedUser(_ email: String) -> Bool {
        return authorizedEmails.contains(email.lowercased())
    }

    // MARK: - Email/Password Login
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

    // MARK: - Google Sign-In with Authorization Check
    func signInWithGoogle() {
        print("🔐 Attempting Google Sign-In")
        
        guard let presentingViewController = getRootViewController() else {
            errorMessage = "Unable to find root view controller"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.isLoading = false
                    self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                    print("🔐 Google Sign-In error: \(error)")
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.isLoading = false
                    self.errorMessage = "Failed to get Google ID token"
                    return
                }
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                             accessToken: user.accessToken.tokenString)
                
                // Sign in to Firebase with Google credential
                Auth.auth().signIn(with: credential) { authResult, error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let error = error {
                            self.errorMessage = "Firebase authentication failed: \(error.localizedDescription)"
                            print("🔐 Firebase Google auth error: \(error)")
                        } else if let user = authResult?.user {
                            // Check if user is authorized
                            let userEmail = user.email ?? ""
                            if self.isAuthorizedUser(userEmail) {
                                print("🔐 Google Sign-In successful for authorized user: \(userEmail)")
                            } else {
                                // Sign out unauthorized user immediately
                                do {
                                    try Auth.auth().signOut()
                                    GIDSignIn.sharedInstance.signOut()
                                } catch {
                                    print("🔐 Error signing out unauthorized user: \(error)")
                                }
                                
                                self.errorMessage = "This app is private and only available to authorized users."
                                print("🔐 Unauthorized user attempted to sign in: \(userEmail)")
                            }
                        }
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
        
        // Also sign out of Google
        GIDSignIn.sharedInstance.signOut()
    }
    
    // MARK: - Helper Methods
    private func getRootViewController() -> UIViewController? {
        // Updated method to get root view controller for iOS 15+
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
}
