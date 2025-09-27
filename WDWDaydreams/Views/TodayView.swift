// Views/TodayView.swift
import SwiftUI
import FirebaseAuth

struct TodayView: View {
    @EnvironmentObject var manager: ScenarioManager
    @Environment(\.theme) var theme: Theme
    
    @State private var storyText: String = ""
    @State private var isEditing: Bool = false
    
    // Computed properties to replace ViewModel
    private var currentPrompt: DaydreamStory? {
        manager.currentStoryPrompt
    }
    
    private var isCurrentUsersTurn: Bool {
        manager.isCurrentUsersTurn()
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Trip countdown if available
                if showTripCountdown {
                    TripCountdownView(days: daysUntilTrip, theme: theme)
                }
                
                // Today's prompt
                if let prompt = currentPrompt {
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
                } else {
                    // No prompt available - show generation option
                    VStack(spacing: 20) {
                        Text("No prompt available for today")
                            .font(.headline)
                            .foregroundColor(theme.mickeyRed)
                            .padding()
                        
                        Button("Generate Today's Prompt") {
                            print("🎯 User tapped Generate Prompt")
                            manager.next()
                        }
                        .buttonStyle(DisneyButtonStyle(color: theme.magicBlue))
                        .padding()
                    }
                    .padding()
                    .background(theme.backgroundCream)
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(theme.mainStreetGold.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
                
                // Show the Generate New Prompt button if it's the user's turn and there's already a prompt
                if currentPrompt != nil && isCurrentUsersTurn {
                    Button("Generate New Prompt") {
                        print("🎯 User tapped Generate New Prompt")
                        manager.next()
                    }
                    .buttonStyle(DisneyButtonStyle(color: theme.magicBlue))
                    .padding()
                }
            }
        }
        .onAppear {
            print("📱 TodayView appeared")
            
            // Initialize text with existing story if available
            if let prompt = currentPrompt, prompt.isWritten {
                storyText = prompt.storyText ?? ""
            }
            
            // Try to generate today's prompt if none exists
            if manager.currentStoryPrompt == nil {
                print("🔍 No current prompt, trying to generate...")
                manager.generateOrUpdateDailyPrompt()
            }
        }
        .refreshable {
            // Pull to refresh functionality
            print("🔄 User pulled to refresh")
            manager.generateOrUpdateDailyPrompt()
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
        guard let prompt = currentPrompt else { return }
        storyText = text
        manager.saveStoryText(text, for: prompt.id)
        isEditing = false
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
