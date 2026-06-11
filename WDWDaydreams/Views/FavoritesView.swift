// Views/FavoritesView.swift
import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var manager: ScenarioManager
    @Environment(\.theme) var theme: Theme

    var body: some View {
        List {
            if manager.favorites.isEmpty {
                EmptyFavoritesView(theme: theme)
            } else {
                ForEach(manager.favorites) { story in
                    StoryCardView(story: story, showFavoriteLabel: true, previewMode: true)
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(theme.hairline)
                        .listRowInsets(EdgeInsets(
                            top: DesignSystem.Spacing.xxs,
                            leading: DesignSystem.Spacing.pageMargin,
                            bottom: DesignSystem.Spacing.xxs,
                            trailing: DesignSystem.Spacing.pageMargin
                        ))
                        .transition(.opacity)
                }
                .onDelete { offsets in
                    HapticManager.instance.impact(style: .medium)
                    manager.removeFavorite(at: offsets)
                }
            }
        }
        .animation(DesignSystem.Animation.standard, value: manager.favorites)
        .listStyle(.plain)
        .background(theme.backgroundCream)
        .scrollContentBackground(.hidden)
        .navigationTitle("Favorite Daydreams")
        .toolbar {
            // EditButton works with onDelete
            if !manager.favorites.isEmpty {
                EditButton()
                    .foregroundColor(theme.primaryBlue)
            }
        }
    }
}

private struct EmptyFavoritesView: View {
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("No favorites yet")
                .font(DesignSystem.Typography.sectionTitle)
                .foregroundColor(theme.primaryText)

            Text("Tap the heart on a daydream to save it here for easy access later.")
                .font(DesignSystem.Typography.subtext)
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSystem.Spacing.xl)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
