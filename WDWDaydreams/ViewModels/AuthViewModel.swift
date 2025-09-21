import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

final class AuthViewModel: NSObject, ObservableObject {
    @Published private(set) var isAuthenticated: Bool
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var userRole: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private let firebaseService: FirebaseDataService
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var idTokenHandle: AuthStateDidChangeListenerHandle?
    
    // MARK: - User Authorization Properties
    var isAdmin: Bool {
        userRole == "admin"
    }
    
    var currentUserEmail: String {
        Auth.auth().currentUser?.email ?? ""
    }

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

        // Listen for auth state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                print("🔐 Auth state changed - User: \(user?.email ?? "nil")")
                self?.isAuthenticated = user != nil
                
                if let user = user {
                    print("🔐 User authenticated: \(user.email ?? "no email") - UID: \(user.uid)")
                    
                    // Force refresh ID token to get latest custom claims
                    user.getIDTokenForcingRefresh(true) { [weak self] _, error in
                        if let error = error {
                            print("🔐 Error refreshing ID token: \(error.localizedDescription)")
                        } else {
                            self?.checkUserAuthorization()
                        }
                    }
                } else {
                    self?.isAuthorized = false
                    self?.userRole = ""
                }
            }
        }
        
        // Check authorization if already authenticated
        if isAuthenticated {
            checkUserAuthorization()
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        if let handle = idTokenHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Authorization Check
    private func checkUserAuthorization() {
        guard let user = Auth.auth().currentUser else {
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.userRole = ""
            }
            return
        }
        
        // Get ID token to access custom claims
        user.getIDTokenResult { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("🔐 Error getting ID token: \(error.localizedDescription)")
                    self.isAuthorized = false
                    self.userRole = ""
                    return
                }
                
                guard let result = result else {
                    self.isAuthorized = false
                    self.userRole = ""
                    return
                }
                
                // Check custom claims
                let claims = result.claims
                let isAuthorizedClaim = claims["authorized"] as? Bool ?? false
                let roleClaim = claims["role"] as? String ?? ""
                
                // Check if user is in authorized email list (fallback)
                let authorizedEmails = [
                    "jonathanfmandl@gmail.com",
                    "carolyningrid9@gmail.com"
                ]
                let isAuthorizedEmail = authorizedEmails.contains(user.email?.lowercased() ?? "")
                
                self.isAuthorized = isAuthorizedClaim || isAuthorizedEmail
                self.userRole = roleClaim.isEmpty ? (isAuthorizedEmail ? "user" : "") : roleClaim
                
                print("🔐 Authorization check - Authorized: \(self.isAuthorized), Role: \(self.userRole)")
                
                // If user is not authorized, show error
                if !self.isAuthorized {
                    self.errorMessage = "This app is private and only available to authorized users."
                    // Sign out unauthorized user
                    self.signOut()
                }
            }
        }
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
                        // Authorization check will be triggered by auth state listener
                    }
                }
            }
        }
    }

    // MARK: - Google Sign-In
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
                            print("🔐 Google Sign-In successful for user: \(user.email ?? "no email")")
                            // Authorization check will be triggered by auth state listener
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
        
        // Reset authorization state
        isAuthorized = false
        userRole = ""
    }
    
    // MARK: - Admin Functions
    func refreshUserClaims() {
        guard let user = Auth.auth().currentUser else { return }
        
        user.getIDTokenForcingRefresh(true) { [weak self] _, error in
            if let error = error {
                print("🔐 Error refreshing claims: \(error.localizedDescription)")
            } else {
                print("🔐 User claims refreshed")
                self?.checkUserAuthorization()
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
}
