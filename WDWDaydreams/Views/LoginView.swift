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
                    VStack(spacing: 30) {
                        // Disney-themed header
                        VStack(spacing: 15) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 80))
                                .foregroundColor(theme.magicBlue)
                            
                            Text("WDW Daydreams")
                                .font(.disneyTitle(32))
                                .foregroundColor(theme.magicBlue)
                            
                            Text("Share magical Disney moments with your partner")
                                .font(.subheadline)
                                .foregroundColor(theme.magicBlue.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Social Sign-In Buttons
                        VStack(spacing: 15) {
                            // Apple Sign In
                            Button(action: {
                                authViewModel.signInWithApple()
                            }) {
                                HStack {
                                    Image(systemName: "applelogo")
                                        .font(.title2)
                                    Text("Continue with Apple")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(authViewModel.isLoading)
                            
                            // Google Sign In
                            Button(action: {
                                Task {
                                    await authViewModel.signInWithGoogle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "globe")
                                        .font(.title2)
                                    Text("Continue with Google")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(10)
                            }
                            .disabled(authViewModel.isLoading)
                        }
                        .padding(.horizontal)
                        
                        // Divider
                        HStack {
                            VStack { Divider() }
                            Text("or")
                                .foregroundColor(theme.magicBlue.opacity(0.6))
                                .padding(.horizontal, 8)
                            VStack { Divider() }
                        }
                        .padding(.horizontal)
                        
                        // Email/Password Form
                        VStack(spacing: 15) {
                            if isSignUpMode {
                                TextField("Display Name", text: $displayName)
                                    .textFieldStyle(DisneyTextFieldStyle(theme: theme))
                            }
                            
                            TextField("Email", text: $email)
                                .textFieldStyle(DisneyTextFieldStyle(theme: theme))
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(DisneyTextFieldStyle(theme: theme))
                        }
                        .padding(.horizontal)
                        
                        // Email/Password Action buttons
                        VStack(spacing: 15) {
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
                                }
                            }
                            .buttonStyle(DisneyButtonStyle(color: theme.magicBlue))
                            .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty || (isSignUpMode && displayName.isEmpty))
                            
                            Button(action: {
                                isSignUpMode.toggle()
                                email = ""
                                password = ""
                                displayName = ""
                            }) {
                                Text(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                    .font(.footnote)
                                    .foregroundColor(theme.magicBlue)
                            }
                            
                            if !isSignUpMode {
                                Button("Forgot Password?") {
                                    showingForgotPassword = true
                                }
                                .font(.footnote)
                                .foregroundColor(theme.magicBlue.opacity(0.7))
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top)
                }
            }
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
                .environment(\.theme, theme)
        }
    }
}

// MARK: - Custom Text Field Style

struct DisneyTextFieldStyle: TextFieldStyle {
    let theme: Theme
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .shadow(color: theme.magicBlue.opacity(0.2), radius: 3, x: 0, y: 2)
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
                
                VStack(spacing: 20) {
                    Text("Reset Password")
                        .font(.disneyTitle(24))
                        .foregroundColor(theme.magicBlue)
                    
                    Text("Enter your email address and we'll send you a password reset link.")
                        .font(.subheadline)
                        .foregroundColor(theme.magicBlue.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(DisneyTextFieldStyle(theme: theme))
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    Button("Send Reset Link") {
                        Task {
                            await resetPassword()
                        }
                    }
                    .buttonStyle(DisneyButtonStyle(color: email.isEmpty ? .gray : theme.magicBlue))
                    .disabled(email.isEmpty || isLoading)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: theme.magicBlue))
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.magicBlue)
                }
            }
        }
        .alert("Password Reset", isPresented: $showingAlert) {
            Button("OK") {
                if message.contains("sent") {
                    dismiss()
                }
            }
        } message: {
            Text(message)
        }
    }
    
    private func resetPassword() async {
        isLoading = true
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            message = "Password reset link sent to \(email)"
        } catch {
            message = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
        showingAlert = true
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
