import Foundation
import FirebaseAuth
import FirebaseFirestore
import UIKit

/// Manages user sessions, device tracking, and session timeout
class SessionManager: ObservableObject {
    static let shared = SessionManager()

    private let db = Firestore.firestore()

    // Session configuration
    private let sessionTimeout: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    private let inactivityTimeout: TimeInterval = 15 * 60 // 15 minutes
    private let maxConcurrentSessions = 5

    @Published var isSessionValid = true
    @Published var requiresReauthentication = false

    private var lastActivityDate: Date?
    private var inactivityTimer: Timer?

    private init() {
        setupInactivityMonitoring()
    }

    // MARK: - Session Lifecycle

    /// Initialize session when user logs in
    func startSession(userId: String) async throws {
        let deviceInfo = getDeviceFingerprint()

        let sessionData: [String: Any] = [
            "deviceId": deviceInfo.deviceId,
            "deviceName": deviceInfo.deviceName,
            "deviceModel": deviceInfo.deviceModel,
            "osVersion": deviceInfo.osVersion,
            "appVersion": deviceInfo.appVersion,
            "lastActiveAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp(),
            "ipAddress": deviceInfo.ipAddress ?? "unknown",
            "isActive": true
        ]

        // Add session to user's active sessions
        try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(deviceInfo.deviceId)
            .setData(sessionData, merge: true)

        // Update user's last active timestamp
        try await db.collection("users")
            .document(userId)
            .updateData([
                "lastActiveAt": FieldValue.serverTimestamp()
            ])

        // Check for concurrent session limit
        try await enforceConcurrentSessionLimit(userId: userId)

        lastActivityDate = Date()
        startInactivityTimer()

        print("✅ Session started for device: \(deviceInfo.deviceId)")
    }

    /// Update session activity
    func updateActivity(userId: String) async {
        guard let user = Auth.auth().currentUser else { return }

        lastActivityDate = Date()

        let deviceId = getDeviceFingerprint().deviceId

        // Update session last activity (throttled to prevent excessive writes)
        do {
            try await db.collection("users")
                .document(userId)
                .collection("sessions")
                .document(deviceId)
                .updateData([
                    "lastActiveAt": FieldValue.serverTimestamp()
                ])

            // Also update user's global lastActiveAt
            try await db.collection("users")
                .document(userId)
                .updateData([
                    "lastActiveAt": FieldValue.serverTimestamp()
                ])
        } catch {
            print("⚠️ Error updating activity: \(error.localizedDescription)")
        }
    }

    /// End current session
    func endSession(userId: String) async throws {
        let deviceId = getDeviceFingerprint().deviceId

        try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(deviceId)
            .updateData([
                "isActive": false,
                "endedAt": FieldValue.serverTimestamp()
            ])

        stopInactivityTimer()
        lastActivityDate = nil

        print("✅ Session ended for device: \(deviceId)")
    }

    // MARK: - Session Validation

    /// Check if current session is valid
    func validateSession(userId: String) async throws -> Bool {
        let deviceId = getDeviceFingerprint().deviceId

        let sessionDoc = try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(deviceId)
            .getDocument()

        guard sessionDoc.exists,
              let data = sessionDoc.data(),
              let isActive = data["isActive"] as? Bool,
              isActive else {
            isSessionValid = false
            return false
        }

        // Check session timeout (30 days)
        if let createdAt = data["createdAt"] as? Timestamp {
            let sessionAge = Date().timeIntervalSince(createdAt.dateValue())
            if sessionAge > sessionTimeout {
                print("⚠️ Session expired (age: \(sessionAge)s)")
                try await endSession(userId: userId)
                isSessionValid = false
                return false
            }
        }

        // Check inactivity timeout (15 minutes)
        if let lastActiveAt = data["lastActiveAt"] as? Timestamp {
            let inactivityDuration = Date().timeIntervalSince(lastActiveAt.dateValue())
            if inactivityDuration > inactivityTimeout {
                print("⚠️ Session inactive (duration: \(inactivityDuration)s)")
                isSessionValid = false
                return false
            }
        }

        isSessionValid = true
        return true
    }

    /// Require re-authentication for sensitive operations
    func requireReauthentication(for operation: SensitiveOperation) async throws {
        guard let user = Auth.auth().currentUser else {
            throw SessionError.notAuthenticated
        }

        // Check when user last signed in
        let lastSignInDate = user.metadata.lastSignInDate ?? Date.distantPast
        let timeSinceSignIn = Date().timeIntervalSince(lastSignInDate)

        // Require re-auth if sign-in was more than 5 minutes ago for sensitive operations
        let reauthThreshold: TimeInterval = 5 * 60 // 5 minutes

        if timeSinceSignIn > reauthThreshold {
            requiresReauthentication = true
            throw SessionError.reauthenticationRequired
        }
    }

