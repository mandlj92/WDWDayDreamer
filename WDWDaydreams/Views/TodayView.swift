import SwiftUI

struct TodayView: View {
    @EnvironmentObject var manager: ScenarioManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.theme) var theme: Theme

    @State private var showingFirstPartnershipGuide = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                if manager.isLoadingPartnership {
                    SkeletonList(count: 1) {
                        SkeletonStoryCard()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.pageMargin)
                } else if manager.selectedPartnership == nil {
                    emptyStateView
                } else {
                    partnershipHeader

                    if let prompt = manager.currentStoryPrompt {
                        let partnerName = getPartnerName()
                        ParkPromptView(
                            prompt: prompt,
                            isUsersTurn: isUsersTurn(for: prompt),
                            partnerName: partnerName,
                            onToggleFavorite: {
                                manager.toggleFavorite()
                            },
                            onSaveStory: { text in
                                Task {
                                    manager.saveStoryText(text, for: prompt.id)
                                }
                            }
                        )
                    } else {
                        Text("No story for today yet")
                            .font(DesignSystem.Typography.subtext)
                            .italic()
                            .foregroundColor(theme.tertiaryText)
                            .padding(.horizontal, DesignSystem.Spacing.pageMargin)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical)
        }
        .sheet(isPresented: $showingFirstPartnershipGuide) {
            FirstPartnershipGuideView(
                onCreateInvite: {
                    // This would navigate to Pals tab - for now just dismiss
                },
                onJoinCode: {
                    // This would navigate to Pals tab - for now just dismiss
                }
            )
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Connect with a Story Pal")
                .font(DesignSystem.Typography.pageTitle)
                .foregroundColor(theme.primaryText)
                .padding(.top, DesignSystem.Spacing.xl)

            Text("To start creating daily Disney daydreams, connect with a Story Pal from the Pals tab.")
                .font(DesignSystem.Typography.subtext)
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                    Text("1.")
                        .font(DesignSystem.Typography.sectionTitle)
                        .foregroundColor(theme.accentGold)
                    Text("Invite someone to be your Story Pal")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(theme.primaryText)
                }

                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                    Text("2.")
                        .font(DesignSystem.Typography.sectionTitle)
                        .foregroundColor(theme.accentGold)
                    Text("Or join using a friend's invitation code")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(theme.primaryText)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)

            Text("Once connected, you'll take turns creating magical Disney stories together.")
                .font(DesignSystem.Typography.meta)
                .italic()
                .foregroundColor(theme.tertiaryText)
        }
        .padding(.horizontal, DesignSystem.Spacing.pageMargin)
    }

    // MARK: - Partnership Header

    @ViewBuilder
    private var partnershipHeader: some View {
        if let partnership = manager.selectedPartnership,
           let currentUserId = authViewModel.userProfile?.id {

            let partnerId = partnership.user1Id == currentUserId ? partnership.user2Id : partnership.user1Id
            let partnerName = manager.partnerProfiles[partnerId]?.displayName ?? "Your Pal"

            VStack(alignment: .leading, spacing: 2) {
                SectionLabel("Story with \(partnerName)", color: theme.accentPurple)

                if let tripDate = partnership.sharedTripDate {
                    Text("Trip \(tripDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(DesignSystem.Typography.meta)
                        .foregroundColor(theme.secondaryText)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.pageMargin)
        }
    }

    // MARK: - Helper Methods

    private func isUsersTurn(for prompt: DaydreamStory) -> Bool {
        guard let currentUserId = authViewModel.userProfile?.id else { return false }
        return prompt.assignedAuthor.userId == currentUserId
    }

    private func getPartnerName() -> String {
        guard let partnership = manager.selectedPartnership,
              let currentUserId = authViewModel.userProfile?.id else {
            return "your pal"
        }

        let partnerId = partnership.user1Id == currentUserId ? partnership.user2Id : partnership.user1Id
        return manager.partnerProfiles[partnerId]?.displayName ?? "your pal"
    }
}
