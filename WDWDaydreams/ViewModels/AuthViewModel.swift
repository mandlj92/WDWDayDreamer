import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

final class AuthViewModel: NSObject, ObservableObject {  // ← Changed: Now inherits from NSObject
    @Published private(set) var isAuthenticated: Bool
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private let firebaseService: FirebaseDataService
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    // For Apple Sign-In
    private var currentNonce: String?

    override init() {  // ← Changed: Now uses override init()
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        self.firebaseService = FirebaseDataService.shared
        self.isAuthenticated = Auth.auth().currentUser != nil
        
        super.init()  // ← Added: Call super.init()
        
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
                        } else {
                            print("🔐 Google Sign-In successful!")
                            // The auth state listener will handle updating isAuthenticated
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Apple Sign-In
    func signInWithApple() {
        print("🔐 Attempting Apple Sign-In")
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        isLoading = true
        errorMessage = ""
        
        authorizationController.performRequests()
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
    
    // MARK: - Apple Sign-In Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
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
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("🔐 Unable to fetch identity token")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Unable to fetch identity token"
                }
                return
            }
            
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("🔐 Unable to serialize token string from data")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Unable to serialize token"
                }
                return
            }
            
            let credential = OAuthProvider.credential(providerID: AuthProviderID.apple,
                                                    idToken: idTokenString,
                                                    rawNonce: nonce)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("🔐 Apple Sign-In error: \(error)")
                        self.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                    } else {
                        print("🔐 Apple Sign-In successful!")
                        // The auth state listener will handle updating isAuthenticated
                    }
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("🔐 Apple Sign-In error: \(error)")
        DispatchQueue.main.async {
            self.isLoading = false
            
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    // User canceled, don't show error
                    break
                default:
                    self.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                }
            } else {
                self.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
