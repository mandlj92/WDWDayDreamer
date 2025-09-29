// Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: ScenarioManager
    @EnvironmentObject var weatherManager: WDWWeatherManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showSettings = false
    @State private var currentView = "Today"
    @State private var isInitializing = true
    @State private var showLogoutAlert = false
    @State private var errorMessage = ""

    // Optimized theme computation - only changes when theme selection changes
    @State private var currentTheme: Theme = LightTheme()

    var body: some View {
        ZStack {
            // Background color
            currentTheme.backgroundCream
                .edgesIgnoringSafeArea(.all)

            // Background sparkle decoration
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 80))
                        .foregroundColor(currentTheme.mainStreetGold.opacity(0.1))
                    Spacer()
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 60))
                        .foregroundColor(currentTheme.magicBlue.opacity(0.1))
                    Spacer()
                }
                .offset(y: 20)
            }
            .edgesIgnoringSafeArea(.bottom)

            // Main Content
            if !authViewModel.isAuthenticated {
                LoginView()
                    .environmentObject(authViewModel)
                    .environment(\.theme, currentTheme)
            } else {
                NavigationView {
                    VStack {
                        Picker("View", selection: $currentView) {
                            Text("Today").tag("Today")
                            Text("History").tag("History")
                            Text("Favorites").tag("Favorites")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        .background(currentTheme.backgroundCream)

                        // Content based on selected tab
                        switch currentView {
                        case "Today":
                            TodayView()
                                .environment(\.theme, currentTheme)
                        case "History":
                            HistoryView()
                                .environment(\.theme, currentTheme)
                        case "Favorites":
                            FavoritesView()
                                .environment(\.theme, currentTheme)
                        default:
                            TodayView()
                                .environment(\.theme, currentTheme)
                        }
                    }
                    .navigationTitle("Disney Daydreams")
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Disney Daydreams")
                                .font(.disneyTitle(24))
                                .foregroundColor(currentTheme.magicBlue)
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            WeatherWidget(weatherManager: weatherManager)
                                .environment(\.theme, currentTheme)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HStack {
                                Button(action: { showSettings = true }) {
                                    Image(systemName: "gear")
                                }
                                Button(action: { showLogoutAlert = true }) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                }
                            }
                            .foregroundColor(currentTheme.magicBlue)
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsView()
                            .environment(\.theme, currentTheme)
                    }
                    .alert(isPresented: $showLogoutAlert) {
                        Alert(
                            title: Text("Sign Out"),
                            message: Text("Are you sure?"),
                            primaryButton: .destructive(Text("Sign Out"), action: authViewModel.signOut),
                            secondaryButton: .cancel()
                        )
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }

            if isInitializing {
                LoadingOverlayView(theme: currentTheme)
            }
            if !errorMessage.isEmpty {
                ErrorToastView(message: $errorMessage, theme: currentTheme)
            }
        }
        .preferredColorScheme(
            themeManager.selectedTheme == .light ? .light :
            (themeManager.selectedTheme == .dark ? .dark : nil)
        )
        .onAppear {
            updateTheme()
            setupApp()
            weatherManager.fetchWeather()
        }
        .onChange(of: themeManager.selectedTheme) { _, _ in
            updateTheme()
        }
        .onReceive(authViewModel.$errorMessage) { msg in
            if !msg.isEmpty {
                errorMessage = msg
                authViewModel.errorMessage = ""
            }
        }
    }

    private func updateTheme() {
        switch themeManager.selectedTheme {
        case .light:
            currentTheme = LightTheme()
        case .dark:
            currentTheme = DarkTheme()
        case .system:
            currentTheme = UITraitCollection.current.userInterfaceStyle == .dark ? DarkTheme() : LightTheme()
        }
    }

    private func setupApp() {
        isInitializing = true
        FirebaseDataService.shared.ensureDatabaseSetup { success in
            if success {
                manager.generateOrUpdateDailyPrompt()
            } else {
                errorMessage = "Error setting up database."
            }
            isInitializing = false
        }
    }
}

// MARK: - Subviews
struct LoadingOverlayView: View {
    let theme: Theme
    
    var body: some View {
        Color.black.opacity(0.4)
            .edgesIgnoringSafeArea(.all)
        VStack {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(theme.mainStreetGold)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
                .padding()
            Text("Setting up your Daydreams...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.magicBlue)
                .shadow(radius: 10)
        )
    }
}

struct ErrorToastView: View {
    @Binding var message: String
    let theme: Theme
    
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .padding()
                .background(theme.mickeyRed.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            message = ""
                        }
                    }
                }
        }
        .transition(.move(edge: .bottom))
        .animation(.easeInOut, value: message)
    }
}

// MARK: - Environment Key for Theme
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = LightTheme()
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
