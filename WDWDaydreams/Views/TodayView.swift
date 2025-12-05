// Views/TodayView.swift
import SwiftUI
import FirebaseAuth

struct TodayView: View {
    @EnvironmentObject var manager: ScenarioManager
    @Environment(\.theme) var theme: Theme

    @State private var storyText: String = ""
    @State private var isEditing: Bool = false
    @State private var showPartnershipPicker = false
    @State private var errorMessage: String?

    // Computed properties to replace ViewModel
    private var currentPrompt: DaydreamStory? {
        manager.currentStoryPrompt
    }

    private var isCurrentUsersTurn: Bool {
        manager.isCurrentUsersTurn()
    }

    private var hasMultiplePartnerships: Bool {
        manager.userPartnerships.count > 1
    }

    private var currentPartnerName: String? {
        guard let partnership = manager.selectedPartnership,
              let currentUserId = Auth.auth().currentUser?.uid,
              let partnerId = partnership.getPartnerId(for: currentUserId),
              let profile = manager.partnerProfiles[partnerId] else {
            return nil
        }
        return profile.displayName
    }
    
    private var showTripCountdown: Bool {
        guard let tripDate = manager.tripDate else { return false }
        let days = daysUntilTrip
        return tripDate > Date() && days >= 0
    }
    
    private var daysUntilTrip: Int {
        guard let tripDate = manager.tripDate else { return 0 }
        return Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: tripDate)).day ?? 0
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Partnership selector (if multiple partnerships)
                    if hasMultiplePartnerships {
                        PartnershipSelectorView(
                            currentPartnerName: currentPartnerName ?? "Select Partner",
                            onTap: { showPartnershipPicker = true },
                            theme: theme
                        )
                    } else if manager.userPartnerships.isEmpty {
                        NoPartnershipsView(theme: theme)
                    }

                    // Stats dashboard (quick glance)
                    if !manager.userPartnerships.isEmpty {
                        HStack(spacing: 12) {
                            StatCard(icon: "pencil.circle.fill", value: "\(manager.totalStoriesCount)", label: "Stories", color: theme.magicBlue)
                            StatCard(icon: "flame.fill", value: "\(manager.currentStreak)", label: "Streak", color: .orange)
                            StatCard(icon: "star.fill", value: manager.favoriteCategory.capitalized, label: "Top", color: theme.mainStreetGold)
                        }
                        .padding(.horizontal)
                    }

                    // Error message
                    if let error = errorMessage {
                        ErrorBannerView(message: error, theme: theme)
                            .onTapGesture {
                                errorMessage = nil
                            }
                    }

                    // Loading state
                    if manager.isLoading {
                        LoadingPromptView(theme: theme)
                    }

                    // Trip countdown if available
                    if showTripCountdown {
                        TripCountdownView(days: daysUntilTrip, theme: theme)
                    }

                    // Today's prompt
                    if let prompt = currentPrompt, !manager.isLoading {
                    DisneyPromptView(
                        prompt: prompt,
                        isUsersTurn: isCurrentUsersTurn,
                        onToggleFavorite: {
                            manager.toggleFavorite()
                        },
                        onSaveStory: { text in
                            saveStory(text: text)
                        }
                    )
                } else if !manager.userPartnerships.isEmpty && !manager.isLoading {
                    // No prompt available - show generation option
                    VStack(spacing: 20) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 50))
                            .foregroundColor(theme.mainStreetGold)

                        Text("No prompt available for today")
                            .font(.headline)
                            .foregroundColor(theme.mickeyRed)

                        if let partnerName = currentPartnerName {
                            Text("Create a magical story with \(partnerName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Button("Generate Today's Prompt") {
                            print("🎯 User tapped Generate Prompt")
                            Task {
                                await generatePrompt()
                            }
                        }
                        .buttonStyle(DisneyButtonStyle(color: theme.magicBlue))
                        .padding(.top)
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal)
                }
                
                    // Show the Generate New Prompt button if it's the user's turn and there's already a prompt
                    if currentPrompt != nil && isCurrentUsersTurn && !manager.isLoading {
                        Button("Generate New Prompt") {
                            print("🎯 User tapped Generate New Prompt")
                            Task {
                                await generatePrompt()
                            }
                        }
                        .buttonStyle(DisneyButtonStyle(color: theme.magicBlue))
                        .padding(.horizontal)
                    }
                }
            }
            .refreshable {
                // Pull to refresh functionality with haptic feedback
                HapticManager.instance.impact(style: .light)
                print("🔄 User pulled to refresh")
                Task {
                    await manager.generateOrUpdateDailyPrompt()
                }
            }
        }
        .sheet(isPresented: $showPartnershipPicker) {
            PartnershipPickerSheet(manager: manager)
        }
        .onAppear {
            print("📱 TodayView appeared")

            // Initialize text with existing story if available
            if let prompt = currentPrompt, prompt.isWritten {
                storyText = prompt.storyText ?? ""
            }

            // Try to generate today's prompt if none exists
            if manager.currentStoryPrompt == nil && !manager.userPartnerships.isEmpty {
                print("🔍 No current prompt, trying to generate...")
                Task {
                    await manager.generateOrUpdateDailyPrompt()
                }
            }
        }
        .onChange(of: currentPrompt?.storyText) { _, newValue in
            // Update local text when story changes
            if let newText = newValue, !isEditing {
                storyText = newText
            }
        }
    }
    
    // Local functions to replace ViewModel methods
    private func saveStory(text: String) {
        guard let prompt = currentPrompt else {
            errorMessage = "Unable to save story. Please try again."
            return
        }
        storyText = text
        manager.saveStoryText(text, for: prompt.id)
        isEditing = false
    }

    private func generatePrompt() async {
        errorMessage = nil
        await manager.next()
    }
}

