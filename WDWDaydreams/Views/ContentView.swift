// Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: ScenarioManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var feedbackCenter: UIFeedbackCenter

    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    @StateObject private var editorState = EditorStateManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared

    @State private var showSettings = false
    @State private var currentView = "Today"
    @State private var isInitializing = true
    @State private var showLogoutAlert = false
    @State private var errorMessage: String?
    @State private var showingNavigationWarning = false
    @State private var targetView: String?
    @State private var showFirstPartnershipGuide = false

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
                        .foregroundColor(currentTheme.accentGold.opacity(0.1))
                    Spacer()
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 60))
                        .foregroundColor(currentTheme.primaryBlue.opacity(0.1))
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
                    VStack(spacing: 0) {
                        // Offline banner
                        if !networkMonitor.isConnected {
                            HStack {
                                Image(systemName: "wifi.slash")
                                Text("You're offline. Changes will sync when reconnected.")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                        }

                        Picker("View", selection: Binding(
                            get: { currentView },
                            set: { newValue in
                                // Check if leaving Today tab with unsaved changes
                                if currentView == "Today" && editorState.hasUnsavedStoryChanges {
                                    targetView = newValue
                                    showingNavigationWarning = true
                                } else {
                                    currentView = newValue
                                }
                            }
                        )) {
                            Text("Today").tag("Today")
                            Text("Pals").tag("Pals")
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
                        case "Pals":
                            PalsView()
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
                    .navigationTitle("Park DayDreams")
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Park DayDreams")
                                .font(.parkTitle(24))
                                .foregroundColor(currentTheme.primaryBlue)
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
                            .foregroundColor(currentTheme.primaryBlue)
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
                    .alert("Unsaved Changes", isPresented: $showingNavigationWarning) {
                        Button("Discard", role: .destructive) {
                            if let target = targetView {
                                editorState.hasUnsavedStoryChanges = false
                                currentView = target
                            }
                        }
                        Button("Keep Editing", role: .cancel) {}
                    } message: {
                        Text("You have unsaved changes in your story. Are you sure you want to leave?")
                    }
                    .sheet(isPresented: $showFirstPartnershipGuide) {
                        FirstPartnershipGuideView(
                            onCreateInvite: {
                                // Switch to Pals tab to create invite
                                currentView = "Pals"
                                // The PalsView will show its invitation creation UI
                            },
                            onJoinCode: {
                                // Switch to Pals tab to join with code
                                currentView = "Pals"
                                // The PalsView will show its code entry UI
                            }
                        )
                        .environment(\.theme, currentTheme)
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }

            if isInitializing {
                LoadingOverlayView(theme: currentTheme)
            }
            FeedbackBannerView(banner: $feedbackCenter.currentBanner)
        }
        .preferredColorScheme(
            themeManager.selectedTheme == .light ? .light :
            (themeManager.selectedTheme == .dark ? .dark : nil)
        )
        .onAppear {
            updateTheme()
            setupApp()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("ShowFirstPartnershipGuide")
            )
        ) { _ in
            // Only show if user has no partnerships
            if manager.userPartnerships.isEmpty {
                showFirstPartnershipGuide = true
            }
        }
        .onChange(of: themeManager.selectedTheme) { _, _ in
            updateTheme()
        }
        .onReceive(authViewModel.$errorMessage) { msg in
            if !msg.isEmpty {
                feedbackCenter.present(message: msg, style: .error)
                authViewModel.errorMessage = ""
            }
        }
        .onChange(of: navigationCoordinator.shouldNavigate) { _, shouldNav in
            if shouldNav, let partnershipId = navigationCoordinator.targetPartnershipId {
                // Switch to Today tab
                currentView = "Today"

                // Select the partnership
                Task {
                    if let partnership = manager.userPartnerships.first(where: { $0.id == partnershipId }) {
                        await manager.selectPartnership(partnership)
                    }

                    // Clear navigation state
                    navigationCoordinator.clearNavigation()
                }
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
        FirebaseDataService.shared.ensureDatabaseSetup { [weak authViewModel, weak manager] success in
            if success {
                Task { @MainActor in
                    if let userId = authViewModel?.userProfile?.id, let manager = manager {
                        await manager.initialize(userId: userId)
                    }
                    self.isInitializing = false
                }
            } else {
                self.errorMessage = "Error setting up database."
                self.isInitializing = false
            }
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
                .foregroundColor(theme.accentGold)
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
                .fill(theme.primaryBlue)
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
                .background(theme.accentRed.opacity(0.9))
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
