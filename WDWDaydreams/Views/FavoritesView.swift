// Views/FavoritesView.swift
import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var manager: ScenarioManager
    // Change to @ObservedObject
    @ObservedObject private var viewModel: FavoritesViewModel
    
    init() {
        // Create the initial view model with a placeholder manager
        self._viewModel = ObservedObject(wrappedValue: FavoritesViewModel(manager: ScenarioManager()))
    }

    var body: some View {
        List {
            if viewModel.isEmpty {
                EmptyFavoritesView()
            } else {
                // Iterate over the DaydreamStory objects in favorites
                ForEach(viewModel.favorites) { story in
                    StoryCardView(story: story, showFavoriteLabel: true, previewMode: true)
                }
                // Use the manager's removeFavorite function
                .onDelete { offsets in
                    viewModel.removeFavorite(at: offsets)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .background(DisneyColors.backgroundCream)
        .scrollContentBackground(.hidden)
        .navigationTitle("Favorite Daydreams")
        .toolbar {
             // EditButton works with onDelete
            if !viewModel.isEmpty {
                 EditButton()
                    .foregroundColor(DisneyColors.magicBlue)
            }
        }
        .onAppear {
            // Create a new viewModel with the real manager from environment
            viewModel = FavoritesViewModel(manager: manager)
        }
    }
}
