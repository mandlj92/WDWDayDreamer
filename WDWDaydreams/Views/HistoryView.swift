// Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var manager: ScenarioManager
    // Change to @ObservedObject
    @ObservedObject private var viewModel: HistoryViewModel
    
    init() {
        // Create the initial view model with a placeholder manager
        self._viewModel = ObservedObject(wrappedValue: HistoryViewModel(manager: ScenarioManager()))
    }
    
    var body: some View {
        List {
            if viewModel.isEmpty {
                EmptyHistoryView()
            } else {
                // Display history items
                ForEach(viewModel.storyHistory) { story in
                    StoryCardView(story: story, previewMode: true)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .background(DisneyColors.backgroundCream)
        .scrollContentBackground(.hidden)
        .navigationTitle("Daydream History")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    viewModel.refreshHistory()
                }) {
                    Image(systemName: viewModel.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .foregroundColor(DisneyColors.magicBlue)
                        .rotationEffect(viewModel.isRefreshing ? .degrees(360) : .degrees(0))
                        .animation(viewModel.isRefreshing ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: viewModel.isRefreshing)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear All") {
                    // Add confirmation alert here for safety
                    viewModel.clearHistory()
                }
                .foregroundColor(DisneyColors.mickeyRed)
            }
        }
        .onAppear {
            // Create a new viewModel with the real manager from environment
            viewModel = HistoryViewModel(manager: manager)
            
            // Refresh the history when the view appears
            viewModel.refreshHistory()
        }
    }
}
