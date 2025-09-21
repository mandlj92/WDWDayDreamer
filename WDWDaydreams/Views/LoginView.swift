// Views/LoginView.swift - Secure version with no hardcoded credentials
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [DisneyColors.backgroundCream, Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 30) {
                    // App title with Disney font
                    Text("Disney Daydreams")
                        .font(.disneyTitle(32))
                        .foregroundColor(DisneyColors.magicBlue)
                        .padding(.top, 40)

                    // Disney-themed icon with sparkles effect
                    ZStack {
                        Circle()
                            .fill(DisneyColors.backgroundCream)
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.1), radius: 5)

                        Image(systemName: "sparkles")
                            .font(.system(size: 50))
                            .foregroundColor(DisneyColors.mainStreetGold)
                    }
                    .padding(.bottom, 20)

                    Text("Sign in to continue your magical journey")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(DisneyColors.magicBlue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Google Sign-In Section
                    VStack(spacing: 16) {
                        Text("Sign in with")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Google Sign-In Button
                        Button(action: {
                            authViewModel.signInWithGoogle()
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Continue with Google")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .disabled(authViewModel.isLoading)
                    }
                    .padding(.horizontal, 30)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 30)

                    // Email/Password Login form
                    VStack(spacing: 20) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(DisneyColors.magicBlue)
                                .fontWeight(.medium)
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(DisneyTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .focused($emailFocused)
                                .onSubmit {
                                    passwordFocused = true
                                }
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .foregroundColor(DisneyColors.magicBlue)
                                .fontWeight(.medium)
                            
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("Enter your password", text: $password)
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                    }
                                }
                                .textFieldStyle(DisneyTextFieldStyle())
                                .textContentType(.password)
                                .focused($passwordFocused)
                                .onSubmit {
                                    signIn()
                                }
                                
                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(DisneyColors.magicBlue)
                                        .padding(.trailing, 12)
                                }
                            }
                        }

                        // Sign in button
                        Button(action: signIn) {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "person.fill")
                                    Text("Sign In")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                DisneyColors.magicBlue.opacity(isSignInEnabled ? 1.0 : 0.6)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        }
                        .disabled(!isSignInEnabled || authViewModel.isLoading)
                    }
                    .padding(.horizontal, 30)

                    // Error message display
                    if !authViewModel.errorMessage.isEmpty {
                        Text(authViewModel.errorMessage)
                            .foregroundColor(DisneyColors.mickeyRed)
                            .font(.caption)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(DisneyColors.mickeyRed.opacity(0.1))
                            )
                            .multilineTextAlignment(.center)
                    }

                    Spacer(minLength: 50)
                }
                .padding()
            }
            .ignoresSafeArea(.keyboard, edges: .bottom) // <-- ADD THIS MODIFIER
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            emailFocused = false
            passwordFocused = false
        }
    }
    
    private var isSignInEnabled: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private func signIn() {
        guard isSignInEnabled else { return }
        
        emailFocused = false
        passwordFocused = false
        
        authViewModel.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                          password: password)
    }
}

// Custom text field style
struct DisneyTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(DisneyColors.mainStreetGold.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Preview providers
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
