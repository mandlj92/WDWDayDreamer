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
            // Main Onboarding Form
            NavigationView {
                Form {
                Section(header: Text("Stay in the loop")) {
                    Toggle("Story reminders", isOn: binding(for: \.notifications.storyReminders))
                    Toggle("Connection requests", isOn: binding(for: \.notifications.connectionRequests))
                    Toggle("New story alerts", isOn: binding(for: \.notifications.newStoryNotifications))
                    Toggle("Weekly digest", isOn: binding(for: \.notifications.weeklyDigest))
                    Button(action: requestNotifications) {
                        HStack {
                            if isRequestingNotifications { ProgressView() }
                            Text("Allow Notifications")
                        }
                    }
                }

                Section(header: Text("Privacy")) {
                    Picker("Profile visibility", selection: binding(for: \.privacy.profileVisibility)) {
                        ForEach(ProfileVisibility.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    Toggle("Allow story sharing", isOn: binding(for: \.privacy.allowStorySharing))
                    Toggle("Allow discovery", isOn: binding(for: \.privacy.allowConnectionDiscovery))
                }

                Section(header: Text("Prompt categories")) {
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

                Section(header: Text("Trip planning")) {
                    DatePicker("Next visit", selection: Binding(
                        get: { preferences.tripDate ?? Date() },
                        set: { preferences.tripDate = $0 }
                    ), displayedComponents: .date)
                }

                Section(header: Text("Ready to begin?")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("You're all set!")
                            .font(.headline)
                            .foregroundColor(theme.magicBlue)

                        Text("Next step: Invite a Story Pal to start creating magical Disney stories together.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button(action: savePreferences) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(isSaving ? "Saving..." : "Complete Setup")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(theme.magicBlue)
                            .cornerRadius(12)
                        }
                        .disabled(isSaving)
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(theme.backgroundCream)
                }
            }
            .navigationTitle("Set Up Your Profile")
            .scrollContentBackground(.hidden)
            .background(theme.backgroundCream.edgesIgnoringSafeArea(.all))
            }

            // Welcome Tour Overlay
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
                // Map stored category strings to Category enum values
                let categories = preferences.storyCategories.compactMap { Category(rawValue: $0) }
                FirebaseDataService.shared.saveUserSettings(enabledCategories: categories, tripDate: preferences.tripDate) { success in
                    DispatchQueue.main.async {
                        if success {
                            authViewModel.requiresOnboarding = false
                            feedbackCenter.present(message: "Preferences saved", style: .success)
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
