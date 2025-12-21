// CommonUI/Views/StoryCardView.swift
import SwiftUI
import UIKit

/// A reusable card view for displaying Disney daydream stories
struct StoryCardView: View {
    let story: DaydreamStory
    var showFavoriteLabel: Bool = true
    var previewMode: Bool = false
    @Environment(\.theme) var theme: Theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date and author header
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(theme.primaryBlue)
                Text("\(story.dateAssigned, style: .date)")
                    .font(.caption)
                    .foregroundColor(theme.primaryBlue)
                
                Spacer()
                
                Image(systemName: "person.fill")
                    .foregroundColor(theme.accentPurple)
                Text("\(story.assignedAuthor.displayName)'s Turn")
                    .font(.caption)
                    .foregroundColor(theme.accentPurple)
            }
            .padding(.bottom, 4)

            // Prompt with themed styling
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(theme.accentGold)
                
                Text("Prompt: \(story.promptText)")
                    .font(.footnote)
                    .italic()
                    .lineLimit(2)
                    .foregroundColor(theme.primaryText)
            }

            // Story text with themed styling
            if story.isWritten {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .background(theme.accentGold.opacity(0.5))
                        .padding(.vertical, 4)
                    
                    Text(story.storyText!)
                        .font(.body)
                        .lineLimit(previewMode ? 3 : nil)
                        .foregroundColor(theme.primaryText)
                }
            } else {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(theme.secondaryText)
                    
                    Text("(Story not written yet)")
                        .font(.body)
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.top, 4)
            }
            
            // Favorite indicator if applicable
            if story.isFavorite && showFavoriteLabel {
                HStack {
                    Spacer()
                    Image(systemName: "heart.fill")
                        .foregroundColor(theme.accentRed)
                    if previewMode {
                        Text("Favorite")
                            .font(.caption)
                            .foregroundColor(theme.accentRed)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(DesignSystem.Spacing.xs)
        .background(theme.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.small)
    }
}

// CommonUI/Views/CategoryBadgeView.swift
import SwiftUI

/// A reusable badge view for displaying category items
struct CategoryBadgeView: View {
    let category: Category
    let value: String
    @Environment(\.theme) var theme: Theme
    
    var body: some View {
        HStack {
            Image(systemName: CategoryHelper.icon(for: category))
                .foregroundColor(CategoryHelper.color(for: category))
                .frame(width: 30)
            
            Text("\(category.promptPrefix):")
                .fontWeight(.medium)
                .foregroundColor(CategoryHelper.color(for: category))
            
            Text(value)
                .foregroundColor(theme.primaryText)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(CategoryHelper.color(for: category).opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.small)
    }
}

// CommonUI/Views/ParkPromptView.swift
import SwiftUI

/// A view for displaying the current day's prompt
struct ParkPromptView: View {
    let prompt: DaydreamStory
    let isUsersTurn: Bool
    let partnerName: String
    let onToggleFavorite: () -> Void
    let onSaveStory: (String) -> Void
    @Environment(\.theme) var theme: Theme

    @State private var storyText: String = ""
    @State private var isEditing: Bool = false
    @State private var showingSubmitConfirmation = false
    @State private var pendingStoryText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header section
            HStack {
                Text("Today's Daydream")
                    .font(.system(.title2, design: .rounded))
                    .bold()
                    .foregroundColor(theme.primaryBlue)
                
                Spacer()
                
                // Favorite button
                HStack(spacing: 12) {
                    Button(action: {
                        HapticManager.instance.impact(style: .medium)
                        onToggleFavorite()
                    }) {
                        Image(systemName: prompt.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(prompt.isFavorite ? theme.accentRed : theme.secondaryText)
                            .scaleEffect(prompt.isFavorite ? 1.1 : 1.0)
                            .animation(.spring(), value: prompt.isFavorite)
                    }

                    // Share button
                    Button(action: { presentShare() }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(theme.primaryBlue)
                    }
                }
            }
            
            Text("It's \(prompt.assignedAuthor.displayName)'s turn today!")
                .font(.subheadline)
                .foregroundColor(theme.accentPurple)
            
            // Prompt items
            ForEach(prompt.items.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { item in
                CategoryBadgeView(category: item.key, value: item.value)
            }
            
            Divider()
                .background(theme.accentGold.opacity(0.5))
            
            // Story writing/viewing area
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Your Story")
                        .font(.headline)
                        .foregroundColor(theme.primaryBlue)
                    
                    Spacer()
                    
                    // Only show Edit button if it's the user's turn and story is written
                    if prompt.isWritten && isUsersTurn {
                        Button(isEditing ? "Done" : "Edit") {
                            if isEditing {
                                // Show confirmation before saving
                                pendingStoryText = storyText
                                showingSubmitConfirmation = true
                            } else {
                                // Load existing text for editing
                                storyText = prompt.storyText ?? ""
                            }
                            isEditing.toggle()
                        }
                        .foregroundColor(theme.primaryBlue)
                    }
                }
                
                if prompt.isWritten && !isEditing {
                    Text(prompt.storyText ?? "")
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(DesignSystem.CornerRadius.small)
                } else if isUsersTurn {
                    // Only show text editor if it's the user's turn
                    TextEditor(text: $storyText)
                        .frame(minHeight: 200)
                        .padding(4)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(DesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .stroke(theme.accentGold.opacity(0.5), lineWidth: 1)
                        )
                    
                    if !isEditing {
                        Button("Save Story") {
                            HapticManager.instance.impact(style: .medium)
                            pendingStoryText = storyText
                            showingSubmitConfirmation = true
                        }
                        .buttonStyle(ParkButtonStyle(color: theme.primaryBlue))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .disabled(storyText.isEmpty)
                    }
                } else if !prompt.isWritten {
                    // Show a message when it's not the user's turn and no story yet
                    Text("Waiting for \(prompt.assignedAuthor.displayName) to write their story...")
                        .italic()
                        .foregroundColor(theme.secondaryText)
                        .padding()
                }
            }
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(theme.accentGold.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
        .onAppear {
            // Initialize the text editor with existing story if available
            if prompt.isWritten {
                storyText = prompt.storyText ?? ""
            }
        }
        .alert("Submit Your Story?", isPresented: $showingSubmitConfirmation) {
            Button("Send to \(partnerName)", role: .destructive) {
                HapticManager.instance.success()
                onSaveStory(pendingStoryText)
                if isEditing {
                    isEditing = false
                }
            }
            Button("Keep Editing", role: .cancel) {
                // Just dismiss the alert
            }
        } message: {
            Text("Ready to share your magical story with \(partnerName)? Once submitted, your story will be locked and sent to your pal!")
        }
    }

    private func presentShare() {
        let textToShare = ShareService.shared.shareText(for: prompt.promptText, storyText: prompt.storyText)
        let activityVC = UIActivityViewController(activityItems: [textToShare], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            root.present(activityVC, animated: true, completion: nil)
        } else {
            print("⚠️ Could not find window to present share sheet")
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
        case .hotel: return ThemeColors.accentPink
        case .park: return ThemeColors.primaryBlue
        case .ride: return ThemeColors.accentRed
        case .food: return ThemeColors.accentGreen
        case .beverage: return ThemeColors.accentGreen
        case .souvenir: return ThemeColors.accentGold
        case .character: return ThemeColors.accentPurple
        case .event: return ThemeColors.accentSilver
        }
    }
}
