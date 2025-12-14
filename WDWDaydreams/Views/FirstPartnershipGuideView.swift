import SwiftUI

struct FirstPartnershipGuideView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme: Theme

    var onCreateInvite: () -> Void
    var onJoinCode: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(theme.primaryBlue)

            Text("Connect with a Story Pal")
                .font(.title2.weight(.bold))

            Text("To start creating theme park stories, you'll need to connect with a friend or family member.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: 16) {
                Button(action: {
                    dismiss()
                    onCreateInvite()
                }) {
                    VStack {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                        Text("Invite Someone")
                            .font(.headline)
                        Text("Create a code to share")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.primaryBlue.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(action: {
                    dismiss()
                    onJoinCode()
                }) {
                    VStack {
                        Image(systemName: "key.fill")
                            .font(.title2)
                        Text("Join with Code")
                            .font(.headline)
                        Text("Enter a friend's code")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.accentRed.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            Button("I'll do this later") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
    }
}
