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
    
    private let userService = UserService()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
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
                    await self?.loadUserProfile(for: user.uid)
                } else {
                    self?.userProfile = nil
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
        authenticationError = nil
        errorMessage = ""
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await loadUserProfile(for: result.user.uid)
        } catch {
            let authError = AuthError.signInFailed(error.localizedDescription)
            authenticationError = authError
            errorMessage = authError.localizedDescription
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        authenticationError = nil
        errorMessage = ""
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Create user profile with new structure
            let userProfile = UserProfile(
                id: result.user.uid,
                email: email,
                displayName: displayName,
                avatarURL: nil,
                bio: nil,
                createdAt: Date(),
                connectionIds: [],
                pendingInvitations: [],
                preferences: UserPreferences()
            )
            
            try await userService.createUserProfile(userProfile)
            self.userProfile = userProfile
            
        } catch {
            let authError = AuthError.signUpFailed(error.localizedDescription)
            authenticationError = authError
            errorMessage = authError.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async {
        isLoading = true
        authenticationError = nil
        errorMessage = ""
        
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let presentingViewController = windowScene.windows.first?.rootViewController else {
                throw AuthError.googleSignInFailed("Unable to find presenting view controller")
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.googleSignInFailed("Failed to get ID token from Google")
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // Check if user profile exists, create if needed
            let existingProfile = try await userService.getUserProfile(userId: authResult.user.uid)
            if existingProfile == nil {
                // Create user profile with new structure
                let userProfile = UserProfile(
                    id: authResult.user.uid,
                    email: authResult.user.email ?? "",
                    displayName: authResult.user.displayName ?? "Google User",
                    avatarURL: authResult.user.photoURL?.absoluteString,
                    bio: nil,
                    createdAt: Date(),
                    connectionIds: [],
                    pendingInvitations: [],
                    preferences: UserPreferences()
                )
                try await userService.createUserProfile(userProfile)
                self.userProfile = userProfile
            } else {
                self.userProfile = existingProfile
            }
            
        } catch {
            let authError = AuthError.googleSignInFailed(error.localizedDescription)
            authenticationError = authError
            errorMessage = authError.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.performRequests()
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            errorMessage = ""
        } catch {
            let authError = AuthError.signOutFailed(error.localizedDescription)
            authenticationError = authError
            errorMessage = authError.localizedDescription
        }
    }
    
    // MARK: - Private Methods
    
    private func loadUserProfile(for userId: String) async {
        do {
            userProfile = try await userService.getUserProfile(userId: userId)
        } catch {
            let authError = AuthError.profileLoadFailed(error.localizedDescription)
            authenticationError = authError
            errorMessage = authError.localizedDescription
        }
    }
}

// MARK: - Apple Sign In Delegate

extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            isLoading = true
            
            do {
                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    guard let nonce = generateNonce() else {
                        throw AuthError.appleSignInFailed("Unable to generate nonce")
                    }
                    
                    guard let appleIDToken = appleIDCredential.identityToken else {
                        throw AuthError.appleSignInFailed("Unable to fetch identity token")
                    }
                    
                    guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                        throw AuthError.appleSignInFailed("Unable to serialize token string from data")
                    }
                    
                    let credential = OAuthProvider.credential(
                        providerID: AuthProviderID.apple,
                        idToken: idTokenString,
                        rawNonce: nonce
                    )
                    
                    let authResult = try await Auth.auth().signIn(with: credential)
                    
                    // Check if user profile exists, create if needed
                    let existingProfile = try await userService.getUserProfile(userId: authResult.user.uid)
                    if existingProfile == nil {
                        let displayName = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
                            .compactMap { $0 }
                            .joined(separator: " ")
                        
                        // Create user profile with new structure
                        let userProfile = UserProfile(
                            id: authResult.user.uid,
                            email: appleIDCredential.email ?? authResult.user.email ?? "",
                            displayName: displayName.isEmpty ? "Apple User" : displayName,
                            avatarURL: nil,
                            bio: nil,
                            createdAt: Date(),
                            connectionIds: [],
                            pendingInvitations: [],
                            preferences: UserPreferences()
                        )
                        try await userService.createUserProfile(userProfile)
                        self.userProfile = userProfile
                    } else {
                        self.userProfile = existingProfile
                    }
                }
            } catch {
                let authError = AuthError.appleSignInFailed(error.localizedDescription)
                authenticationError = authError
                errorMessage = authError.localizedDescription
            }
            
            isLoading = false
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            let authError = AuthError.appleSignInFailed(error.localizedDescription)
            authenticationError = authError
            errorMessage = authError.localizedDescription
            isLoading = false
        }
    }
    
    private func generateNonce() -> String? {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = 32
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
}

// MARK: - Auth Error Types

enum AuthError: LocalizedError {
    case signInFailed(String)
    case signUpFailed(String)
    case signOutFailed(String)
    case profileLoadFailed(String)
    case googleSignInFailed(String)
    case appleSignInFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .profileLoadFailed(let message):
            return "Failed to load profile: \(message)"
        case .googleSignInFailed(let message):
            return "Google sign in failed: \(message)"
        case .appleSignInFailed(let message):
            return "Apple sign in failed: \(message)"
        }
    }
}
