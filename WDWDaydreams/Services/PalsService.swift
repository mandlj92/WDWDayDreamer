import FirebaseFirestore
import Foundation

class PalsService {
    private let db = Firestore.firestore()
    private let invitationsCollection = "palInvitations"
    private let partnershipsCollection = "storyPartnerships"

    // MARK: - Invitation Management

    func createInvitation(fromUser: UserProfile) async throws -> PalInvitation {
        // Rate limiting: Check pending invitations count
        let pendingCount = try await getPendingInvitationCount(userId: fromUser.id)
        guard pendingCount < 10 else {
            throw NSError(
                domain: "PalsService",
                code: 429,
                userInfo: [NSLocalizedDescriptionKey: "You have reached the maximum of 10 pending invitations. Please wait for some to be accepted or expire before creating more."]
            )
        }

        // Rate limiting: Check recent invitation creation (last hour)
        let recentCount = try await getRecentInvitationCount(userId: fromUser.id, withinHours: 1)
        guard recentCount < 5 else {
            throw NSError(
                domain: "PalsService",
                code: 429,
                userInfo: [NSLocalizedDescriptionKey: "You can only create 5 invitations per hour. Please try again later."]
            )
        }

        // Generate a unique 6-character invitation code
        let invitationCode = generateInvitationCode()

        let invitation = PalInvitation(
            fromUserId: fromUser.id,
            fromUserName: fromUser.displayName,
            fromUserEmail: fromUser.email,
            invitationCode: invitationCode
        )

        try await db.collection(invitationsCollection)
            .document(invitation.id)
            .setData(invitation.dictionary)

        return invitation
    }

    func getInvitationByCode(_ code: String) async throws -> PalInvitation? {
        let query = try await db.collection(invitationsCollection)
            .whereField("invitationCode", isEqualTo: code)
            .whereField("status", isEqualTo: InvitationStatus.pending.rawValue)
            .getDocuments()

        guard let document = query.documents.first else {
            return nil
        }

        return PalInvitation(document: document)
    }

    func acceptInvitation(_ invitation: PalInvitation, byUser userId: String) async throws -> StoryPartnership {
        // Update invitation status
        try await db.collection(invitationsCollection)
            .document(invitation.id)
            .updateData([
                "status": InvitationStatus.accepted.rawValue,
                "toUserId": userId
            ])

        // Create partnership
        let partnership = StoryPartnership(
            user1Id: invitation.fromUserId,
            user2Id: userId,
            nextAuthorId: invitation.fromUserId // First author is the inviter
        )

        try await db.collection(partnershipsCollection)
            .document(partnership.id)
            .setData(partnership.dictionary)

        // Add connection to both users
        let userService = UserService()
        try await userService.addConnection(userId: invitation.fromUserId, connectionId: userId)
        try await userService.addConnection(userId: userId, connectionId: invitation.fromUserId)

        return partnership
    }

    func declineInvitation(_ invitationId: String) async throws {
        try await db.collection(invitationsCollection)
            .document(invitationId)
            .updateData([
                "status": InvitationStatus.declined.rawValue
            ])
    }

