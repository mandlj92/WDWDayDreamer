import SwiftUI

// MARK: - Welcome Tour View
struct WelcomeTourView: View {
    @Binding var showTour: Bool
    @State private var currentPage = 0
    @Environment(\.theme) var theme: Theme

    private let pages: [WelcomePage] = [
        WelcomePage(
            title: "Welcome to Daydreams",
            description: "Create magical theme park stories with friends and family. Each day brings a new creative prompt to inspire your imagination.",
            accent: ThemeColors.primaryBlue
        ),
        WelcomePage(
            title: "Connect with Story Pals",
            description: "Invite friends or family to be your Story Pal. Take turns writing stories inspired by theme parks, characters, and memories.",
            accent: ThemeColors.accentPurple
        ),
        WelcomePage(
            title: "Daily Magical Prompts",
            description: "Every day, you'll receive a unique story prompt combining rides, foods, characters, and more from across theme parks.",
            accent: ThemeColors.accentGold
        ),
        WelcomePage(
            title: "Save Your Favorites",
            description: "Build a collection of your favorite theme park stories. Export, share, and relive your magical moments anytime.",
            accent: ThemeColors.accentPink
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    WelcomePageView(page: pages[index], pageIndex: index, total: pages.count)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Controls
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Hairline()

                HStack(alignment: .center) {
                    // Dot indicator
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? theme.primaryBlue : theme.hairline)
                                .frame(width: currentPage == index ? 16 : 6, height: 6)
                                .animation(DesignSystem.Animation.spring, value: currentPage)
                        }
                    }

                    Spacer()

                    HStack(spacing: DesignSystem.Spacing.lg) {
                        if currentPage > 0 {
                            Button("Back", action: previousPage)
                                .buttonStyle(InlineActionButtonStyle(color: theme.secondaryText))
                        }

                        Button(currentPage == pages.count - 1 ? "Get Started" : "Next", action: nextPageOrFinish)
                            .buttonStyle(InlineActionButtonStyle(color: theme.primaryBlue))
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.pageMargin)
            }
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(theme.backgroundCream.edgesIgnoringSafeArea(.all))
    }

    private func previousPage() {
        withAnimation(DesignSystem.Animation.standard) { currentPage -= 1 }
    }

    private func nextPageOrFinish() {
        HapticManager.instance.impact(style: .light)
        if currentPage < pages.count - 1 {
            withAnimation(DesignSystem.Animation.standard) { currentPage += 1 }
        } else {
            withAnimation(DesignSystem.Animation.standard) { showTour = false }
        }
    }
}

// MARK: - Welcome Page Model
struct WelcomePage {
    let title: String
    let description: String
    let accent: Color
}

// MARK: - Individual Welcome Page View
struct WelcomePageView: View {
    let page: WelcomePage
    let pageIndex: Int
    let total: Int
    @Environment(\.theme) var theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Spacer()

            // Page counter — typographic position indicator instead of icon
            Text("\(pageIndex + 1) of \(total)")
                .font(DesignSystem.Typography.meta)
                .tracking(1)
                .foregroundColor(page.accent)

            Text(page.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(page.description)
                .font(DesignSystem.Typography.subtext)
                .foregroundColor(theme.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Preview
#Preview {
    WelcomeTourView(showTour: .constant(true))
        .environmentObject(ThemeManager())
}
