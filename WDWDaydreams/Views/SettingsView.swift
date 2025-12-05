// Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: ScenarioManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var feedbackCenter: UIFeedbackCenter
    @Environment(\.theme) var theme: Theme
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirmation = false
    @State private var testResults: String = ""
    @State private var preferences: UserPreferences = UserPreferences()
    @State private var showingSupport = false
    
    // Computed properties to replace ViewModel
    private var enabledCategories: Binding<[Category]> {
        Binding(
            get: { manager.enabledCategories },
            set: { manager.enabledCategories = $0 }
        )
    }
    
    private var tripDate: Binding<Date?> {
        Binding(
            get: { manager.tripDate },
            set: { manager.tripDate = $0 }
        )
    }
    
    private var showTripCountdown: Bool {
        guard let tripDate = manager.tripDate else { return false }
        return tripDate > Date() && daysUntilTrip >= 0
    }
    
    private var daysUntilTrip: Int {
        guard let tripDate = manager.tripDate else { return 0 }
        return Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: tripDate)).day ?? 0
    }
    
    var body: some View {
        NavigationView { () -> AnyView in
            AnyView(
            ZStack {
                // Use the dynamic theme background color
                theme.backgroundCream
                    .edgesIgnoringSafeArea(.all)
                
                Form {
                    Group {
                        // Title Section
                        Section {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 40))
                                .foregroundColor(theme.magicBlue)
                            
                            Text("Disney Daydreams Settings")
                                .font(.disneyTitle(18))
                                .foregroundColor(theme.magicBlue)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .listRowBackground(theme.backgroundCream)
                    }
                    
                    // App Appearance Section
                    Section(header: SectionHeader(title: "Appearance", theme: theme)) {
                        Picker("Theme", selection: $themeManager.selectedTheme) {
                            ForEach(ThemeOption.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .listRowBackground(theme.cardBackground)

                    // Notification Preferences
                    Section(header: SectionHeader(title: "Notifications", theme: theme)) {
                        Toggle("Story reminders", isOn: Binding(
                            get: { preferences.notifications.storyReminders },
                            set: { preferences.notifications = NotificationPreferences(
                                storyReminders: $0,
                                connectionRequests: preferences.notifications.connectionRequests,
                                newStoryNotifications: preferences.notifications.newStoryNotifications,
                                weeklyDigest: preferences.notifications.weeklyDigest
                            ) }
                        ))
                        Toggle("Connection requests", isOn: Binding(
                            get: { preferences.notifications.connectionRequests },
                            set: { preferences.notifications = NotificationPreferences(
                                storyReminders: preferences.notifications.storyReminders,
                                connectionRequests: $0,
                                newStoryNotifications: preferences.notifications.newStoryNotifications,
                                weeklyDigest: preferences.notifications.weeklyDigest
                            ) }
                        ))
                        Toggle("New story alerts", isOn: Binding(
                            get: { preferences.notifications.newStoryNotifications },
                            set: { preferences.notifications = NotificationPreferences(
                                storyReminders: preferences.notifications.storyReminders,
                                connectionRequests: preferences.notifications.connectionRequests,
                                newStoryNotifications: $0,
                                weeklyDigest: preferences.notifications.weeklyDigest
                            ) }
                        ))
                        Toggle("Weekly digest", isOn: Binding(
                            get: { preferences.notifications.weeklyDigest },
                            set: { preferences.notifications = NotificationPreferences(
                                storyReminders: preferences.notifications.storyReminders,
                                connectionRequests: preferences.notifications.connectionRequests,
                                newStoryNotifications: preferences.notifications.newStoryNotifications,
                                weeklyDigest: $0
                            ) }
                        ))
                        Button("Request Notification Permission") {
                            NotificationManager.shared.requestPermission()
                            feedbackCenter.present(message: "Notification permission requested", style: .info)
                        }
                        .buttonStyle(DisneyButtonStyle(color: theme.magicBlue))
                    }
                    .listRowBackground(theme.cardBackground)

                    // Privacy
                    Section(header: SectionHeader(title: "Privacy & Permissions", theme: theme)) {
                        Picker("Profile visibility", selection: Binding(
                            get: { preferences.privacy.profileVisibility },
                            set: { preferences.privacy = PrivacySettings(
                                profileVisibility: $0,
                                allowStorySharing: preferences.privacy.allowStorySharing,
                                allowConnectionDiscovery: preferences.privacy.allowConnectionDiscovery
                            ) }
                        )) {
                            ForEach(ProfileVisibility.allCases, id: \.self) { visibility in
                                Text(visibility.displayName).tag(visibility)
                            }
                        }
                        Toggle("Allow Story Sharing", isOn: Binding(
                            get: { preferences.privacy.allowStorySharing },
                            set: { preferences.privacy = PrivacySettings(
                                profileVisibility: preferences.privacy.profileVisibility,
                                allowStorySharing: $0,
                                allowConnectionDiscovery: preferences.privacy.allowConnectionDiscovery
                            ) }
                        ))
                        Toggle("Allow Discovery", isOn: Binding(
                            get: { preferences.privacy.allowConnectionDiscovery },
                            set: { preferences.privacy = PrivacySettings(
                                profileVisibility: preferences.privacy.profileVisibility,
                                allowStorySharing: preferences.privacy.allowStorySharing,
                                allowConnectionDiscovery: $0
                            ) }
                        ))
                    }
                    .listRowBackground(theme.cardBackground)
                    }

                    Group {
                    // Category Section
                    Section(header: Text("Enable Categories For Prompts").font(.headline).foregroundColor(theme.magicBlue)) {
                        ForEach(Category.allCases) { category in
                            CategoryToggleRow(
                                category: category,
                                manager: manager,
                                theme: theme
                            )
                        }
                        
                        let enabledCount = Category.allCases.filter { isCategoryEnabled($0) }.count
                        if enabledCount == 1 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("At least one category must be enabled")
                                    .font(.caption)
                            }
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                        }
                    }
                    .listRowBackground(theme.cardBackground)

                    // Trip Countdown Section
                    Section(header: SectionHeader(title: "Trip Countdown", theme: theme)) {
                        DatePicker(
                            "Trip Date",
                            selection: Binding(
                                get: { tripDate.wrappedValue ?? Date() },
                                set: { tripDate.wrappedValue = $0 }
                            ),
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .colorScheme(themeManager.selectedTheme == .dark ? .dark : .light)
                        .foregroundColor(theme.primaryText)

                        if showTripCountdown {
                            TripCountdownRow(days: daysUntilTrip, theme: theme)
                        }
                    }
                    .listRowBackground(theme.cardBackground)

                    // System Tests Section
                    Section(header: SectionHeader(title: "System Tests", theme: theme)) {
                        Button("Test Firebase Connection") {
                            testFirebaseConnection()
                        }
                        .buttonStyle(DisneyButtonStyle(color: theme.magicBlue))
                        
                        if !testResults.isEmpty {
                            Text(testResults)
                                .font(.caption)
                                .foregroundColor(testResults.contains("✅") ? .green : .red)
                                .padding(.top, 4)
                        }
                    }
                    .listRowBackground(theme.cardBackground)

                    Section(header: Text("Account & Support").font(.headline).foregroundColor(theme.magicBlue)) {
                        NavigationLink(destination: AchievementsView()
                                        .environmentObject(authViewModel)
                                        .environmentObject(manager)) {
                            Label("Achievements", systemImage: "rosette")
                        }

                        Button("Save Preferences") {
                            Task {
                                await authViewModel.updatePreferences(preferences)
                                feedbackCenter.present(message: "Preferences saved", style: .success)
                            }
                        }
                        .buttonStyle(DisneyButtonStyle(color: theme.magicBlue))

                        Button("Delete Account", role: .destructive) {
                            Task { await authViewModel.deleteAccount() }
                        }

                        Button("Help & Support") {
                            showingSupport = true
                        }
                    }
                    .listRowBackground(theme.cardBackground)

                    // Danger Zone Section
                    Section(header: Text("Danger Zone").foregroundColor(theme.mickeyRed).font(.headline)) {
                        Button(action: {
                            showClearConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Clear All Story History")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(DisneyButtonStyle(color: theme.mickeyRed))
                        .listRowBackground(theme.backgroundCream)
                    }
                    }
                }
                .scrollContentBackground(.hidden)
                .alert(isPresented: $showClearConfirmation) {
                    Alert(
                        title: Text("Clear History"),
                        message: Text("Are you sure? This cannot be undone."),
                        primaryButton: .destructive(Text("Clear All")) {
                            manager.clearHistory()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.magicBlue)
                    .fontWeight(.semibold)
                }
            }
            )
        }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingSupport) {
            SupportView()
                .environment(\.theme, theme)
        }
        .onAppear {
            preferences = authViewModel.userProfile?.preferences ?? UserPreferences()
        }
    }
    
    // Local helper functions to replace ViewModel methods
    private func isCategoryEnabled(_ category: Category) -> Bool {
        manager.enabledCategories.contains(category)
    }
    
    private func toggleCategory(_ category: Category, isEnabled: Bool) {
        if isEnabled {
            if !manager.enabledCategories.contains(category) {
                manager.enabledCategories.append(category)
                manager.enabledCategories.sort(by: { $0.rawValue < $1.rawValue })
            }
        } else {
            manager.enabledCategories.removeAll { $0 == category }
        }
    }
    
    // Test Firebase connection
    private func testFirebaseConnection() {
        testResults = "Testing..."
        
        FirebaseDataService.shared.testFirebaseConnection { success, message in
            DispatchQueue.main.async {
                testResults = success ? "✅ \(message)" : "❌ \(message)"
            }
        }
    }
}

// MARK: - Subviews
struct SectionHeader: View {
    let title: String
    let theme: Theme
    
    var body: some View {
        Text(title)
            .foregroundColor(theme.magicBlue)
            .font(.headline)
    }
}

struct CategoryToggleRow: View {
    let category: Category
    let manager: ScenarioManager
    let theme: Theme
    
    private var isEnabled: Binding<Bool> {
        Binding(
            get: { manager.enabledCategories.contains(category) },
            set: { newValue in
                let currentlyEnabled = Category.allCases.filter { manager.enabledCategories.contains($0) }
                if !newValue && currentlyEnabled.count <= 1 { return }
                
                if newValue {
                    if !manager.enabledCategories.contains(category) {
                        manager.enabledCategories.append(category)
                        manager.enabledCategories.sort(by: { $0.rawValue < $1.rawValue })
                    }
                } else {
                    manager.enabledCategories.removeAll { $0 == category }
                }
            }
        )
    }
    
    private var isLastEnabled: Bool {
        let currentlyEnabled = Category.allCases.filter { manager.enabledCategories.contains($0) }
        return currentlyEnabled.count == 1 && manager.enabledCategories.contains(category)
    }
    
    var body: some View {
        Toggle(isOn: isEnabled) {
            HStack {
                Image(systemName: CategoryHelper.icon(for: category))
                    .foregroundColor(CategoryHelper.color(for: category))
                
                Text(category.rawValue.capitalized)
                    .foregroundColor(theme.primaryText)
                
                if isLastEnabled {
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: CategoryHelper.color(for: category)))
        .disabled(isLastEnabled)
    }
}

struct TripCountdownRow: View {
    let days: Int
    let theme: Theme
    
    var body: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
            Text("\(days) day\(days == 1 ? "" : "s") until your trip!")
                .font(.headline)
        }
        .foregroundColor(theme.mickeyRed)
        .padding(.vertical, 4)
    }
}
