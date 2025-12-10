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
            } else if blockedUserIds.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Blocked Users")
                        .font(.headline)

                    Text("You haven't blocked anyone yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                ForEach(blockedUserIds, id: \.self) { userId in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(userId)
                                .font(.body)

                            Text("Blocked")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            unblockUser(userId)
                        } label: {
                            Text("Unblock")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBlockedUsers()
        }
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