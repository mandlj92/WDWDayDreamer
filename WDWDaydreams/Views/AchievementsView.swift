import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var manager: ScenarioManager
    @Environment(\.theme) var theme: Theme

    var body: some View {
        List {
            Section(header: SectionHeader(title: "Your Achievements", theme: theme)) {
                ForEach(Badge.allBadges) { badge in
                    let unlocked = auth.userProfile?.achievements.contains(badge.id) ?? false

                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                        Text(badge.icon)
                            .font(.title3)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(badge.name)
                                .font(DesignSystem.Typography.sectionTitle)
                                .foregroundColor(unlocked ? theme.primaryText : theme.secondaryText)
                            Text(badge.description)
                                .font(DesignSystem.Typography.meta)
                                .foregroundColor(theme.tertiaryText)
                        }

                        Spacer()

                        if unlocked {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(theme.accentGreen)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xxs)
                    .opacity(unlocked ? 1 : 0.5)
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
            .environmentObject(AuthViewModel())
            .environmentObject(ScenarioManager())
            .environmentObject(ThemeManager())
    }
}
