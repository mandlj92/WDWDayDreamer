import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import Foundation

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case userNotFound
    case network
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid credentials"
        case .userNotFound: return "User not found"
        case .network: return "Network error"
        case .unknown(let message): return message
        }
    }
}

@MainActor
class AuthViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var authenticationError: AuthError?
    @Published var isLoading = false
    @Published var errorMessage: String = ""
    @Published var requiresOnboarding = false

    private let firebaseService = FirebaseDataService.shared
    private let userService = UserService()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    // For Sign in with Apple
    private var currentNonce: String?
    private var userRole: String = ""
    @Published var isAuthorized = false
    
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

        do {
            // Validate email format before attempting sign-in
            let validatedEmail = try Validator.validateEmail(email)

            let result = try await Auth.auth().signIn(withEmail: validatedEmail, password: password)
            await MainActor.run {
                self.isLoading = false
                self.currentUser = result.user
                print("🔐 Login successful for user: \(result.user.email ?? "no email")")
                self.checkUserAuthorization()
                self.clearErrors()
            }
        } catch let validationError as ValidationError {
            // Handle validation errors
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = validationError.localizedDescription
            }
        } catch {
            let nsError = error as NSError
            print("🔐 Login failed with error: \(error.localizedDescription)")
            print("🔐 Error code: \(nsError.code), domain: \(nsError.domain)")

            await MainActor.run {
                self.isLoading = false

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
            }
        }
    }

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true

        do {
            // Validate all inputs before creating account
            let validatedEmail = try Validator.validateEmail(email)
            let validatedPassword = try Validator.validatePassword(password)
            let validatedDisplayName = try Validator.validateDisplayName(displayName)

            let result = try await Auth.auth().createUser(withEmail: validatedEmail, password: validatedPassword)
            let user = result.user

            print("🔐 User created successfully: \(user.email ?? "no email") - UID: \(user.uid)")

            // Set display name
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = validatedDisplayName

            do {
                try await changeRequest.commitChanges()
                print("🔐 Display name set successfully: \(validatedDisplayName)")
            } catch {
                print("🔐 Failed to set display name: \(error.localizedDescription)")
                // Don't fail the signup for this - just log it
            }

            // Create UserProfile document in Firestore
            let userProfile = UserProfile(
                id: user.uid,
                email: user.email ?? validatedEmail,
                displayName: validatedDisplayName,
                createdAt: Date()
            )

            do {
                try await userService.createUserProfile(userProfile)

                await MainActor.run {
                    self.isLoading = false
                    print("🔐 User profile created in Firestore successfully")
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.requiresOnboarding = true
                    self.clearErrors()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("🔐 Failed to create user profile in Firestore: \(error.localizedDescription)")
                    self.errorMessage = "Account created but profile setup failed. Please try signing in."
                }
            }
        } catch let validationError as ValidationError {
            // Handle validation errors
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = validationError.localizedDescription
            }
        } catch {
            let nsError = error as NSError
            print("🔐 Sign up failed with error: \(error.localizedDescription)")
            print("🔐 Error code: \(nsError.code), domain: \(nsError.domain)")

            await MainActor.run {
                self.isLoading = false

                // Map Firebase error codes to user-friendly messages
                switch nsError.code {
                case 17007: // Email already in use
                    self.errorMessage = "This email is already registered. Please sign in instead."
                case 17008: // Invalid email
                    self.errorMessage = "Invalid email address format."
                case 17026: // Weak password
                    self.errorMessage = "Password is too weak. Please use at least 8 characters with uppercase, lowercase, and number."
                default:
                    self.errorMessage = "Sign up failed: \(error.localizedDescription)"
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

            // Clear Firestore cache for security (prevents data exposure on stolen/lost devices)
            clearFirestoreCache()

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

    /// Clear Firestore offline cache on sign-out for security
    /// Prevents unauthorized access to cached data if device is stolen/lost
    private func clearFirestoreCache() {
        Task {
            do {
                // First, disable the network to prevent active queries
                Firestore.firestore().disableNetwork { error in
                    if let error = error {
                        print("⚠️ Failed to disable network: \(error.localizedDescription)")
                    }
                }

                // Wait a moment for queries to complete
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Now try to clear persistence
                try await Firestore.firestore().clearPersistence()
                print("🔐 Firestore cache cleared successfully")

                // Re-enable network for next user
                Firestore.firestore().enableNetwork { error in
                    if let error = error {
                        print("⚠️ Failed to re-enable network: \(error.localizedDescription)")
                    }
                }
            } catch {
                // Note: clearPersistence() can only be called when Firestore is not actively used
                // If it fails, we log it but don't block sign-out
                print("⚠️ Failed to clear Firestore cache (may be in use): \(error.localizedDescription)")

                // Re-enable network if disabled
                Firestore.firestore().enableNetwork { error in
                    if let error = error {
                        print("⚠️ Failed to re-enable network: \(error.localizedDescription)")
                    } else {
                        print("🔐 Firestore network re-enabled - cache will persist until next app restart")
                    }
                }
            }
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
                    let profile = try await userService.getUserProfile(userId: user.uid)
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

    // MARK: - Sign in with Apple Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }

            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random) % charset.count])
                    remaining -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    func signInWithApple() {
        clearErrors()
        isLoading = true

        let nonce = randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { isLoading = false }

        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                errorMessage = "Invalid state: missing nonce"
                return
            }
            guard let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                errorMessage = "Failed to fetch identity token"
                return
            }

            let credential = OAuthProvider.credential(providerID: AuthProviderID.apple, idToken: idTokenString, rawNonce: nonce)

            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                        print("🔐 Apple Sign-In error: \(error)")
                    } else if let user = authResult?.user {
                        print("🔐 Apple Sign-In succeeded for user: \(user.uid)")
                        self?.checkUserAuthorization()
                    }
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        errorMessage = "Apple Sign-In error: \(error.localizedDescription)"
        print("🔐 Apple Sign-In failed: \(error)")
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window
        }
        // Fallback: force-create a UIWindow (should rarely happen in normal app lifecycle)
        return UIWindow()
    }
}
