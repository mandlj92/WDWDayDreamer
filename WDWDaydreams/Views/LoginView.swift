// Views/LoginView.swift
import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject var manager: ScenarioManager
    @EnvironmentObject var weatherManager: WDWWeatherManager
    
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
                        isLoading: viewModel.isLoading
                    ) {
                        viewModel.loginAs(email: "jon@example.com", password: "password123")
                    }
                    
                    UserLoginButton(
                        name: "Carolyn",
                        icon: "person.fill",
                        color: DisneyColors.fantasyPurple,
                        isLoading: viewModel.isLoading
                    ) {
                        viewModel.loginAs(email: "carolyn@example.com", password: "password123")
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DisneyColors.magicBlue))
                        .scaleEffect(1.2)
                        .padding()
                }
                
                Spacer()
                
                // Error message display
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(DisneyColors.mickeyRed)
                        .font(.caption)
                        .padding()
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .fullScreenCover(isPresented: $viewModel.isLoggedIn) {
                ContentView()
                    .environmentObject(manager)
                    .environmentObject(weatherManager)
            }
            .onAppear {
                viewModel.createTestAccounts()
            }
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
            .environmentObject(ScenarioManager())
            .environmentObject(WDWWeatherManager())
    }
}
