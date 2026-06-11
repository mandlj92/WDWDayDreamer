import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var feedbackCenter: UIFeedbackCenter
    @Environment(\.theme) var theme: Theme
    @State private var preferences: UserPreferences = UserPreferences()
    @State private var isRequestingNotifications = false
    @State private var isSaving = false
    @State private var showWelcomeTour = true

    var body: some View {
        ZStack {
            NavigationView {
                Form {
                    Section(header: SectionHeader(title: "Stay in the Loop", theme: theme)) {
                        Toggle("Story reminders", isOn: binding(for: \.notifications.storyReminders))
                        Toggle("Connection requests", isOn: binding(for: \.notifications.connectionRequests))
                        Toggle("New story alerts", isOn: binding(for: \.notifications.newStoryNotifications))
                        Toggle("Weekly digest", isOn: binding(for: \.notifications.weeklyDigest))
                        Button(action: requestNotifications) {
                            HStack {
                                if isRequestingNotifications { ProgressView().scaleEffect(0.8) }
                                Text("Allow Notifications")
                            }
                        }
                        .foregroundColor(theme.primaryBlue)
                    }
                    .listRowBackground(theme.cardBackground)

                    Section(header: SectionHeader(title: "Privacy", theme: theme)) {
                        Picker("Profile visibility", selection: binding(for: \.privacy.profileVisibility)) {
                            ForEach(ProfileVisibility.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        Toggle("Allow story sharing", isOn: binding(for: \.privacy.allowStorySharing))
                        Toggle("Allow discovery", isOn: binding(for: \.privacy.allowConnectionDiscovery))
                    }
                    .listRowBackground(theme.cardBackground)

                    Section(header: SectionHeader(title: "Prompt Categories", theme: theme)) {
                        ForEach(Category.allCases) { category in
                            Toggle(category.rawValue.capitalized, isOn: Binding(
                                get: { preferences.storyCategories.contains(category.rawValue) },
                                set: { newValue in
                                    if newValue {
                                        if !preferences.storyCategories.contains(category.rawValue) {
                                            preferences.storyCategories.append(category.rawValue)
                                        }
                                    } else {
                                        preferences.storyCategories.removeAll { $0 == category.rawValue }
                                    }
                                }
                            ))
                        }
                    }
                    .listRowBackground(theme.cardBackground)

                    Section(header: SectionHeader(title: "Trip Planning", theme: theme)) {
                        DatePicker("Next visit", selection: Binding(
                            get: { preferences.tripDate ?? Date() },
                            set: { preferences.tripDate = $0 }
                        ), displayedComponents: .date)
                    }
                    .listRowBackground(theme.cardBackground)

                    Section(header: SectionHeader(title: "Ready to Begin", theme: theme)) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("You're all set!")
                                .font(DesignSystem.Typography.sectionTitle)
                                .foregroundColor(theme.primaryText)

                            Text("Next step: invite a Story Pal to start creating magical theme park stories together.")
                                .font(DesignSystem.Typography.subtext)
                                .foregroundColor(theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            Button(action: savePreferences) {
                                HStack {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    }
                                    Text(isSaving ? "Saving…" : "Complete Setup")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(ParkButtonStyle(color: theme.primaryBlue))
                            .disabled(isSaving)
                            .padding(.top, DesignSystem.Spacing.xs)
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .listRowBackground(theme.backgroundCream)
                    }
                }
                .navigationTitle("Set Up Your Profile")
                .navigationBarTitleDisplayMode(.inline)
                .scrollContentBackground(.hidden)
                .background(theme.backgroundCream.edgesIgnoringSafeArea(.all))
            }

            if showWelcomeTour {
                WelcomeTourView(showTour: $showWelcomeTour)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            if let profile = authViewModel.userProfile {
                preferences = profile.preferences
            }
        }
    }

    private func binding<Value>(for keyPath: WritableKeyPath<UserPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { preferences[keyPath: keyPath] },
            set: { preferences[keyPath: keyPath] = $0 }
        )
    }

    private func requestNotifications() {
        isRequestingNotifications = true
        NotificationManager.shared.requestPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isRequestingNotifications = false
            feedbackCenter.present(message: "Notification request sent", style: .info)
        }
    }

    private func savePreferences() {
        isSaving = true
        Task {
            if authViewModel.currentUser != nil {
                let categories = preferences.storyCategories.compactMap { Category(rawValue: $0) }
                FirebaseDataService.shared.saveUserSettings(enabledCategories: categories, tripDate: preferences.tripDate) { success in
                    DispatchQueue.main.async {
                        if success {
                            authViewModel.requiresOnboarding = false
                            feedbackCenter.present(message: "Preferences saved", style: .success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("ShowFirstPartnershipGuide"),
                                    object: nil
                                )
                            }
                        } else {
                            feedbackCenter.present(message: "Error saving preferences", style: .error)
                        }
                        isSaving = false
                    }
                }
            } else {
                feedbackCenter.present(message: "Not signed in", style: .error)
                isSaving = false
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthViewModel())
        .environmentObject(ThemeManager())
        .environmentObject(UIFeedbackCenter.shared)
}
