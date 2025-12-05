import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import Foundation

@MainActor
class AuthViewModel: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var authenticationError: AuthError?
    @Published var isLoading = false
    @Published var errorMessage: String = ""
    @Published var requiresOnboarding = false

    private let firebaseService: FirebaseDataService
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var userRole: String = ""
    
    var isAuthorized: Bool {
        return isAuthenticated
    }
    
    override init() {
        super.init()
        setupGoogleSignIn()
        
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                
                if let user = user {
                    print("🔐 User authenticated: \(user.email ?? "no email") - UID: \(user.uid)")
                    self?.checkUserAuthorization()
                    self?.clearErrors()
                } else {
                    self?.isAuthorized = false
                    self?.userRole = ""
                }
            }
        }
    }
    
    deinit {
        if let authStateListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("ERROR: GoogleService-Info.plist not found or CLIENT_ID missing")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
    
    // MARK: - Email/Password Authentication
    
    func signIn(email: String, password: String) async {
        isLoading = true

        // First, sign out any existing user
        try? Auth.auth().signOut()
        
        // Add a small delay to ensure clean state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if let error = error {
                        let nsError = error as NSError
                        print("🔐 Login failed with error: \(error.localizedDescription)")
                        print("🔐 Error code: \(nsError.code), domain: \(nsError.domain)")
                        
                        // Handle specific error cases
                        switch nsError.code {
                        case 17008: // FIRAuthErrorCodeInvalidCredential
                            self.errorMessage = "Invalid email or password. Please check your credentials."
                        case 17011: // FIRAuthErrorCodeUserNotFound
                            self.errorMessage = "No account found with this email address."
                        case 17009: // FIRAuthErrorCodeWrongPassword
                            self.errorMessage = "Incorrect password. Please try again."
                        case 17020: // FIRAuthErrorCodeNetworkError
                            self.errorMessage = "Network error. Please check your connection and try again."
                        default:
                            self.errorMessage = "Login failed: \(error.localizedDescription)"
                        }
                    } else if let user = result?.user {
                        print("🔐 Login successful for user: \(user.email ?? "no email")")
                        self.checkUserAuthorization()
                    }
                }
            }
        }
    }

    // MARK: - Google Sign-In (Enhanced)
    func signInWithGoogle() {
        print("🔐 Attempting Google Sign-In")
        
        // Clear previous errors
        clearErrors()
        
        guard let presentingViewController = getRootViewController() else {
            errorMessage = "Unable to find root view controller"
            return
        }
        
        isLoading = true
        
        // First, sign out any existing user
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        
        // Configure Google Sign-In if needed
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            isLoading = false
            errorMessage = "Google Sign-In configuration error"
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.isLoading = false
                    let nsError = error as NSError
                    
                    // Don't show error for user cancellation
                    if nsError.code != -5 { // GIDSignInErrorCodeCanceled
                        self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                        print("🔐 Google Sign-In error: \(error)")
                    }
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.isLoading = false
                    self.errorMessage = "Failed to get Google ID token"
                    return
                }
                
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: user.accessToken.tokenString
                )
                
                // Sign in to Firebase with Google credential
                Auth.auth().signIn(with: credential) { authResult, error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let error = error {
                            self.errorMessage = "Firebase authentication failed: \(error.localizedDescription)"
                            print("🔐 Firebase Google auth error: \(error)")
                        } else if let user = authResult?.user {
                            print("🔐 Google Sign-In successful for user: \(user.email ?? "no email")")
                            self.checkUserAuthorization()
                        }
                    }
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            
            // Reset authorization state
            isAuthorized = false
            userRole = ""
            clearErrors()
            
            print("🔐 Sign out successful")
        } catch {
            errorMessage = "Unable to sign out: \(error.localizedDescription)"
            print("🔐 Sign out error: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func clearErrors() {
        errorMessage = ""
    }
    
    private func checkUserAuthorization() {
        // Placeholder implementation for user authorization check
        // This should verify user profile and determine if onboarding is needed
        Task { @MainActor in
            if let user = Auth.auth().currentUser {
                do {
                    let profile = try await FirebaseDataService.shared.getUserProfile(userId: user.uid)
                    if profile == nil {
                        self.requiresOnboarding = true
                    }
                } catch {
                    print("⚠️ Error checking user authorization: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
    
    // MARK: - Token Refresh
    private func refreshUserToken() {
        guard let user = Auth.auth().currentUser else { return }
        
        user.getIDTokenForcingRefresh(true) { [weak self] token, error in
            if let error = error {
                print("🔐 Token refresh failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.errorMessage = "Session expired. Please sign in again."
                    self?.signOut()
                }
            } else {
                print("🔐 Token refreshed successfully")
            }
        }
    }
}
