// Views/TodayView.swift
import SwiftUI
import FirebaseAuth

struct TodayView: View {
    @EnvironmentObject var manager: ScenarioManager
    @State private var viewModel: TodayViewModel?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let viewModel = viewModel {
                    // Trip countdown if available
                    if viewModel.showTripCountdown {
                        TripCountdownView(days: viewModel.daysUntilTrip)
                    }
                    
                    // Today's prompt
                    if let prompt = viewModel.currentPrompt {
                        DisneyPromptView(
                            prompt: prompt,
                            isUsersTurn: viewModel.isCurrentUsersTurn,
                            onToggleFavorite: {
                                viewModel.toggleFavorite()
                            },
                            onSaveStory: { text in
                                viewModel.storyText = text
                                viewModel.saveStory()
                            }
                        )
                    } else {
                        // No prompt available - show generation option
                        VStack(spacing: 20) {
                            Text("No prompt available for today")
                                .font(.headline)
                                .foregroundColor(DisneyColors.mickeyRed)
                                .padding()
                            
                            Button("Generate Today's Prompt") {
                                print("軸 User tapped Generate Prompt")
                                viewModel.generateNewPrompt()
                            }
                            .buttonStyle(DisneyButtonStyle())
                            .padding()
                        }
                        .padding()
                        .background(DisneyColors.backgroundCream)
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(DisneyColors.mainStreetGold.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                    
                    // Show the Generate New Prompt button if it's the user's turn and there's already a prompt
                    if viewModel.currentPrompt != nil && viewModel.isCurrentUsersTurn {
                        Button("Generate New Prompt") {
                            print("軸 User tapped Generate New Prompt")
                            viewModel.generateNewPrompt()
                        }
                        .buttonStyle(DisneyButtonStyle())
                        .padding()
                    }
                } else {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle(tint: DisneyColors.magicBlue))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            print("導 TodayView appeared")
            // Create a new viewModel with the real manager from environment
            self.viewModel = TodayViewModel(manager: manager)
            
            // --- FIX: REMOVED OLD FETCH CALL ---
            // The listener in ScenarioManager now handles this automatically.
            
            // Try to generate today's prompt if none exists
            if manager.currentStoryPrompt == nil {
                print("売 No current prompt, trying to generate...")
                manager.generateOrUpdateDailyPrompt()
            }
        }
        .refreshable {
            // Pull to refresh functionality
            print("売 User pulled to refresh")
            manager.generateOrUpdateDailyPrompt()
            // --- FIX: REMOVED OLD FETCH CALL ---
            // The listener in ScenarioManager now handles this automatically.
        }
    }
}

// Create the TripCountdownView that was missing
struct TripCountdownView: View {
    let days: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(DisneyColors.mickeyRed)
                
                Text("Trip Countdown")
                    .font(.headline)
                    .foregroundColor(DisneyColors.mickeyRed)
                
                Spacer()
            }
            
            HStack {
                Text("\(days)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(DisneyColors.magicBlue)
                
                VStack(alignment: .leading) {
                    Text(days == 1 ? "day" : "days")
                        .font(.headline)
                        .foregroundColor(DisneyColors.magicBlue)
                    Text("until Disney!")
                        .font(.subheadline)
                        .foregroundColor(DisneyColors.magicBlue.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundColor(DisneyColors.mainStreetGold)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(DisneyColors.backgroundCream)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(DisneyColors.mainStreetGold.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
