import SwiftUI

// MARK: - Welcome Tour View
/// Multi-page welcome tour shown to new users before onboarding preferences
struct WelcomeTourView: View {
    @Binding var showTour: Bool
    @State private var currentPage = 0
    @Environment(\.theme) var theme: Theme

    private let pages: [WelcomePage] = [
        WelcomePage(
            icon: "sparkles",
            title: "Welcome to Disney Daydreams!",
            description: "Create magical Disney stories with friends and family. Each day brings a new creative prompt to inspire your imagination.",
            primaryColor: .blue
        ),
        WelcomePage(
            icon: "person.2.fill",
            title: "Connect with Story Pals",
            description: "Invite friends or family to be your Story Pal. Take turns writing stories inspired by Disney parks, characters, and memories.",
            primaryColor: .purple
        ),
        WelcomePage(
            icon: "wand.and.stars",
            title: "Daily Magical Prompts",
            description: "Every day, you'll receive a unique story prompt combining rides, foods, characters, and more from across Disney parks.",
            primaryColor: .orange
        ),
        WelcomePage(
            icon: "heart.text.square.fill",
            title: "Save Your Favorites",
            description: "Build a collection of your favorite Disney stories. Export, share, and relive your magical moments anytime.",
            primaryColor: .pink
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page Content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    WelcomePageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom Page Indicator
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? theme.magicBlue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.bottom, 20)

            // Navigation Buttons
            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button(action: previousPage) {
                        Text("Back")
                            .foregroundColor(theme.magicBlue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                }

                Button(action: nextPageOrFinish) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.magicBlue)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(theme.backgroundCream.edgesIgnoringSafeArea(.all))
    }

    private func previousPage() {
        withAnimation {
            currentPage -= 1
        }
    }

    private func nextPageOrFinish() {
        if currentPage < pages.count - 1 {
            withAnimation {
                currentPage += 1
            }
        } else {
            // Finish tour
            withAnimation {
                showTour = false
            }
        }
    }
}

// MARK: - Welcome Page Model
struct WelcomePage {
    let icon: String
    let title: String
    let description: String
    let primaryColor: Color
}

// MARK: - Individual Welcome Page View
struct WelcomePageView: View {
    let page: WelcomePage
    @Environment(\.theme) var theme: Theme

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.primaryColor)
                .padding(.bottom, 20)

            // Title
            Text(page.title)
                .font(.disneyTitle(28))
                .foregroundColor(theme.magicBlue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            // Description
            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
#Preview {
    WelcomeTourView(showTour: .constant(true))
        .environmentObject(ThemeManager())
}