// MARK: - Small UI Components

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Supporting Views

struct PartnershipSelectorView: View {
    let currentPartnerName: String
    let onTap: () -> Void
    let theme: Theme

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(theme.magicBlue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Story Partner")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currentPartnerName)
                        .font(.headline)
                        .foregroundColor(theme.magicBlue)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundColor(theme.magicBlue)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal)
    }
}

struct NoPartnershipsView: View {
    let theme: Theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Story Pals Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.magicBlue)

            Text("Visit the Pals tab to invite friends or accept an invitation to start sharing Disney Daydreams!")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

struct LoadingPromptView: View {
    let theme: Theme

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(theme.magicBlue)

            Text("Creating magical prompt...")
                .font(.headline)
                .foregroundColor(theme.magicBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct ErrorBannerView: View {
    let message: String
    let theme: Theme

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.mickeyRed)

            Text(message)
                .font(.subheadline)
                .foregroundColor(theme.mickeyRed)

            Spacer()

            Image(systemName: "xmark.circle.fill")
                .foregroundColor(theme.mickeyRed.opacity(0.6))
        }
        .padding()
        .background(theme.mickeyRed.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct PartnershipPickerSheet: View {
    @ObservedObject var manager: ScenarioManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme: Theme

    var body: some View {
        NavigationView {
            List {
                ForEach(manager.userPartnerships) { partnership in
                    Button(action: {
                        Task {
                            await manager.selectPartnership(partnership)
                            HapticManager.instance.impact(style: .light)
                            dismiss()
                        }
                    }) {
                        HStack {
                            if let currentUserId = Auth.auth().currentUser?.uid,
                               let partnerId = partnership.getPartnerId(for: currentUserId),
                               let profile = manager.partnerProfiles[partnerId] {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(theme.magicBlue)

                                VStack(alignment: .leading) {
                                    Text(profile.displayName)
                                        .font(.headline)

                                    if let tripDate = partnership.sharedTripDate {
                                        Text("Trip: \(tripDate, style: .date)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            if partnership.id == manager.selectedPartnership?.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(theme.mainStreetGold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Story Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Updated TripCountdownView to use theme
struct TripCountdownView: View {
    let days: Int
    let theme: Theme
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(theme.mickeyRed)
                
                Text("Trip Countdown")
                    .font(.headline)
                    .foregroundColor(theme.mickeyRed)
                
                Spacer()
            }
            
            HStack {
                Text("\(days)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(theme.magicBlue)
                
                VStack(alignment: .leading) {
                    Text(days == 1 ? "day" : "days")
                        .font(.headline)
                        .foregroundColor(theme.magicBlue)
                    Text("until Disney!")
                        .font(.subheadline)
                        .foregroundColor(theme.magicBlue.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundColor(theme.mainStreetGold)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(theme.backgroundCream)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(theme.mainStreetGold.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
