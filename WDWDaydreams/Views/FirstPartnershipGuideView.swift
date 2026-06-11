import SwiftUI

struct FirstPartnershipGuideView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme: Theme

    var onCreateInvite: () -> Void
    var onJoinCode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("Connect with a Story Pal")
                    .font(DesignSystem.Typography.pageTitle)
                    .foregroundColor(theme.primaryText)

                Text("To start creating theme park stories, you'll need to connect with a friend or family member.")
                    .font(DesignSystem.Typography.subtext)
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, DesignSystem.Spacing.xl)

            Hairline()

            // Option 1
            Button(action: {
                dismiss()
                onCreateInvite()
            }) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Invite Someone")
                        .font(DesignSystem.Typography.sectionTitle)
                        .foregroundColor(theme.primaryText)
                    Text("Generate a code to share with your friend")
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .buttonStyle(.plain)

            Hairline()

            // Option 2
            Button(action: {
                dismiss()
                onJoinCode()
            }) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Join with Code")
                        .font(DesignSystem.Typography.sectionTitle)
                        .foregroundColor(theme.primaryText)
                    Text("Enter an invitation code a friend has sent you")
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .buttonStyle(.plain)

            Hairline()

            Spacer()

            Button("I'll do this later") {
                dismiss()
            }
            .buttonStyle(InlineActionButtonStyle(color: theme.secondaryText))
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .padding(.horizontal, DesignSystem.Spacing.pageMargin)
    }
}
