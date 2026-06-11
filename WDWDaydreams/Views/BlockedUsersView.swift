import SwiftUI

/// View for managing blocked users
struct BlockedUsersView: View {
    @StateObject private var moderationService = ModerationService()
    @State private var blockedUserIds: [String] = []
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else if blockedUserIds.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("No blocked users")
                        .font(DesignSystem.Typography.sectionTitle)
                    Text("You haven't blocked anyone.")
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, DesignSystem.Spacing.xl)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(blockedUserIds, id: \.self) { userId in
                    HStack(alignment: .firstTextBaseline) {
                        Text(userId)
                            .font(DesignSystem.Typography.body)

                        Spacer()

                        Button("Unblock") {
                            unblockUser(userId)
                        }
                        .buttonStyle(InlineActionButtonStyle(color: ThemeColors.primaryBlue))
                    }
                    .padding(.vertical, DesignSystem.Spacing.xxs)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadBlockedUsers() }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func loadBlockedUsers() {
        Task {
            do {
                let users = try await moderationService.getBlockedUsers()
                await MainActor.run {
                    blockedUserIds = users
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }

    private func unblockUser(_ userId: String) {
        Task {
            do {
                try await moderationService.unblockUser(userId)
                await MainActor.run {
                    blockedUserIds.removeAll { $0 == userId }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
