import SwiftUI

struct TodayView: View {
    @EnvironmentObject var manager: ScenarioManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.theme) var theme: Theme

    @State private var showingFirstPartnershipGuide = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if manager.isLoadingPartnership {
                    ProgressView("Loading...")
                        .padding()
                } else if manager.selectedPartnership == nil {
                    // No partnership selected - show guide
                    emptyStateView
                } else {
                    // Show partnership info and today's story
                    VStack(spacing: 16) {
                        // Partnership header
                        partnershipHeader

                        // Today's story prompt
                        if let prompt = manager.currentStoryPrompt {
                            ParkPromptView(
                                prompt: prompt,
                                isUsersTurn: isUsersTurn(for: prompt),
                                onToggleFavorite: {
                                    manager.toggleFavorite()
                                },
                                onSaveStory: { text in
                                    Task {
                                        await manager.saveStoryText(text, for: prompt.id)
                                    }
                                }
                            )
                        } else {
                            Text("No story for today yet")
                                .foregroundColor(theme.secondaryText)
                                .padding()
                        }
                    }
                }
            }
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
        VStack(spacing: 24) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(theme.primaryBlue)

            Text("Connect with a Story Pal")
                .font(.parkTitle(24))
                .foregroundColor(theme.primaryBlue)
                .multilineTextAlignment(.center)

            Text("To start creating daily Disney daydreams, you need to connect with a Story Pal. Go to the Pals tab to:")
                .font(.body)
                .foregroundColor(theme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(theme.accentGold)
                    Text("Invite someone to be your Story Pal")
                        .foregroundColor(theme.primaryText)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(theme.accentGold)
                    Text("Or join using a friend's invitation code")
                        .foregroundColor(theme.primaryText)
                }
            }
            .padding()
            .background(theme.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal)

            Text("Once connected, you'll take turns creating magical Disney stories together!")
                .font(.caption)
                .italic()
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Partnership Header

    private var partnershipHeader: some View {
        VStack(spacing: 8) {
            if let partnership = manager.selectedPartnership,
               let currentUserId = authViewModel.userProfile?.id {

                let partnerId = partnership.user1Id == currentUserId ? partnership.user2Id : partnership.user1Id
                let partnerName = manager.partnerProfiles[partnerId]?.displayName ?? "Your Pal"

                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(theme.accentPurple)

                    Text("Story with \(partnerName)")
                        .font(.headline)
                        .foregroundColor(theme.primaryText)

                    Spacer()
                }
                .padding(.horizontal)

                // Show trip date if available
                if let tripDate = partnership.sharedTripDate {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(theme.accentGold)

                        Text("Trip: \(tripDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)

                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
        .background(theme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Helper Methods

    private func isUsersTurn(for prompt: DaydreamStory) -> Bool {
        guard let currentUserId = authViewModel.userProfile?.id else { return false }
        return prompt.assignedAuthor.userId == currentUserId
    }
}
