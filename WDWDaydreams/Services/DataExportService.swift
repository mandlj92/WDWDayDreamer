//
//  DataExportService.swift
//  WDWDaydreams
//
//  Created on 12/5/2025.
//

import Foundation
import FirebaseFirestore

struct UserDataExport: Codable {
    let exportDate: String
    let userProfile: ExportableUserProfile
    let stories: [ExportableStory]
    let partnerships: [ExportablePartnership]
    let settings: ExportableSettings

    struct ExportableUserProfile: Codable {
        let id: String
        let email: String
        let displayName: String
        let avatarURL: String?
        let bio: String?
        let createdAt: String
        let lastActiveAt: String
        let connectionIds: [String]
    }

    struct ExportableStory: Codable {
        let id: String
        let userId: String
        let partnershipId: String?
        let category: String
        let prompt: String
        let response: String
        let completedAt: String
        let isFavorite: Bool
    }

    struct ExportablePartnership: Codable {
        let id: String
        let user1Id: String
        let user2Id: String
        let createdAt: String
        let partnerDisplayName: String?
    }

    struct ExportableSettings: Codable {
        let profileVisibility: String
        let allowStorySharing: Bool
        let allowConnectionDiscovery: Bool
        let storyReminders: Bool
        let connectionRequests: Bool
        let newStoryNotifications: Bool
        let weeklyDigest: Bool
    }
}

class DataExportService {
    private let db = Firestore.firestore()

    func exportUserData(userId: String) async throws -> UserDataExport {
        // Fetch user profile
        guard let userDoc = try? await db.collection("users").document(userId).getDocument(),
              let userProfile = UserProfile(document: userDoc) else {
            throw NSError(domain: "DataExportService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }

        // Fetch user stories from subcollections
        var stories: [UserDataExport.ExportableStory] = []

        // Fetch favorites
        let favoritesSnapshot = try await db.collection("userStories")
            .document(userId)
            .collection("favorites")
            .getDocuments()

        // Fetch history
        let historySnapshot = try await db.collection("userStories")
            .document(userId)
            .collection("history")
            .getDocuments()

        // Process all story documents
        for doc in favoritesSnapshot.documents + historySnapshot.documents {
            let data = doc.data()
            if let dateTimestamp = data["date"] as? Timestamp,
               let promptDict = data["prompt"] as? [String: String] {

                let prompt = promptDict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                let response = data["text"] as? String ?? ""
                let partnershipId = data["partnershipId"] as? String
                let isFavorite = favoritesSnapshot.documents.contains(where: { $0.documentID == doc.documentID })

                stories.append(UserDataExport.ExportableStory(
                    id: doc.documentID,
                    userId: userId,
                    partnershipId: partnershipId,
                    category: "Mixed", // Stories contain multiple categories
                    prompt: prompt,
                    response: response,
                    completedAt: ISO8601DateFormatter().string(from: dateTimestamp.dateValue()),
                    isFavorite: isFavorite
                ))
            }
        }

        // Fetch partnerships
        let partnershipsSnapshot1 = try await db.collection("partnerships")
            .whereField("user1Id", isEqualTo: userId)
            .getDocuments()

        let partnershipsSnapshot2 = try await db.collection("partnerships")
            .whereField("user2Id", isEqualTo: userId)
            .getDocuments()

        var partnerships: [UserDataExport.ExportablePartnership] = []

        for doc in partnershipsSnapshot1.documents + partnershipsSnapshot2.documents {
            if let partnership = try? doc.data(as: StoryPartnership.self) {
                let partnerId = partnership.user1Id == userId ? partnership.user2Id : partnership.user1Id
                let partnerDoc = try? await db.collection("users").document(partnerId).getDocument()
                let partnerName = partnerDoc?.data()?["displayName"] as? String

                partnerships.append(UserDataExport.ExportablePartnership(
                    id: doc.documentID,
                    user1Id: partnership.user1Id,
                    user2Id: partnership.user2Id,
                    createdAt: ISO8601DateFormatter().string(from: partnership.createdAt),
                    partnerDisplayName: partnerName
                ))
            }
        }

        // Fetch user settings
        let settingsDoc = try? await db.collection("userSettings").document(userId).getDocument()
        let settingsData = settingsDoc?.data() ?? [:]

        let settings = UserDataExport.ExportableSettings(
            profileVisibility: settingsData["profileVisibility"] as? String ?? "everyone",
            allowStorySharing: settingsData["allowStorySharing"] as? Bool ?? true,
            allowConnectionDiscovery: settingsData["allowConnectionDiscovery"] as? Bool ?? true,
            storyReminders: settingsData["storyReminders"] as? Bool ?? true,
            connectionRequests: settingsData["connectionRequests"] as? Bool ?? true,
            newStoryNotifications: settingsData["newStoryNotifications"] as? Bool ?? true,
            weeklyDigest: settingsData["weeklyDigest"] as? Bool ?? false
        )

        // Create export
        return UserDataExport(
            exportDate: ISO8601DateFormatter().string(from: Date()),
            userProfile: UserDataExport.ExportableUserProfile(
                id: userProfile.id,
                email: userProfile.email,
                displayName: userProfile.displayName,
                avatarURL: userProfile.avatarURL,
                bio: userProfile.bio,
                createdAt: ISO8601DateFormatter().string(from: userProfile.createdAt),
                lastActiveAt: ISO8601DateFormatter().string(from: userProfile.lastActiveAt),
                connectionIds: userProfile.connectionIds
            ),
            stories: stories,
            partnerships: partnerships,
            settings: settings
        )
    }

    func generateJSONFile(export: UserDataExport) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(export)

        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "WDWDaydreams_UserData_\(Date().timeIntervalSince1970).json"
        let fileURL = tempDir.appendingPathComponent(filename)

        try jsonData.write(to: fileURL)

        return fileURL
    }

    func deleteUserData(userId: String) async throws {
        // Delete user profile
        try await db.collection("users").document(userId).delete()

        // Delete user stories (favorites and history subcollections)
        let favoritesSnapshot = try await db.collection("userStories")
            .document(userId)
            .collection("favorites")
            .getDocuments()

        for doc in favoritesSnapshot.documents {
            try await doc.reference.delete()
        }

        let historySnapshot = try await db.collection("userStories")
            .document(userId)
            .collection("history")
            .getDocuments()

        for doc in historySnapshot.documents {
            try await doc.reference.delete()
        }

        // Delete the userStories document itself
        try await db.collection("userStories").document(userId).delete()

        // Delete user settings
        try await db.collection("userSettings").document(userId).delete()

        // Remove user from partnerships
        let partnerships1 = try await db.collection("partnerships")
            .whereField("user1Id", isEqualTo: userId)
            .getDocuments()

        let partnerships2 = try await db.collection("partnerships")
            .whereField("user2Id", isEqualTo: userId)
            .getDocuments()

        for doc in partnerships1.documents + partnerships2.documents {
            try await doc.reference.delete()
        }

        // Delete invitations
        let invitations = try await db.collection("palInvitations")
            .whereField("fromUserId", isEqualTo: userId)
            .getDocuments()

        for doc in invitations.documents {
            try await doc.reference.delete()
        }

        // Note: Firebase Authentication deletion must be handled separately
        // via Auth.auth().currentUser?.delete()
    }
}
