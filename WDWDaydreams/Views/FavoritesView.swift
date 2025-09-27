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
                        .transition(.opacity.combined(with: .scale))
                }
                .onDelete { offsets in
                    manager.removeFavorite(at: offsets)
                }
            }
        }
        .animation(.easeInOut, value: manager.favorites)
        .listStyle(InsetGroupedListStyle())
        .background(theme.backgroundCream)
        .scrollContentBackground(.hidden)
        .navigationTitle("Favorite Daydreams")
        .toolbar {
             // EditButton works with onDelete
            if !manager.favorites.isEmpty {
                 EditButton()
                    .foregroundColor(theme.magicBlue)
            }
        }
    }
}

private struct EmptyFavoritesView: View {
    let theme: Theme
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.magicBlue)

            Text("No favorites yet")
                .font(.headline)
                .foregroundColor(theme.magicBlue)

            Text("Tap the heart on a daydream to save it here for easy access later.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.magicBlue.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}
