import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for handling content moderation, reporting, and user blocking
class ModerationService: ObservableObject {
    private let db = Firestore.firestore()

    // MARK: - Content Reporting

    /// Report inappropriate content
    func reportContent(
        reportedUserId: String,
        contentType: ContentReport.ContentType,
        contentId: String,
        reason: ContentReport.ReportReason,
        details: String? = nil
    ) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ModerationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let report = ContentReport(
            reporterId: currentUserId,
            reportedUserId: reportedUserId,
            contentType: contentType,
            contentId: contentId,
            reason: reason,
            details: details
        )

        try db.collection("contentReports").addDocument(from: report)
        print("Content report submitted: \(contentType.rawValue) - \(contentId)")
    }

    /// Get reports submitted by the current user
    func getUserReports() async throws -> [ContentReport] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ModerationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let snapshot = try await db.collection("contentReports")
            .whereField("reporterId", isEqualTo: currentUserId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { document in
            try document.data(as: ContentReport.self)
        }
    }

    // MARK: - User Blocking

    /// Block a user
    func blockUser(_ userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ModerationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        guard userId != currentUserId else {
            throw NSError(domain: "ModerationService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot block yourself"])
        }

        let blockData: [String: Any] = [
            "blockedUserId": userId,
            "blockedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("users")
            .document(currentUserId)
            .collection("blockedUsers")
            .document(userId)
            .setData(blockData)

        print("User blocked: \(userId)")
    }

    /// Unblock a user
    func unblockUser(_ userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ModerationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await db.collection("users")
            .document(currentUserId)
            .collection("blockedUsers")
            .document(userId)
            .delete()

        print("User unblocked: \(userId)")
    }

    /// Check if a user is blocked
    func isUserBlocked(_ userId: String) async throws -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }

        let doc = try await db.collection("users")
            .document(currentUserId)
            .collection("blockedUsers")
            .document(userId)
            .getDocument()

        return doc.exists
    }

    /// Get list of blocked users
    func getBlockedUsers() async throws -> [String] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ModerationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let snapshot = try await db.collection("users")
            .document(currentUserId)
            .collection("blockedUsers")
            .getDocuments()

        return snapshot.documents.map { $0.documentID }
    }

    // MARK: - Content Moderation Status

    /// Check if content has been flagged by moderation
    func checkModerationStatus(
        contentType: ContentReport.ContentType,
        contentId: String
    ) async throws -> ModerationStatus {
        // For stories, check the story document
        if contentType == .story {
            // Parse partnershipId and storyId from contentId (format: "partnershipId/storyId")
            let components = contentId.split(separator: "/")
            guard components.count == 2 else {
                return .unknown
            }

            let partnershipId = String(components[0])
            let storyId = String(components[1])

            let doc = try await db.collection("partnerships")
                .document(partnershipId)
                .collection("stories")
                .document(storyId)
                .getDocument()

            if let moderationStatus = doc.data()?["moderationStatus"] as? String {
                return ModerationStatus(rawValue: moderationStatus) ?? .unknown
            }
        }

        // For profile content, check the user document
        if contentType == .profile || contentType == .displayName || contentType == .bio {
            let doc = try await db.collection("users")
                .document(contentId)
                .getDocument()

            if let moderationStatus = doc.data()?["moderationStatus"] as? String {
                return ModerationStatus(rawValue: moderationStatus) ?? .unknown
            }
        }

        return .unknown
    }

    enum ModerationStatus: String {
        case approved
        case flagged
        case removed
        case unknown
    }
}