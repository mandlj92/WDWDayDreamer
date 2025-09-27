// Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var manager: ScenarioManager
    @Environment(\.theme) var theme: Theme
    @State private var isRefreshing = false

    var body: some View {
        List {
            if manager.storyHistory.isEmpty {
                EmptyHistoryView(theme: theme)
            } else {
                ForEach(manager.storyHistory) { story in
                    StoryCardView(story: story, previewMode: true)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .background(theme.backgroundCream)
        .scrollContentBackground(.hidden)
        .navigationTitle("Daydream History")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    refreshHistory()
                }) {
                    Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .foregroundColor(theme.magicBlue)
                        .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                        .animation(isRefreshing ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear All") {
                    manager.clearHistory()
                }
                .foregroundColor(theme.mickeyRed)
            }
        }
        .onAppear {
            // Refresh UI feedback when view appears
            refreshHistory()
        }
    }

    private func refreshHistory() {
        isRefreshing = true
        // Real-time listeners in ScenarioManager handle data updates automatically
        // This is just UI feedback for the user
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isRefreshing = false
        }
    }
}

private struct EmptyHistoryView: View {
    let theme: Theme
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(theme.magicBlue)

            Text("Your history is clear")
                .font(.headline)
                .foregroundColor(theme.magicBlue)

            Text("Come back after generating a few daydreams to revisit them here.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.magicBlue.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}
