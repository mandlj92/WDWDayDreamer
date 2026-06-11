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
    @FocusState private var passwordFocused: Bool

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Verify It's You")
                        .font(DesignSystem.Typography.pageTitle)
                        .foregroundColor(.primary)
                        .padding(.top, DesignSystem.Spacing.xl)

                    Text(operationDescription)
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    SectionLabel("Password")

                    SecureField("Enter your password", text: $password)
                        .focused($passwordFocused)
                        .font(DesignSystem.Typography.body)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disabled(isAuthenticating)
                        .padding(.vertical, DesignSystem.Spacing.xs)

                    Rectangle()
                        .fill(passwordFocused ? ThemeColors.primaryBlue : Color.primary.opacity(0.12))
                        .frame(height: passwordFocused ? 2 : 1)
                        .animation(DesignSystem.Animation.quick, value: passwordFocused)
                }

                if showError {
                    Text(errorMessage)
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(ThemeColors.accentRed)
                        .transition(.opacity)
                }

                Spacer()

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
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ParkButtonStyle(color: password.isEmpty || isAuthenticating ? .gray : ThemeColors.primaryBlue))
                .disabled(password.isEmpty || isAuthenticating)
                .opacity(password.isEmpty ? 0.5 : 1)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .padding(.horizontal, DesignSystem.Spacing.pageMargin)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isAuthenticating)
                }
            }
            .onAppear { passwordFocused = true }
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
            errorMessage = "Could not get current user information."
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
                    errorMessage = errorDescription(error)
                    showError = true
                    password = ""
                }
            }
        }
    }

    private func errorDescription(_ error: Error) -> String {
        let code = (error as NSError).code

        switch code {
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
