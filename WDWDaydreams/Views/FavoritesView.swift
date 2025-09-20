// Views/FavoritesView.swift
import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var manager: ScenarioManager

    var body: some View {
        List {
            if manager.favorites.isEmpty {
                EmptyFavoritesView()
            } else {
                ForEach(manager.favorites) { story in
                    StoryCardView(story: story, showFavoriteLabel: true, previewMode: true)
                }
                .onDelete { offsets in
                    manager.removeFavorite(at: offsets)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .background(DisneyColors.backgroundCream)
        .scrollContentBackground(.hidden)
        .navigationTitle("Favorite Daydreams")
        .toolbar {
             // EditButton works with onDelete
            if !manager.favorites.isEmpty {
                 EditButton()
                    .foregroundColor(DisneyColors.magicBlue)
            }
        }
    }
}

private struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 40))
                .foregroundColor(DisneyColors.magicBlue)

            Text("No favorites yet")
                .font(.headline)
                .foregroundColor(DisneyColors.magicBlue)

            Text("Tap the heart on a daydream to save it here for easy access later.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(DisneyColors.magicBlue.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}
