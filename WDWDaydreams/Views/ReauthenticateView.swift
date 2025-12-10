import SwiftUI
import FirebaseAuth

/// View for re-authenticating before sensitive operations
struct ReauthenticateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sessionManager = SessionManager.shared

    let operation: SessionManager.SensitiveOperation
    let onSuccess: () -> Void

    @State private var password = ""
    @State private var isAuthenticating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Verify It's You")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(operationDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 32)

                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disabled(isAuthenticating)
                }
                .padding(.horizontal)

                Spacer()

                // Verify button
                Button {
                    reauthenticate()
                } label: {
                    HStack {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }

                        Text("Verify")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(password.isEmpty || isAuthenticating ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(password.isEmpty || isAuthenticating)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isAuthenticating)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var operationDescription: String {
        switch operation {
        case .deleteAccount:
            return "Please verify your password to delete your account."
        case .changePassword:
            return "Please verify your current password to change it."
        case .changeEmail:
            return "Please verify your password to change your email."
        case .viewPrivateData:
            return "Please verify your password to view sensitive information."
        case .financialTransaction:
            return "Please verify your password to complete this transaction."
        }
    }

    private func reauthenticate() {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            errorMessage = "Could not get current user information"
            showError = true
            return
        }

        isAuthenticating = true

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        Task {
            do {
                try await user.reauthenticate(with: credential)

                await MainActor.run {
                    isAuthenticating = false
                    sessionManager.requiresReauthentication = false
                    dismiss()
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    errorMessage = getErrorMessage(error)
                    showError = true
                    password = ""
                }
            }
        }
    }

    private func getErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError

        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return "Incorrect password. Please try again."
        case AuthErrorCode.userNotFound.rawValue:
            return "User account not found."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many attempts. Please try again later."
        default:
            return error.localizedDescription
        }
    }
}