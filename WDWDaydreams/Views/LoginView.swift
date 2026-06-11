import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.theme) var theme: Theme
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUpMode = false
    @State private var showingForgotPassword = false

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundCream
                    .edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                        // Wordmark
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                            Text("Park DayDreams")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(theme.primaryText)

                            Text("Share magical theme park moments with your partner")
                                .font(DesignSystem.Typography.subtext)
                                .foregroundColor(theme.secondaryText)
                        }
                        .padding(.top, DesignSystem.Spacing.xl)

                        // SSO buttons
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Button(action: {
                                authViewModel.signInWithApple()
                            }) {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "applelogo")
                                        .font(.body.weight(.medium))
                                    Text("Continue with Apple")
                                        .font(.system(.body, design: .default).weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ParkButtonStyle(color: Color(white: 0.05)))
                            .disabled(authViewModel.isLoading)

                            Button(action: {
                                authViewModel.signInWithGoogle()
                            }) {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "globe")
                                        .font(.body.weight(.medium))
                                    Text("Continue with Google")
                                        .font(.system(.body, design: .default).weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ParkButtonStyle(color: theme.cardBackground, textColor: theme.primaryText))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .stroke(theme.hairline, lineWidth: 1)
                            )
                            .disabled(authViewModel.isLoading)
                        }

                        // Divider
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Hairline().frame(maxWidth: .infinity)
                            Text("or")
                                .font(DesignSystem.Typography.meta)
                                .foregroundColor(theme.tertiaryText)
                            Hairline().frame(maxWidth: .infinity)
                        }

                        // Email/Password form
                        VStack(spacing: DesignSystem.Spacing.md) {
                            if isSignUpMode {
                                UnderlineTextField(
                                    placeholder: "Display Name",
                                    text: $displayName,
                                    theme: theme
                                )
                            }

                            UnderlineTextField(
                                placeholder: "Email",
                                text: $email,
                                theme: theme,
                                keyboardType: .emailAddress
                            )
                            .autocapitalization(.none)
                            .onChange(of: email) { _, _ in
                                if !authViewModel.errorMessage.isEmpty {
                                    authViewModel.errorMessage = ""
                                }
                            }

                            UnderlineTextField(
                                placeholder: "Password",
                                text: $password,
                                theme: theme,
                                isSecure: true
                            )
                            .onChange(of: password) { _, _ in
                                if !authViewModel.errorMessage.isEmpty {
                                    authViewModel.errorMessage = ""
                                }
                            }
                        }

                        // Error
                        if !authViewModel.errorMessage.isEmpty {
                            Text(authViewModel.errorMessage)
                                .font(DesignSystem.Typography.subtext)
                                .foregroundColor(theme.accentRed)
                                .transition(.opacity)
                        }

                        // Actions
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Button(action: {
                                Task {
                                    if isSignUpMode {
                                        await authViewModel.signUp(email: email, password: password, displayName: displayName)
                                    } else {
                                        await authViewModel.signIn(email: email, password: password)
                                    }
                                }
                            }) {
                                HStack {
                                    if authViewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Text(isSignUpMode ? "Create Account" : "Sign In")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(ParkButtonStyle(color: theme.primaryBlue))
                            .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty || (isSignUpMode && displayName.isEmpty))
                            .opacity((email.isEmpty || password.isEmpty || (isSignUpMode && displayName.isEmpty)) ? 0.5 : 1)

                            HStack(spacing: DesignSystem.Spacing.lg) {
                                Button(action: {
                                    isSignUpMode.toggle()
                                    email = ""
                                    password = ""
                                    displayName = ""
                                }) {
                                    Text(isSignUpMode ? "Already have an account? Sign in" : "No account? Sign up")
                                        .font(DesignSystem.Typography.subtext)
                                        .foregroundColor(theme.primaryBlue)
                                }

                                if !isSignUpMode {
                                    Spacer()
                                    Button("Forgot Password?") {
                                        showingForgotPassword = true
                                    }
                                    .font(DesignSystem.Typography.subtext)
                                    .foregroundColor(theme.secondaryText)
                                }
                            }
                        }

                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.pageMargin)
                }
            }
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
                .environment(\.theme, theme)
        }
    }
}

// MARK: - Underline Text Field
/// Text field with a single underline — no container, no box, no shadow.
/// The underline thickens and tints when focused, giving clear state feedback.
struct UnderlineTextField: View {
    let placeholder: String
    @Binding var text: String
    let theme: Theme
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .focused($isFocused)
            .font(DesignSystem.Typography.body)
            .autocorrectionDisabled()
            .padding(.vertical, DesignSystem.Spacing.xs)

            Rectangle()
                .fill(isFocused ? theme.primaryBlue : theme.hairline)
                .frame(height: isFocused ? 2 : 1)
                .animation(DesignSystem.Animation.quick, value: isFocused)
        }
    }
}

// MARK: - Park Text Field Style (kept for compatibility)
struct ParkTextFieldStyle: TextFieldStyle {
    let theme: Theme

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .stroke(theme.hairline, lineWidth: 1)
            )
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) var theme: Theme
    @State private var email = ""
    @State private var isLoading = false
    @State private var message = ""
    @State private var showingAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundCream
                    .edgesIgnoringSafeArea(.all)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text("Reset Password")
                        .font(DesignSystem.Typography.pageTitle)
                        .foregroundColor(theme.primaryText)
                        .padding(.top, DesignSystem.Spacing.lg)

                    Text("Enter your email address and we'll send you a password reset link.")
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    UnderlineTextField(
                        placeholder: "Email",
                        text: $email,
                        theme: theme,
                        keyboardType: .emailAddress
                    )
                    .autocapitalization(.none)

                    Button("Send Reset Link") {
                        Task {
                            await resetPassword()
                        }
                    }
                    .buttonStyle(ParkButtonStyle(color: email.isEmpty ? Color.gray : theme.primaryBlue))
                    .disabled(email.isEmpty || isLoading)
                    .opacity(email.isEmpty ? 0.5 : 1)

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: theme.primaryBlue))
                    }

                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.pageMargin)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.primaryBlue)
                }
            }
            .alert("Password Reset", isPresented: $showingAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(message)
            }
        }
    }

    private func resetPassword() async {
        isLoading = true
        do {
            try await FirebaseAuth.Auth.auth().sendPasswordReset(withEmail: email)
            await MainActor.run {
                message = "Reset link sent to \(email)."
                showingAlert = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                message = error.localizedDescription
                showingAlert = true
                isLoading = false
            }
        }
    }
}
