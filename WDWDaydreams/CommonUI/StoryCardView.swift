// CommonUI/Views/StoryCardView.swift
import SwiftUI

/// A reusable card view for displaying Disney daydream stories
struct StoryCardView: View {
    let story: DaydreamStory
    var showFavoriteLabel: Bool = true
    var previewMode: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date and author header
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(DisneyColors.magicBlue)
                Text("\(story.dateAssigned, style: .date)")
                    .font(.caption)
                    .foregroundColor(DisneyColors.magicBlue)
                
                Spacer()
                
                Image(systemName: "person.fill")
                    .foregroundColor(DisneyColors.fantasyPurple)
                Text("\(story.assignedAuthor.displayName)'s Turn")
                    .font(.caption)
                    .foregroundColor(DisneyColors.fantasyPurple)
            }
            .padding(.bottom, 4)

            // Prompt with themed styling
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(DisneyColors.mainStreetGold)
                
                Text("Prompt: \(story.promptText)")
                    .font(.footnote)
                    .italic()
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }

            // Story text with themed styling
            if story.isWritten {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .background(DisneyColors.mainStreetGold.opacity(0.5))
                        .padding(.vertical, 4)
                    
                    Text(story.storyText!)
                        .font(.body)
                        .lineLimit(previewMode ? 3 : nil)
                        .foregroundColor(.primary)
                }
            } else {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(.gray)
                    
                    Text("(Story not written yet)")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
            }
            
            // Favorite indicator if applicable
            if story.isFavorite && showFavoriteLabel {
                HStack {
                    Spacer()
                    Image(systemName: "heart.fill")
                        .foregroundColor(DisneyColors.mickeyRed)
                    if previewMode {
                        Text("Favorite")
                            .font(.caption)
                            .foregroundColor(DisneyColors.mickeyRed)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(DisneyColors.backgroundCream)
        .cornerRadius(10)
    }
}

// CommonUI/Views/CategoryBadgeView.swift
import SwiftUI

/// A reusable badge view for displaying category items
struct CategoryBadgeView: View {
    let category: Category
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: CategoryHelper.icon(for: category))
                .foregroundColor(CategoryHelper.color(for: category))
                .frame(width: 30)
            
            Text("\(category.promptPrefix):")
                .fontWeight(.medium)
                .foregroundColor(CategoryHelper.color(for: category))
            
            Text(value)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(CategoryHelper.color(for: category).opacity(0.1))
        .cornerRadius(8)
    }
}

// CommonUI/Views/DisneyPromptView.swift
import SwiftUI

/// A view for displaying the current day's prompt
struct DisneyPromptView: View {
    let prompt: DaydreamStory
    let isUsersTurn: Bool
    let onToggleFavorite: () -> Void
    let onSaveStory: (String) -> Void
    
    @State private var storyText: String = ""
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header section
            HStack {
                Text("Today's Disney Daydream")
                    .font(.system(.title2, design: .rounded))
                    .bold()
                    .foregroundColor(DisneyColors.magicBlue)
                
                Spacer()
                
                // Favorite button
                Button(action: onToggleFavorite) {
                    Image(systemName: prompt.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(prompt.isFavorite ? DisneyColors.mickeyRed : .gray)
                        .scaleEffect(prompt.isFavorite ? 1.1 : 1.0)
                        .animation(.spring(), value: prompt.isFavorite)
                }
            }
            
            Text("It's \(prompt.assignedAuthor.displayName)'s turn today!")
                .font(.subheadline)
                .foregroundColor(DisneyColors.fantasyPurple)
            
            // Prompt items
            ForEach(prompt.items.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { item in
                CategoryBadgeView(category: item.key, value: item.value)
            }
            
            Divider()
                .background(DisneyColors.mainStreetGold.opacity(0.5))
            
            // Story writing/viewing area
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Your Story")
                        .font(.headline)
                        .foregroundColor(DisneyColors.magicBlue)
                    
                    Spacer()
                    
                    // Only show Edit button if it's the user's turn and story is written
                    if prompt.isWritten && isUsersTurn {
                        Button(isEditing ? "Done" : "Edit") {
                            if isEditing {
                                // Save the story
                                onSaveStory(storyText)
                            } else {
                                // Load existing text for editing
                                storyText = prompt.storyText ?? ""
                            }
                            isEditing.toggle()
                        }
                        .foregroundColor(DisneyColors.magicBlue)
                    }
                }
                
                if prompt.isWritten && !isEditing {
                    Text(prompt.storyText ?? "")
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(8)
                } else if isUsersTurn {
                    // Only show text editor if it's the user's turn
                    TextEditor(text: $storyText)
                        .frame(minHeight: 200)
                        .padding(4)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DisneyColors.mainStreetGold.opacity(0.5), lineWidth: 1)
                        )
                    
                    if !isEditing {
                        Button("Save Story") {
                            onSaveStory(storyText)
                            isEditing = false
                        }
                        .buttonStyle(DisneyButtonStyle())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .disabled(storyText.isEmpty)
                    }
                } else if !prompt.isWritten {
                    // Show a message when it's not the user's turn and no story yet
                    Text("Waiting for \(prompt.assignedAuthor.displayName) to write their story...")
                        .italic()
                        .foregroundColor(.gray)
                        .padding()
                }
            }
        }
        .padding()
        .background(DisneyColors.backgroundCream)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DisneyColors.mainStreetGold.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
        .onAppear {
            // Initialize the text editor with existing story if available
            if prompt.isWritten {
                storyText = prompt.storyText ?? ""
            }
        }
    }
}

// CommonUI/Helpers/CategoryHelper.swift
import SwiftUI

/// Helper class for category-related functionality
enum CategoryHelper {
    static func icon(for category: Category) -> String {
        switch category {
        case .hotel: return "bed.double.fill"
        case .park: return "map.fill"
        case .ride: return "tram.fill"
        case .food: return "fork.knife"
        case .beverage: return "cup.and.saucer.fill"
        case .souvenir: return "bag.fill"
        case .character: return "person.fill"
        case .event: return "calendar.badge.clock"
        }
    }
    
    static func color(for category: Category) -> Color {
        switch category {
        case .hotel: return DisneyColors.castlePink
        case .park: return DisneyColors.magicBlue
        case .ride: return DisneyColors.mickeyRed
        case .food: return DisneyColors.adventureGreen
        case .beverage: return DisneyColors.adventureGreen
        case .souvenir: return DisneyColors.mainStreetGold
        case .character: return DisneyColors.fantasyPurple
        case .event: return DisneyColors.tomorrowlandSilver
        }
    }
}
