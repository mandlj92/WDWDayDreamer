// CommonUI/SkeletonViews.swift
import SwiftUI

// MARK: - Shimmer Effect Modifier
/// Animated shimmer effect for skeleton loading states
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.theme) var theme: Theme

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        theme.primaryBlue.opacity(0.15),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = UIScreen.main.bounds.width * 2
                }
            }
    }
}

extension View {
    /// Applies a shimmer animation effect to the view
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Skeleton Story Card
/// Skeleton placeholder for DaydreamStory cards while loading
struct SkeletonStoryCard: View {
    @Environment(\.theme) var theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Header skeleton (date and author)
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.primaryBlue.opacity(0.15))
                    .frame(width: 100, height: 12)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.accentPurple.opacity(0.15))
                    .frame(width: 120, height: 12)
            }

            // Prompt skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.accentGold.opacity(0.15))
                .frame(height: 14)
                .frame(width: CGFloat.random(in: 200...280))

            // Story text skeleton (3 lines)
            VStack(spacing: DesignSystem.Spacing.xxs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.primaryText.opacity(0.1))
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.primaryText.opacity(0.1))
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.primaryText.opacity(0.1))
                    .frame(height: 16)
                    .frame(width: CGFloat.random(in: 150...250))
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .shimmer()
    }
}

// MARK: - Skeleton Pal Card
/// Skeleton placeholder for partnership cards while loading
struct SkeletonPalCard: View {
    @Environment(\.theme) var theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.primaryBlue.opacity(0.15))
                .frame(width: 120, height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.secondaryText.opacity(0.1))
                .frame(width: 90, height: 12)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .shimmer()
    }
}

// MARK: - Skeleton List (Reusable)
/// Generic skeleton list that displays multiple skeleton items
struct SkeletonList<SkeletonItem: View>: View {
    let count: Int
    let skeletonItem: () -> SkeletonItem

    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            skeletonItem()
        }
    }
}
