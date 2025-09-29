import FirebaseFirestore
import Foundation

class UserService {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    // MARK: - User Profile Operations
    
    func createUserProfile(_ userProfile: UserProfile) async throws {
        try await db.collection(usersCollection)
            .document(userProfile.id)
            .setData(userProfile.dictionary)
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
    
    func searchUsers(query: String, currentUserId: String) async throws -> [UserProfile] {
        let queryLower = query.lowercased()
        
        let documents = try await db.collection(usersCollection)
            .whereField("allowConnectionDiscovery", isEqualTo: true)
            .getDocuments()
        
        return documents.documents.compactMap { document in
            guard let profile = UserProfile(document: document),
                  profile.id != currentUserId,
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
