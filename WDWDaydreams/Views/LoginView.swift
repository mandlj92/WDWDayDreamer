// Views/LoginView.swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [DisneyColors.backgroundCream, Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 30) {
                // App title with Disney font
                Text("Disney Daydreams")
                    .font(.disneyTitle(32))
                    .foregroundColor(DisneyColors.magicBlue)
                    .padding(.top, 40)

                Spacer()

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

                Text("Who's daydreaming today?")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(DisneyColors.magicBlue)
                    .padding()

                // User buttons with themed styling
                VStack(spacing: 20) {
                    UserLoginButton(
                        name: "Jonathan",
                        icon: "person.fill",
                        color: DisneyColors.magicBlue,
                        isLoading: authViewModel.isLoading
                    ) {
                        // Use real email from AccountSetupHelper
                        authViewModel.login(email: "jonathanfmandl@gmail.com", password: "Yunchie309!")
                    }

                    UserLoginButton(
                        name: "Carolyn",
                        icon: "person.fill",
                        color: DisneyColors.fantasyPurple,
                        isLoading: authViewModel.isLoading
                    ) {
                        // Use real email from AccountSetupHelper
                        authViewModel.login(email: "carolnyingrid9@gmail.com", password: "Dancing006!!!")
                    }
                }

                if authViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DisneyColors.magicBlue))
                        .scaleEffect(1.2)
                        .padding()
                }

                Spacer()

                // Error message display
                if !authViewModel.errorMessage.isEmpty {
                    Text(authViewModel.errorMessage)
                        .foregroundColor(DisneyColors.mickeyRed)
                        .font(.caption)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                
                // Debug: Add account creation button (remove after testing)
                Button("Create Accounts (Debug)") {
                    AccountSetupHelper.createAccounts { success, message in
                        print("Account creation result: \(success), message: \(message ?? "none")")
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            .padding()
        }
    }
}

struct UserLoginButton: View {
    let name: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(name)
            }
            .frame(minWidth: 200)
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
        }
        .disabled(isLoading)
    }
}

// Preview providers
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ScenarioManager())
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
