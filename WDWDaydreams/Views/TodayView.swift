// Views/TodayView.swift
import SwiftUI
import FirebaseAuth

struct TodayView: View {
    @EnvironmentObject var manager: ScenarioManager
    // Change to @ObservedObject
    @ObservedObject private var viewModel: TodayViewModel
    
    init() {
        // Create the initial view model with a placeholder manager
        // We'll update it in onAppear
        self._viewModel = ObservedObject(wrappedValue: TodayViewModel(manager: ScenarioManager()))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
                    Text("No prompt available. Try refreshing.")
                        .padding()
                        .foregroundColor(DisneyColors.mickeyRed)
                }
                
                // Only show the Generate New Prompt button if it's the user's turn
                if viewModel.isCurrentUsersTurn {
                    Button("Generate New Prompt") {
                        viewModel.generateNewPrompt()
                    }
                    .buttonStyle(DisneyButtonStyle())
                    .padding()
                }
            }
        }
        .onAppear {
            // Create a new viewModel with the real manager from environment
            viewModel = TodayViewModel(manager: manager)
            
            // Refresh the history data
            manager.fetchStoryHistory()
        }
    }
}
