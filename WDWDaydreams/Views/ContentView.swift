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

    // Determine the current theme based on manager and system setting
    var theme: Theme {
        switch themeManager.selectedTheme {
        case .light:
            return LightTheme()
        case .dark:
            return DarkTheme()
        case .system:
            // Use the system's color scheme to decide
            return UITraitCollection.current.userInterfaceStyle == .dark ? DarkTheme() : LightTheme()
        }
    }

    var body: some View {
        ZStack {
            // Background color
            theme.backgroundCream
                .edgesIgnoringSafeArea(.all)

            // Background sparkle decoration
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 80))
                        .foregroundColor(theme.mainStreetGold.opacity(0.1))
                    Spacer()
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 60))
                        .foregroundColor(theme.magicBlue.opacity(0.1))
                    Spacer()
                }
                .offset(y: 20)
            }
            .edgesIgnoringSafeArea(.bottom)

            // Main Content
            if !authViewModel.isAuthorized {
                UnauthorizedView().environment(\.theme, theme)
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
                        .background(theme.backgroundCream)

                        // Content based on selected tab
                        if currentView == "Today" {
                            TodayView().environment(\.theme, theme)
                        } else if currentView == "History" {
                            HistoryView().environment(\.theme, theme)
                        } else if currentView == "Favorites" {
                            FavoritesView().environment(\.theme, theme)
                        }
                    }
                    .navigationTitle("Disney Daydreams")
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Disney Daydreams")
                                .font(.disneyTitle(24))
                                .foregroundColor(theme.magicBlue)
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            WeatherWidget(weatherManager: weatherManager).environment(\.theme, theme)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HStack {
                                Button(action: { showSettings = true }) { Image(systemName: "gear") }
                                Button(action: { showLogoutAlert = true }) { Image(systemName: "rectangle.portrait.and.arrow.right") }
                            }
                            .foregroundColor(theme.magicBlue)
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsView().environment(\.theme, theme)
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

            if isInitializing { LoadingOverlayView(theme: theme) }
            if !errorMessage.isEmpty { ErrorToastView(message: $errorMessage, theme: theme) }
        }
        .preferredColorScheme(
            themeManager.selectedTheme == .light ? .light :
            (themeManager.selectedTheme == .dark ? .dark : nil)
        )
        .onAppear {
            setupApp()
            weatherManager.fetchWeather()
        }
        .onReceive(authViewModel.$errorMessage) { msg in
            if !msg.isEmpty {
                errorMessage = msg
                authViewModel.errorMessage = ""
            }
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

// Environment Key for passing theme
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = LightTheme()
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}


// MARK: - Subviews
struct UnauthorizedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.theme) var theme: Theme
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "lock.shield").font(.system(size: 80))
            Text("Access Restricted").font(.largeTitle).fontWeight(.bold)
            Text("This app is private and only for authorized users.").multilineTextAlignment(.center)
            Button("Try Different Account") { authViewModel.signOut() }
                .buttonStyle(DisneyButtonStyle(color: theme.mickeyRed))
            Spacer()
        }
        .foregroundColor(theme.mickeyRed)
        .padding()
        .background(theme.backgroundCream)
    }
}

struct LoadingOverlayView: View {
    let theme: Theme
    var body: some View {
        Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
        VStack {
            Image(systemName: "sparkles").font(.system(size: 40)).foregroundColor(theme.mainStreetGold)
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.2).padding()
            Text("Setting up your Daydreams...").font(.headline).foregroundColor(.white)
        }
        .padding(30).background(RoundedRectangle(cornerRadius: 20).fill(theme.magicBlue).shadow(radius: 10))
    }
}

struct ErrorToastView: View {
    @Binding var message: String
    let theme: Theme
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .padding().background(theme.mickeyRed.opacity(0.9)).foregroundColor(.white)
                .cornerRadius(10).padding()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { message = "" }
                    }
                }
        }
        .transition(.move(edge: .bottom)).animation(.easeInOut, value: message)
    }
}
