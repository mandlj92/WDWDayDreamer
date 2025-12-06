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

    // Binding helpers for notifications
    private var storyRemindersBinding: Binding<Bool> {
        Binding(
            get: { self.preferences.notifications.storyReminders },
            set: { newValue in
                self.preferences.notifications = NotificationPreferences(
                    storyReminders: newValue,
                    connectionRequests: self.preferences.notifications.connectionRequests,
                    newStoryNotifications: self.preferences.notifications.newStoryNotifications,
                    weeklyDigest: self.preferences.notifications.weeklyDigest
                )
            }
        )
    }

    private var connectionRequestsBinding: Binding<Bool> {
        Binding(
            get: { self.preferences.notifications.connectionRequests },
            set: { newValue in
                self.preferences.notifications = NotificationPreferences(
                    storyReminders: self.preferences.notifications.storyReminders,
                    connectionRequests: newValue,
                    newStoryNotifications: self.preferences.notifications.newStoryNotifications,
                    weeklyDigest: self.preferences.notifications.weeklyDigest
                )
            }
        )
    }

    private var newStoryAlertsBinding: Binding<Bool> {
        Binding(
            get: { self.preferences.notifications.newStoryNotifications },
            set: { newValue in
                self.preferences.notifications = NotificationPreferences(
                    storyReminders: self.preferences.notifications.storyReminders,
                    connectionRequests: self.preferences.notifications.connectionRequests,
                    newStoryNotifications: newValue,
                    weeklyDigest: self.preferences.notifications.weeklyDigest
                )
            }
        )
    }

    private var weeklyDigestBinding: Binding<Bool> {
        Binding(
            get: { self.preferences.notifications.weeklyDigest },
            set: { newValue in
                self.preferences.notifications = NotificationPreferences(
                    storyReminders: self.preferences.notifications.storyReminders,
                    connectionRequests: self.preferences.notifications.connectionRequests,
                    newStoryNotifications: self.preferences.notifications.newStoryNotifications,
                    weeklyDigest: newValue
                )
            }
        )
    }

    // Binding helpers for privacy
    private var profileVisibilityBinding: Binding<ProfileVisibility> {
        Binding(
            get: { self.preferences.privacy.profileVisibility },
            set: { newValue in
                self.preferences.privacy = PrivacySettings(
                    profileVisibility: newValue,
                    allowStorySharing: self.preferences.privacy.allowStorySharing,
                    allowConnectionDiscovery: self.preferences.privacy.allowConnectionDiscovery
                )
            }
        )
    }

    private var allowStorySharingBinding: Binding<Bool> {
        Binding(
            get: { self.preferences.privacy.allowStorySharing },
            set: { newValue in
                self.preferences.privacy = PrivacySettings(
                    profileVisibility: self.preferences.privacy.profileVisibility,
                    allowStorySharing: newValue,
                    allowConnectionDiscovery: self.preferences.privacy.allowConnectionDiscovery
                )
            }
        )
    }

    private var allowDiscoveryBinding: Binding<Bool> {
        Binding(
            get: { self.preferences.privacy.allowConnectionDiscovery },
            set: { newValue in
                self.preferences.privacy = PrivacySettings(
                    profileVisibility: self.preferences.privacy.profileVisibility,
                    allowStorySharing: self.preferences.privacy.allowStorySharing,
                    allowConnectionDiscovery: newValue
                )
            }
        )
    }

    var body: some View {
        NavigationView {
            settingsContent
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

    private var settingsContent: some View {
        ZStack {
            theme.backgroundCream
                .edgesIgnoringSafeArea(.all)

            Form {
                Group {
                    titleSection
                    appearanceSection
                    notificationSection
                    privacySection
                }

                Group {
                    categorySection
                    tripCountdownSection
                    systemTestsSection
                    accountSupportSection
                    dangerZoneSection
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
    }

    private var titleSection: some View {
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
    }

    private var appearanceSection: some View {
        Section(header: SectionHeader(title: "Appearance", theme: theme)) {
            Picker("Theme", selection: $themeManager.selectedTheme) {
                ForEach(ThemeOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .listRowBackground(theme.cardBackground)
    }

    private var notificationSection: some View {
        Section(header: SectionHeader(title: "Notifications", theme: theme)) {
            Toggle("Story reminders", isOn: storyRemindersBinding)
            Toggle("Connection requests", isOn: connectionRequestsBinding)
            Toggle("New story alerts", isOn: newStoryAlertsBinding)
            Toggle("Weekly digest", isOn: weeklyDigestBinding)

            Button("Request Notification Permission") {
                NotificationManager.shared.requestPermission()
                feedbackCenter.present(message: "Notification permission requested", style: .info)
            }
            .buttonStyle(DisneyButtonStyle(color: theme.magicBlue))
        }
        .listRowBackground(theme.cardBackground)
    }

    private var privacySection: some View {
        Section(header: SectionHeader(title: "Privacy & Permissions", theme: theme)) {
            Picker("Profile visibility", selection: profileVisibilityBinding) {
                ForEach(ProfileVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.displayName).tag(visibility)
                }
            }
            Toggle("Allow Story Sharing", isOn: allowStorySharingBinding)
            Toggle("Allow Discovery", isOn: allowDiscoveryBinding)
        }
        .listRowBackground(theme.cardBackground)
    }

    private var categorySection: some View {
        let enabledCount = Category.allCases.filter { isCategoryEnabled($0) }.count

        return Section(header: SectionHeader(title: "Enable Categories For Prompts", theme: theme)) {
            ForEach(Category.allCases) { category in
                CategoryToggleRow(
                    category: category,
                    manager: manager,
                    theme: theme
                )
            }

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
    }

    private var tripCountdownSection: some View {
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
    }

    private var systemTestsSection: some View {
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
    }

    @ViewBuilder
    private var accountSupportSection: some View {
        let headerView = SectionHeader(title: "Account & Support", theme: theme)

        Section(header: headerView) {
            NavigationLink(destination: AchievementsView()
                            .environmentObject(authViewModel)
                            .environmentObject(manager)) {
                Label("Achievements", systemImage: "rosette")
            }
        }
        .listRowBackground(theme.cardBackground)

        Section {
            Button("Help & Support") {
                showingSupport = true
            }
        }
        .listRowBackground(theme.cardBackground)
    }

    private var dangerZoneSection: some View {
        let headerText = Text("Danger Zone")
            .foregroundColor(theme.mickeyRed)
            .font(.headline)

        return Section(header: headerText) {
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
