// Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var manager: ScenarioManager
    @State private var isRefreshing = false

    var body: some View {
        List {
            if manager.storyHistory.isEmpty {
                HistoryEmptyStateView()
            } else {
                ForEach(manager.storyHistory) { story in
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
                    refreshHistory()
                }) {
                    Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .foregroundColor(DisneyColors.magicBlue)
                        .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                        .animation(isRefreshing ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear All") {
                    // Add confirmation alert here for safety
                    manager.clearHistory()
                }
                .foregroundColor(DisneyColors.mickeyRed)
            }
        }
        .onAppear {
            // Refresh the history when the view appears
            refreshHistory()
        }
    }

    private func refreshHistory() {
        isRefreshing = true
        manager.fetchStoryHistory()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isRefreshing = false
        }
    }
}

private struct HistoryEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(DisneyColors.magicBlue)

            Text("Your history is clear")
                .font(.headline)
                .foregroundColor(DisneyColors.magicBlue)

            Text("Come back after generating a few daydreams to revisit them here.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(DisneyColors.magicBlue.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}
