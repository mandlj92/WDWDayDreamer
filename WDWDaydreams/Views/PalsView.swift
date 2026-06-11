import SwiftUI

struct PalsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var palsViewModel = PalsViewModel()
    @Environment(\.theme) var theme: Theme

    @State private var showingInviteSheet = false
    @State private var showingJoinSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Intro + actions
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Connect with others to share daydreams. Invite a friend, or join with a code they've sent you.")
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: DesignSystem.Spacing.lg) {
                        Button("Invite a Pal") { showingInviteSheet = true }
                            .buttonStyle(InlineActionButtonStyle(color: theme.primaryBlue))

                        Button("Join with Code") { showingJoinSheet = true }
                            .buttonStyle(InlineActionButtonStyle(color: theme.accentGold))
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.pageMargin)
                .padding(.top, DesignSystem.Spacing.xs)

                // Messages
                if let errorMessage = palsViewModel.errorMessage {
                    StatusLine(text: errorMessage, color: theme.accentRed)
                }

                if let successMessage = palsViewModel.successMessage {
                    StatusLine(text: successMessage, color: theme.accentGreen)
                }

                // My Story Pals Section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    SectionLabel("My Story Pals")
                        .padding(.horizontal, DesignSystem.Spacing.pageMargin)

                    Hairline()
                        .padding(.horizontal, DesignSystem.Spacing.pageMargin)

                    if palsViewModel.isLoading {
                        SkeletonList(count: 3) {
                            SkeletonPalCard()
                        }
                        .padding(.horizontal, DesignSystem.Spacing.pageMargin)
                    } else if palsViewModel.partnerships.isEmpty {
                        Text("No story pals yet — invite someone or join with a code to get started.")
                            .font(DesignSystem.Typography.subtext)
                            .italic()
                            .foregroundColor(theme.tertiaryText)
                            .padding(.horizontal, DesignSystem.Spacing.pageMargin)
                            .padding(.vertical, DesignSystem.Spacing.md)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
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

                                    if partnership.id != palsViewModel.partnerships.last?.id {
                                        Hairline()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.pageMargin)
                    }
                }

                // My Invitations Section
                let visibleInvitations = palsViewModel.myInvitations.filter { $0.status == .pending && !$0.isExpired }
                if !palsViewModel.myInvitations.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        SectionLabel("My Invitations")
                            .padding(.horizontal, DesignSystem.Spacing.pageMargin)

                        Hairline()
                            .padding(.horizontal, DesignSystem.Spacing.pageMargin)

                        if visibleInvitations.isEmpty {
                            Text("No active invitations.")
                                .font(DesignSystem.Typography.subtext)
                                .italic()
                                .foregroundColor(theme.tertiaryText)
                                .padding(.horizontal, DesignSystem.Spacing.pageMargin)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(visibleInvitations) { invitation in
                                    InvitationCard(invitation: invitation)

                                    if invitation.id != visibleInvitations.last?.id {
                                        Hairline()
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.pageMargin)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Status Line

/// Inline status feedback — colored text, no boxed background.
private struct StatusLine: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.subtext)
            .foregroundColor(color)
            .padding(.horizontal, DesignSystem.Spacing.pageMargin)
            .transition(.opacity)
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(partnerName)
                    .font(DesignSystem.Typography.sectionTitle)
                    .foregroundColor(theme.primaryText)

                Text("Connected \(partnership.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(DesignSystem.Typography.meta)
                    .foregroundColor(theme.secondaryText)

                if let tripDate = partnership.sharedTripDate {
                    Text("Trip \(tripDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(DesignSystem.Typography.meta)
                        .foregroundColor(theme.accentGold)
                }
            }

            Spacer()

            Button(action: { showingRemoveAlert = true }) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundColor(theme.accentRed)
            }
            .accessibilityLabel("Remove \(partnerName)")
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
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
    @State private var copied = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(invitation.invitationCode)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .foregroundColor(theme.primaryBlue)
                    .tracking(2)
                    .textSelection(.enabled)

                Text("Expires \(invitation.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(DesignSystem.Typography.meta)
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            Button(action: copyCode) {
                Text(copied ? "Copied" : "Copy")
            }
            .buttonStyle(InlineActionButtonStyle(color: copied ? theme.accentGreen : theme.primaryBlue))
            .accessibilityLabel("Copy invitation code")
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private func copyCode() {
        UIPasteboard.general.string = invitation.invitationCode
        HapticManager.instance.notification(type: .success)
        withAnimation(DesignSystem.Animation.quick) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(DesignSystem.Animation.quick) { copied = false }
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
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Invite a Story Pal")
                        .font(DesignSystem.Typography.pageTitle)
                        .foregroundColor(theme.primaryText)

                    Text("Generate an invitation code to share with a friend. It expires in 7 days.")
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, DesignSystem.Spacing.lg)

                if let code = palsViewModel.generatedInviteCode {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Hairline()

                        SectionLabel("Your Invitation Code")

                        Text(code)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.primaryBlue)
                            .tracking(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, DesignSystem.Spacing.xs)

                        Hairline()

                        Button(action: {
                            UIPasteboard.general.string = code
                            HapticManager.instance.notification(type: .success)
                        }) {
                            Label("Copy Code", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(InlineActionButtonStyle(color: theme.primaryBlue))
                    }
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
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Generate Invitation Code")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(ParkButtonStyle(color: theme.primaryBlue))
                    .disabled(palsViewModel.isLoading)
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.pageMargin)
            .background(theme.backgroundCream.edgesIgnoringSafeArea(.all))
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
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Join with Code")
                        .font(DesignSystem.Typography.pageTitle)
                        .foregroundColor(theme.primaryText)

                    Text("Enter the invitation code from your friend.")
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.top, DesignSystem.Spacing.lg)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    TextField("ABC123", text: $inviteCode)
                        .focused($codeFieldFocused)
                        .font(.system(.title2, design: .monospaced).weight(.semibold))
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                        .textCase(.uppercase)
                        .padding(.vertical, DesignSystem.Spacing.xs)

                    Rectangle()
                        .fill(codeFieldFocused ? theme.primaryBlue : theme.hairline)
                        .frame(height: codeFieldFocused ? 2 : 1)
                        .animation(DesignSystem.Animation.quick, value: codeFieldFocused)
                }

                Button(action: {
                    Task {
                        await palsViewModel.acceptInvitation(code: inviteCode.trimmingCharacters(in: .whitespaces), userId: userId, userName: userName)
                        if palsViewModel.errorMessage == nil {
                            HapticManager.instance.success()
                            dismiss()
                        }
                    }
                }) {
                    if palsViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Join")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ParkButtonStyle(color: theme.accentGold))
                .disabled(inviteCode.isEmpty || palsViewModel.isLoading)
                .opacity(inviteCode.isEmpty ? 0.5 : 1)

                if let errorMessage = palsViewModel.errorMessage {
                    Text(errorMessage)
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(theme.accentRed)
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.pageMargin)
            .background(theme.backgroundCream.edgesIgnoringSafeArea(.all))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear { codeFieldFocused = true }
        }
    }
}