    func getUserInvitations(userId: String) async throws -> [PalInvitation] {
        let query = try await db.collection(invitationsCollection)
            .whereField("fromUserId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return query.documents.compactMap { PalInvitation(document: $0) }
    }

    // MARK: - Partnership Management

    func getUserPartnerships(userId: String) async throws -> [StoryPartnership] {
        // Query where user is either user1 or user2
        let query1 = try await db.collection(partnershipsCollection)
            .whereField("user1Id", isEqualTo: userId)
            .getDocuments()

        let query2 = try await db.collection(partnershipsCollection)
            .whereField("user2Id", isEqualTo: userId)
            .getDocuments()

        let partnerships1 = query1.documents.compactMap { StoryPartnership(document: $0) }
        let partnerships2 = query2.documents.compactMap { StoryPartnership(document: $0) }

        // Combine and remove duplicates
        let allPartnerships = partnerships1 + partnerships2
        return Array(Set(allPartnerships.map { $0.id }))
            .compactMap { id in allPartnerships.first { $0.id == id } }
    }

    func getPartnership(user1Id: String, user2Id: String) async throws -> StoryPartnership? {
        // Try both user orderings
        let query1 = try await db.collection(partnershipsCollection)
            .whereField("user1Id", isEqualTo: user1Id)
            .whereField("user2Id", isEqualTo: user2Id)
            .getDocuments()

        if let doc = query1.documents.first {
            return StoryPartnership(document: doc)
        }

        let query2 = try await db.collection(partnershipsCollection)
            .whereField("user1Id", isEqualTo: user2Id)
            .whereField("user2Id", isEqualTo: user1Id)
            .getDocuments()

        if let doc = query2.documents.first {
            return StoryPartnership(document: doc)
        }

        return nil
    }

    func updatePartnership(_ partnership: StoryPartnership) async throws {
        try await db.collection(partnershipsCollection)
            .document(partnership.id)
            .updateData(partnership.dictionary)
    }

    func removePartnership(_ partnershipId: String, user1Id: String, user2Id: String) async throws {
        // Delete partnership
        try await db.collection(partnershipsCollection)
            .document(partnershipId)
            .delete()

        // Remove connections from both users
        let userService = UserService()
        try await userService.removeConnection(userId: user1Id, connectionId: user2Id)
        try await userService.removeConnection(userId: user2Id, connectionId: user1Id)
    }

    // MARK: - Helper Methods

    private func generateInvitationCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Removed ambiguous characters
        return String((0..<6).compactMap { _ in characters.randomElement() })
    }

    /// Get the count of pending invitations for a user (for rate limiting)
    private func getPendingInvitationCount(userId: String) async throws -> Int {
        let query = try await db.collection(invitationsCollection)
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: InvitationStatus.pending.rawValue)
            .getDocuments()

        return query.documents.count
    }

    /// Get the count of invitations created within the last N hours (for rate limiting)
    private func getRecentInvitationCount(userId: String, withinHours hours: Int) async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()

        let query = try await db.collection(invitationsCollection)
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("createdAt", isGreaterThan: Timestamp(date: cutoffDate))
            .getDocuments()

        return query.documents.count
    }

    /// Cleanup expired invitations - should be called periodically (e.g., daily via Cloud Function)
    func cleanupExpiredInvitations() async throws {
        let query = try await db.collection(invitationsCollection)
            .whereField("status", isEqualTo: InvitationStatus.pending.rawValue)
            .getDocuments()

        let batch = db.batch()
        var updateCount = 0

        for document in query.documents {
            if let invitation = PalInvitation(document: document), invitation.isExpired {
                let ref = db.collection(invitationsCollection).document(document.documentID)
                batch.updateData(["status": InvitationStatus.expired.rawValue], forDocument: ref)
                updateCount += 1
            }
        }

        if updateCount > 0 {
            try await batch.commit()
            print("✅ Cleaned up \(updateCount) expired invitations")
        }
    }

    /// Delete old expired and declined invitations (cleanup for database size management)
    func deleteOldInvitations(olderThanDays days: Int = 30) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let query = try await db.collection(invitationsCollection)
            .whereField("createdAt", isLessThan: Timestamp(date: cutoffDate))
            .getDocuments()

        let batch = db.batch()
        var deleteCount = 0

        for document in query.documents {
            if let invitation = PalInvitation(document: document),
               invitation.status == .expired || invitation.status == .declined {
                let ref = db.collection(invitationsCollection).document(document.documentID)
                batch.deleteDocument(ref)
                deleteCount += 1
            }
        }

        if deleteCount > 0 {
            try await batch.commit()
            print("✅ Deleted \(deleteCount) old invitations")
        }
    }
}
