import FirebaseFirestore
import Foundation

class UserService {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    // MARK: - User Profile Operations
    
    func createUserProfile(_ userProfile: UserProfile) async throws {
        var profileData = userProfile.dictionary

        // SECURITY: Add denormalized searchable field for efficient privacy-aware queries
        profileData["searchable"] = userProfile.preferences.privacy.allowConnectionDiscovery

        try await db.collection(usersCollection)
            .document(userProfile.id)
            .setData(profileData)
    }
    
    func getUserProfile(userId: String) async throws -> UserProfile? {
        let document = try await db.collection(usersCollection)
            .document(userId)
            .getDocument()
        
        return UserProfile(document: document)
    }
    
    func updateUserProfile(_ userProfile: UserProfile) async throws {
        var updateData = userProfile.dictionary
        updateData["lastActiveAt"] = Timestamp(date: Date())

        // SECURITY: Sync denormalized searchable field with privacy settings
        updateData["searchable"] = userProfile.preferences.privacy.allowConnectionDiscovery

        try await db.collection(usersCollection)
            .document(userProfile.id)
            .updateData(updateData)
    }
    
    func updateLastActive(userId: String) async throws {
        try await db.collection(usersCollection)
            .document(userId)
            .updateData(["lastActiveAt": Timestamp(date: Date())])
    }
    
    func deleteUserProfile(userId: String) async throws {
        try await db.collection(usersCollection)
            .document(userId)
            .delete()
    }
    
    // MARK: - Connection Management
    
    func addConnection(userId: String, connectionId: String) async throws {
        try await db.collection(usersCollection)
            .document(userId)
            .updateData([
                "connectionIds": FieldValue.arrayUnion([connectionId])
            ])
    }
    
    func removeConnection(userId: String, connectionId: String) async throws {
        try await db.collection(usersCollection)
            .document(userId)
            .updateData([
                "connectionIds": FieldValue.arrayRemove([connectionId])
            ])
    }
    
    func getUserConnections(userId: String) async throws -> [UserProfile] {
        guard let userProfile = try await getUserProfile(userId: userId) else {
            return []
        }
        
        var connections: [UserProfile] = []
        
        for connectionId in userProfile.connectionIds {
            if let connection = try await getUserProfile(userId: connectionId) {
                connections.append(connection)
            }
        }
        
        return connections
    }
    
    // MARK: - Search and Discovery

    /// SECURITY: Search users with proper privacy settings enforcement
    /// Users can only be found if they've enabled connection discovery in their privacy settings
    func searchUsers(query: String, currentUserId: String) async throws -> [UserProfile] {
        let queryLower = query.lowercased()

        // SECURITY: Query using denormalized searchable field for performance
        // This field is synced with the nested preferences.privacy.allowConnectionDiscovery
        let documents = try await db.collection(usersCollection)
            .whereField("searchable", isEqualTo: true)
            .getDocuments()

        // Double-check privacy settings in the actual nested structure
        return documents.documents.compactMap { document in
            guard let profile = UserProfile(document: document),
                  profile.id != currentUserId,
                  // SECURITY: Verify the actual nested privacy setting
                  profile.preferences.privacy.allowConnectionDiscovery,
                  (profile.displayName.lowercased().contains(queryLower) ||
                   profile.email.lowercased().contains(queryLower))
            else { return nil }

            return profile
        }
    }
    
    func findUserByEmail(_ email: String) async throws -> UserProfile? {
        let query = try await db.collection(usersCollection)
            .whereField("email", isEqualTo: email)
            .getDocuments()
        
        return query.documents.compactMap { UserProfile(document: $0) }.first
    }
    
    // MARK: - Invitation Management
    
    func addPendingInvitation(userId: String, invitationCode: String) async throws {
        try await db.collection(usersCollection)
            .document(userId)
            .updateData([
                "pendingInvitations": FieldValue.arrayUnion([invitationCode])
            ])
    }
    
    func removePendingInvitation(userId: String, invitationCode: String) async throws {
        try await db.collection(usersCollection)
            .document(userId)
            .updateData([
                "pendingInvitations": FieldValue.arrayRemove([invitationCode])
            ])
    }
}
