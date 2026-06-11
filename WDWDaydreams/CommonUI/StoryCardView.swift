// CommonUI/Views/StoryCardView.swift
import SwiftUI
import UIKit

/// A typographic row for displaying Disney daydream stories.
/// Hierarchy is established by type scale and alignment — no containers.
struct StoryCardView: View {
    let story: DaydreamStory
    var showFavoriteLabel: Bool = true
    var previewMode: Bool = false
    @Environment(\.theme) var theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            // Metadata line: date · author, favorite marker trailing
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xxs) {
                Text(story.dateAssigned.formatted(date: .abbreviated, time: .omitted).uppercased())
                    .font(DesignSystem.Typography.meta)
                    .tracking(0.8)
                    .foregroundColor(theme.secondaryText)

                Text("·")
                    .font(DesignSystem.Typography.meta)
                    .foregroundColor(theme.tertiaryText)

                Text("\(story.assignedAuthor.displayName)'s turn".uppercased())
                    .font(DesignSystem.Typography.meta)
                    .tracking(0.8)
                    .foregroundColor(theme.accentPurple)

                Spacer()

                if story.isFavorite && showFavoriteLabel {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(theme.accentRed)
                        .accessibilityLabel("Favorite")
                }
            }

            // Prompt — italic, secondary
            Text(story.promptText)
                .font(DesignSystem.Typography.prompt)
                .foregroundColor(theme.secondaryText)
                .lineLimit(previewMode ? 2 : nil)

            // Story text
            if story.isWritten {
                Text(story.storyText!)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(theme.primaryText)
                    .lineSpacing(2)
                    .lineLimit(previewMode ? 3 : nil)
                    .padding(.top, 2)
            } else {
                Text("Not written yet")
                    .font(DesignSystem.Typography.subtext)
                    .italic()
                    .foregroundColor(theme.tertiaryText)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// CommonUI/Views/CategoryBadgeView.swift
import SwiftUI

/// An aligned label/value row for a prompt category. The fixed label column
/// keeps values on a shared left edge across consecutive rows.
struct CategoryBadgeView: View {
    let category: Category
    let value: String
    @Environment(\.theme) var theme: Theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
            Text(category.promptPrefix.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(0.8)
                .foregroundColor(CategoryHelper.color(for: category))
                .frame(width: DesignSystem.Spacing.labelColumn, alignment: .leading)

            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

// CommonUI/Views/ParkPromptView.swift
import SwiftUI

/// The day's prompt and story composer. Sections are separated by hairline
/// rules and typographic section labels rather than nested cards.
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
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            header

            // Prompt items, aligned on a shared label column
            VStack(alignment: .leading, spacing: 0) {
                ForEach(prompt.items.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { item in
                    CategoryBadgeView(category: item.key, value: item.value)
                }
            }

            Hairline()

            storySection
        }
        .padding(.horizontal, DesignSystem.Spacing.pageMargin)
        .onAppear {
            if prompt.isWritten {
                storyText = prompt.storyText ?? ""
            }
        }
        .onChange(of: storyText) {
            // Track dirty state so tab navigation can warn before discarding
            let saved = prompt.storyText ?? ""
            EditorStateManager.shared.hasUnsavedStoryChanges =
                isComposing && !storyText.isEmpty && storyText != saved
        }
        .alert("Submit Your Story?", isPresented: $showingSubmitConfirmation) {
            Button("Send to \(partnerName)", role: .destructive) {
                HapticManager.instance.success()
                EditorStateManager.shared.hasUnsavedStoryChanges = false
                onSaveStory(pendingStoryText)
                if isEditing {
                    isEditing = false
                }
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Ready to share your magical story with \(partnerName)? Once submitted, your story will be locked and sent to your pal!")
        }
    }

    /// Whether the user is actively able to type (first draft or edit mode)
    private var isComposing: Bool {
        isUsersTurn && (!prompt.isWritten || isEditing)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's Daydream")
                    .font(DesignSystem.Typography.pageTitle)
                    .foregroundColor(theme.primaryText)

                Spacer()

                HStack(spacing: DesignSystem.Spacing.md) {
                    Button(action: {
                        HapticManager.instance.impact(style: .medium)
                        onToggleFavorite()
                    }) {
                        Image(systemName: prompt.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(prompt.isFavorite ? theme.accentRed : theme.secondaryText)
                            .scaleEffect(prompt.isFavorite ? 1.1 : 1.0)
                            .animation(DesignSystem.Animation.spring, value: prompt.isFavorite)
                    }
                    .accessibilityLabel(prompt.isFavorite ? "Remove favorite" : "Add favorite")

                    Button(action: { presentShare() }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(theme.primaryBlue)
                    }
                    .accessibilityLabel("Share")
                }
                .font(.body)
            }

            Text(isUsersTurn ? "Your turn today" : "\(prompt.assignedAuthor.displayName)'s turn today")
                .font(DesignSystem.Typography.subtext)
                .foregroundColor(theme.accentPurple)
        }
    }

    // MARK: - Story Section

    @ViewBuilder
    private var storySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(isUsersTurn ? "Your Story" : "\(prompt.assignedAuthor.displayName)'s Story")

                Spacer()

                if prompt.isWritten && isUsersTurn {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            pendingStoryText = storyText
                            showingSubmitConfirmation = true
                        } else {
                            storyText = prompt.storyText ?? ""
                            isEditing = true
                            editorFocused = true
                        }
                    }
                    .buttonStyle(InlineActionButtonStyle(color: theme.primaryBlue))
                }
            }

            if prompt.isWritten && !isEditing {
                Text(prompt.storyText ?? "")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(theme.primaryText)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            } else if isUsersTurn {
                TextEditor(text: $storyText)
                    .focused($editorFocused)
                    .font(DesignSystem.Typography.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .overlay(alignment: .topLeading) {
                        if storyText.isEmpty {
                            Text("Start your story…")
                                .font(DesignSystem.Typography.body)
                                .italic()
                                .foregroundColor(theme.tertiaryText)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }

                Hairline()

                if !isEditing {
                    HStack {
                        Text("\(storyText.count) characters")
                            .font(DesignSystem.Typography.meta)
                            .foregroundColor(theme.tertiaryText)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(DesignSystem.Animation.quick, value: storyText.count)

                        Spacer()

                        Button("Save Story") {
                            HapticManager.instance.impact(style: .medium)
                            pendingStoryText = storyText
                            showingSubmitConfirmation = true
                        }
                        .buttonStyle(InlineActionButtonStyle(color: theme.primaryBlue))
                        .disabled(storyText.isEmpty)
                        .opacity(storyText.isEmpty ? 0.4 : 1)
                    }
                }
            } else if !prompt.isWritten {
                Text("Waiting for \(prompt.assignedAuthor.displayName) to write their story…")
                    .font(DesignSystem.Typography.subtext)
                    .italic()
                    .foregroundColor(theme.tertiaryText)
            }
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