    // MARK: - Device Management

    /// Get device fingerprint
    func getDeviceFingerprint() -> DeviceFingerprint {
        let device = UIDevice.current

        // Create stable device ID using identifierForVendor
        let deviceId = device.identifierForVendor?.uuidString ?? UUID().uuidString

        let deviceName = device.name
        let deviceModel = device.model
        let osVersion = "\(device.systemName) \(device.systemVersion)"

        // Get app version
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        return DeviceFingerprint(
            deviceId: deviceId,
            deviceName: deviceName,
            deviceModel: deviceModel,
            osVersion: osVersion,
            appVersion: appVersion,
            ipAddress: nil // IP address would need to be fetched from server
        )
    }

    /// Get all active sessions for a user
    func getActiveSessions(userId: String) async throws -> [UserSession] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .whereField("isActive", isEqualTo: true)
            .order(by: "lastActiveAt", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: UserSession.self)
        }
    }

    /// Revoke a specific session
    func revokeSession(userId: String, sessionId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .updateData([
                "isActive": false,
                "revokedAt": FieldValue.serverTimestamp()
            ])

        print("✅ Session revoked: \(sessionId)")
    }

    /// Revoke all sessions except current
    func revokeAllOtherSessions(userId: String) async throws {
        let currentDeviceId = getDeviceFingerprint().deviceId

        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        for doc in snapshot.documents {
            if doc.documentID != currentDeviceId {
                try await revokeSession(userId: userId, sessionId: doc.documentID)
            }
        }

        print("✅ All other sessions revoked")
    }

    /// Enforce concurrent session limit
    private func enforceConcurrentSessionLimit(userId: String) async throws {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .whereField("isActive", isEqualTo: true)
            .order(by: "lastActiveAt", descending: true)
            .getDocuments()

        // If over limit, revoke oldest sessions
        if snapshot.documents.count > maxConcurrentSessions {
            let sessionsToRevoke = snapshot.documents.dropFirst(maxConcurrentSessions)

            for session in sessionsToRevoke {
                try await revokeSession(userId: userId, sessionId: session.documentID)
            }

            print("⚠️ Enforced session limit: revoked \(sessionsToRevoke.count) sessions")
        }
    }

    // MARK: - Inactivity Monitoring

    private func setupInactivityMonitoring() {
        // Monitor app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // Monitor user interactions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidInteract),
            name: NSNotification.Name("UserInteraction"),
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        startInactivityTimer()
        Task {
            if let userId = Auth.auth().currentUser?.uid {
                let isValid = try? await validateSession(userId: userId)
                if isValid == false {
                    // Session expired, log out user
                    try? Auth.auth().signOut()
                }
            }
        }
    }

    @objc private func appDidEnterBackground() {
        stopInactivityTimer()
    }

    @objc private func userDidInteract() {
        lastActivityDate = Date()

        // Update activity in Firestore (throttled)
        Task {
            if let userId = Auth.auth().currentUser?.uid {
                await updateActivity(userId: userId)
            }
        }
    }

    private func startInactivityTimer() {
        stopInactivityTimer()

        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkInactivity()
        }
    }

    private func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    private func checkInactivity() {
        guard let lastActivity = lastActivityDate else { return }

        let inactivityDuration = Date().timeIntervalSince(lastActivity)

        if inactivityDuration > inactivityTimeout {
            print("⚠️ User inactive for \(inactivityDuration)s")
            isSessionValid = false

            // Log out user
            Task {
                try? Auth.auth().signOut()
            }
        }
    }

    // MARK: - Sensitive Operations

    enum SensitiveOperation {
        case deleteAccount
        case changePassword
        case changeEmail
        case viewPrivateData
        case financialTransaction
    }
}

// MARK: - Data Models

struct DeviceFingerprint {
    let deviceId: String
    let deviceName: String
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let ipAddress: String?
}

struct UserSession: Codable, Identifiable {
    @DocumentID var id: String?
    let deviceId: String
    let deviceName: String
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let lastActiveAt: Date?
    let createdAt: Date?
    let isActive: Bool
    var endedAt: Date?
    var revokedAt: Date?
    let ipAddress: String?

    var lastActiveDescription: String {
        guard let lastActive = lastActiveAt else { return "Unknown" }
        return formatTimeAgo(lastActive)
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

enum SessionError: Error, LocalizedError {
    case notAuthenticated
    case sessionExpired
    case sessionInactive
    case reauthenticationRequired
    case tooManyConcurrentSessions

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .sessionInactive:
            return "Your session has been inactive for too long. Please sign in again."
        case .reauthenticationRequired:
            return "This operation requires re-authentication. Please sign in again."
        case .tooManyConcurrentSessions:
            return "Too many active sessions. Please sign out from other devices."
        }
    }
}