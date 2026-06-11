// Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var manager: ScenarioManager
    @Environment(\.theme) var theme: Theme
    @State private var isRefreshing = false
    @State private var showingClearConfirmation = false

    var body: some View {
        List {
            if manager.storyHistory.isEmpty {
                EmptyHistoryView(theme: theme)
            } else {
                ForEach(manager.storyHistory) { story in
                    StoryCardView(story: story, previewMode: true)
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(theme.hairline)
                        .listRowInsets(EdgeInsets(
                            top: DesignSystem.Spacing.xxs,
                            leading: DesignSystem.Spacing.pageMargin,
                            bottom: DesignSystem.Spacing.xxs,
                            trailing: DesignSystem.Spacing.pageMargin
                        ))
                }
            }
        }
        .listStyle(.plain)
        .background(theme.backgroundCream)
        .scrollContentBackground(.hidden)
        .navigationTitle("Daydream History")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    refreshHistory()
                }) {
                    Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .foregroundColor(theme.primaryBlue)
                        .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                        .animation(isRefreshing ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .accessibilityLabel("Refresh history")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if !manager.storyHistory.isEmpty {
                    Button("Clear All") {
                        showingClearConfirmation = true
                    }
                    .foregroundColor(theme.accentRed)
                }
            }
        }
        .confirmationDialog(
            "Clear all story history?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                HapticManager.instance.notification(type: .warning)
                manager.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Your history is clear")
                .font(DesignSystem.Typography.sectionTitle)
                .foregroundColor(theme.primaryText)

            Text("Come back after generating a few daydreams to revisit them here.")
                .font(DesignSystem.Typography.subtext)
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSystem.Spacing.xl)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
