import SwiftUI
import FirebaseAuth

/// View for managing active sessions and devices
struct ActiveSessionsView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @State private var sessions: [UserSession] = []
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRevokeAllAlert = false
    @State private var sessionToRevoke: UserSession?

    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    Text("Signed in on \(sessions.count) device\(sessions.count == 1 ? "" : "s").")
                        .font(DesignSystem.Typography.subtext)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section(header: SectionHeaderText("Active Devices")) {
                    ForEach(sessions) { session in
                        SessionRow(session: session, isCurrentDevice: isCurrentDevice(session))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !isCurrentDevice(session) {
                                    Button(role: .destructive) {
                                        sessionToRevoke = session
                                    } label: {
                                        Label("Revoke", systemImage: "xmark.circle")
                                    }
                                }
                            }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showRevokeAllAlert = true
                    } label: {
                        Text("Sign Out All Other Devices")
                    }
                    .disabled(sessions.count <= 1)
                }

                Section {
                    Text("Sessions expire after 30 days of inactivity. You'll be automatically signed out after 15 minutes of inactivity.")
                        .font(DesignSystem.Typography.meta)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Active Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadSessions() }
        .refreshable { loadSessions() }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Revoke Session?", isPresented: .constant(sessionToRevoke != nil)) {
            Button("Cancel", role: .cancel) { sessionToRevoke = nil }
            Button("Revoke", role: .destructive) {
                if let session = sessionToRevoke {
                    revokeSession(session)
                }
            }
        } message: {
            if let session = sessionToRevoke {
                Text("This will sign out \(session.deviceName). You can always sign back in on that device.")
            }
        }
        .alert("Sign Out Other Devices?", isPresented: $showRevokeAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) { revokeAllOtherSessions() }
        } message: {
            Text("This will sign you out on all devices except this one.")
        }
    }

    private func isCurrentDevice(_ session: UserSession) -> Bool {
        session.deviceId == sessionManager.getDeviceFingerprint().deviceId
    }

    private func loadSessions() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                let loaded = try await sessionManager.getActiveSessions(userId: userId)
                await MainActor.run {
                    sessions = loaded
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

    private func revokeSession(_ session: UserSession) {
        guard let userId = Auth.auth().currentUser?.uid,
              let sessionId = session.id else { return }
        Task {
            do {
                try await sessionManager.revokeSession(userId: userId, sessionId: sessionId)
                await MainActor.run {
                    sessions.removeAll { $0.id == sessionId }
                    sessionToRevoke = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    sessionToRevoke = nil
                }
            }
        }
    }

    private func revokeAllOtherSessions() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                try await sessionManager.revokeAllOtherSessions(userId: userId)
                await MainActor.run { loadSessions() }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: UserSession
    let isCurrentDevice: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xs) {
                Text(session.deviceName)
                    .font(DesignSystem.Typography.sectionTitle)
                    .foregroundColor(.primary)

                if isCurrentDevice {
                    Text("This device")
                        .font(DesignSystem.Typography.meta)
                        .foregroundColor(ThemeColors.primaryBlue)
                }
            }

            Text("\(session.deviceModel) · \(session.osVersion)")
                .font(DesignSystem.Typography.meta)
                .foregroundColor(.secondary)

            Text("Last active \(session.lastActiveDescription)")
                .font(DesignSystem.Typography.meta)
                .foregroundColor(.secondary)

            if let ip = session.ipAddress, ip != "unknown" {
                Text("IP \(ip)")
                    .font(DesignSystem.Typography.meta)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xxs)
    }
}

// MARK: - Private helpers

private struct SectionHeaderText: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(DesignSystem.Typography.label)
            .tracking(1.2)
            .foregroundColor(.secondary)
    }
}
