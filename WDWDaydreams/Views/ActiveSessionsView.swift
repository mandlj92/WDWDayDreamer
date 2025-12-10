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
            } else {
                Section {
                    Text("You're currently signed in on \(sessions.count) device\(sessions.count == 1 ? "" : "s").")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section("Active Devices") {
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
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Sign Out All Other Devices")
                        }
                    }
                    .disabled(sessions.count <= 1)
                }

                Section {
                    Text("For security, sessions expire after 30 days of inactivity. You'll be automatically signed out after 15 minutes of inactivity.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Active Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSessions()
        }
        .refreshable {
            loadSessions()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Revoke Session?", isPresented: .constant(sessionToRevoke != nil)) {
            Button("Cancel", role: .cancel) {
                sessionToRevoke = nil
            }
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
            Button("Sign Out", role: .destructive) {
                revokeAllOtherSessions()
            }
        } message: {
            Text("This will sign you out on all devices except this one. You'll need to sign in again on those devices.")
        }
    }

    private func isCurrentDevice(_ session: UserSession) -> Bool {
        let currentDeviceId = sessionManager.getDeviceFingerprint().deviceId
        return session.deviceId == currentDeviceId
    }

    private func loadSessions() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        Task {
            do {
                let loadedSessions = try await sessionManager.getActiveSessions(userId: userId)
                await MainActor.run {
                    sessions = loadedSessions
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
                await MainActor.run {
                    loadSessions()
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

struct SessionRow: View {
    let session: UserSession
    let isCurrentDevice: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Device icon
            Image(systemName: deviceIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.deviceName)
                        .font(.body)
                        .fontWeight(.medium)

                    if isCurrentDevice {
                        Text("This Device")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }

                Text("\(session.deviceModel) • \(session.osVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Last active: \(session.lastActiveDescription)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let ipAddress = session.ipAddress, ipAddress != "unknown" {
                    Text("IP: \(ipAddress)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !isCurrentDevice {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var deviceIcon: String {
        let model = session.deviceModel.lowercased()

        if model.contains("ipad") {
            return "ipad"
        } else if model.contains("iphone") {
            return "iphone"
        } else if model.contains("mac") {
            return "laptopcomputer"
        } else if model.contains("watch") {
            return "applewatch"
        } else {
            return "desktopcomputer"
        }
    }
}