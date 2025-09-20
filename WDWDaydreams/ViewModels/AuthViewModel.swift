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

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func login(email: String, password: String) {
        isLoading = true
        errorMessage = ""

        firebaseService.loginUser(email: email, password: password) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = error
                } else if !success {
                    self.errorMessage = "Login failed. Please try again."
                }
            }
        }
    }

    func signOut() {
        if !firebaseService.signOutUser() {
            errorMessage = "Unable to sign out. Please try again."
        }
    }
}
