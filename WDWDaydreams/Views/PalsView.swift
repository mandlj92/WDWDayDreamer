import SwiftUI

struct PalsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var palsViewModel = PalsViewModel()
    @Environment(\.theme) var theme: Theme

    @State private var showingInviteSheet = false
    @State private var showingJoinSheet = false
    @State private var inviteCodeInput = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40))
                        .foregroundColor(theme.magicBlue)

                    Text("Story Pals")
                        .font(.disneyTitle(28))
                        .foregroundColor(theme.magicBlue)

                    Text("Connect with others to share Disney Daydreams")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: { showingInviteSheet = true }) {
                        VStack {
                            Image(systemName: "person.badge.plus")
                                .font(.title2)
                            Text("Invite Pal")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.magicBlue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    Button(action: { showingJoinSheet = true }) {
                        VStack {
                            Image(systemName: "key.fill")
                                .font(.title2)
                            Text("Join with Code")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.mainStreetGold)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                // Messages
                if let errorMessage = palsViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(theme.mickeyRed)
                        .padding()
                        .background(theme.mickeyRed.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                if let successMessage = palsViewModel.successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                // My Story Pals Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("My Story Pals")
                        .font(.headline)
                        .foregroundColor(theme.magicBlue)
                        .padding(.horizontal)

                    if palsViewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if palsViewModel.partnerships.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2.slash")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("No story pals yet")
                                .foregroundColor(.secondary)
                            Text("Invite someone or join with a code to get started!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(palsViewModel.partnerships) { partnership in
                            if let userId = authViewModel.userProfile?.id {
                                PalCard(
                                    partnerName: palsViewModel.getPartnerName(for: partnership, currentUserId: userId),
                                    partnership: partnership,
                                    onRemove: {
                                        Task {
                                            await palsViewModel.removePartnership(partnership, currentUserId: userId)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)

                // My Invitations Section
                if !palsViewModel.myInvitations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Invitations")
                            .font(.headline)
                            .foregroundColor(theme.magicBlue)
                            .padding(.horizontal)

                        ForEach(palsViewModel.myInvitations.filter { $0.status == .pending && !$0.isExpired }) { invitation in
                            InvitationCard(invitation: invitation)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
            }
            .padding(.vertical)
        }
        .background(theme.backgroundCream.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $showingInviteSheet) {
            CreateInviteSheet(palsViewModel: palsViewModel, userProfile: authViewModel.userProfile)
        }
        .sheet(isPresented: $showingJoinSheet) {
            JoinWithCodeSheet(
                palsViewModel: palsViewModel,
                userId: authViewModel.userProfile?.id ?? "",
                userName: authViewModel.userProfile?.displayName ?? ""
            )
        }
        .task {
            if let userId = authViewModel.userProfile?.id {
                await palsViewModel.loadPartnerships(for: userId)
                await palsViewModel.loadMyInvitations(for: userId)
            }
        }
        .refreshable {
            if let userId = authViewModel.userProfile?.id {
                await palsViewModel.loadPartnerships(for: userId)
                await palsViewModel.loadMyInvitations(for: userId)
            }
        }
    }
}

// MARK: - Pal Card

struct PalCard: View {
    let partnerName: String
    let partnership: StoryPartnership
    let onRemove: () -> Void

    @Environment(\.theme) var theme: Theme
    @State private var showingRemoveAlert = false

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.largeTitle)
                .foregroundColor(theme.magicBlue)

            VStack(alignment: .leading, spacing: 4) {
                Text(partnerName)
                    .font(.headline)
                    .foregroundColor(theme.magicBlue)

                Text("Connected \(partnership.createdAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let tripDate = partnership.sharedTripDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("Trip: \(tripDate, style: .date)")
                            .font(.caption)
                    }
                    .foregroundColor(theme.mainStreetGold)
                }
            }

            Spacer()

            Button(action: { showingRemoveAlert = true }) {
                Image(systemName: "trash")
                    .foregroundColor(theme.mickeyRed)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .alert("Remove Story Pal", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("Are you sure you want to remove \(partnerName) as a story pal? This will delete all shared stories.")
        }
    }
}

// MARK: - Invitation Card

struct InvitationCard: View {
    let invitation: PalInvitation

    @Environment(\.theme) var theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(theme.mainStreetGold)

                Text("Invitation Code")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }

            Text(invitation.invitationCode)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.magicBlue)
                .tracking(2)

            Text("Expires \(invitation.expiresAt, style: .date)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var statusText: String {
        switch invitation.status {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .expired: return "Expired"
        }
    }

    private var statusColor: Color {
        switch invitation.status {
        case .pending: return .orange
        case .accepted: return .green
        case .declined: return .red
        case .expired: return .gray
        }
    }
}

// MARK: - Create Invite Sheet

struct CreateInviteSheet: View {
    @ObservedObject var palsViewModel: PalsViewModel
    let userProfile: UserProfile?

    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme: Theme

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 60))
                    .foregroundColor(theme.magicBlue)
                    .padding(.top, 40)

                Text("Invite a Story Pal")
                    .font(.disneyTitle(24))
                    .foregroundColor(theme.magicBlue)

                Text("Generate an invitation code to share with a friend")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let code = palsViewModel.generatedInviteCode {
                    VStack(spacing: 12) {
                        Text("Your Invitation Code")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(code)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(theme.magicBlue)
                            .tracking(4)
                            .padding()
                            .background(theme.backgroundCream)
                            .cornerRadius(12)

                        Button(action: {
                            UIPasteboard.general.string = code
                            HapticManager.instance.notification(type: .success)
                        }) {
                            Label("Copy Code", systemImage: "doc.on.doc")
                                .foregroundColor(theme.magicBlue)
                        }

                        Text("Share this code with your friend. It expires in 7 days.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    Button(action: {
                        Task {
                            if let profile = userProfile {
                                await palsViewModel.createInvitation(fromUser: profile)
                            }
                        }
                    }) {
                        if palsViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Generate Invitation Code")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.magicBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(palsViewModel.isLoading)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Join with Code Sheet

struct JoinWithCodeSheet: View {
    @ObservedObject var palsViewModel: PalsViewModel
    let userId: String
    let userName: String

    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme: Theme

    @State private var inviteCode = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(theme.mainStreetGold)
                    .padding(.top, 40)

                Text("Join with Code")
                    .font(.disneyTitle(24))
                    .foregroundColor(theme.magicBlue)

                Text("Enter the invitation code from your friend")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Enter Code", text: $inviteCode)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .textCase(.uppercase)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    Task {
                        await palsViewModel.acceptInvitation(code: inviteCode.trimmingCharacters(in: .whitespaces), userId: userId, userName: userName)
                        if palsViewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }) {
                    if palsViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Join")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(inviteCode.isEmpty ? Color.gray : theme.mainStreetGold)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(inviteCode.isEmpty || palsViewModel.isLoading)

                if let errorMessage = palsViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(theme.mickeyRed)
                        .padding()
                        .background(theme.mickeyRed.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
