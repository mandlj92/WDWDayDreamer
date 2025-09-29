import Foundation
import FirebaseFirestore

// MARK: - Connection Invitation Model

struct PalInvitation: Codable, Identifiable {
    let id: String
    let fromUserId: String
    let fromUserName: String
    let fromUserEmail: String
    let toUserId: String?
    let invitationCode: String
    let status: InvitationStatus
    let createdAt: Date
    let expiresAt: Date

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "fromUserId": fromUserId,
            "fromUserName": fromUserName,
            "fromUserEmail": fromUserEmail,
            "invitationCode": invitationCode,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "expiresAt": Timestamp(date: expiresAt)
        ]
        if let toUserId = toUserId {
            dict["toUserId"] = toUserId
        }
        return dict
    }

    init(id: String = UUID().uuidString,
         fromUserId: String,
         fromUserName: String,
         fromUserEmail: String,
         toUserId: String? = nil,
         invitationCode: String,
         status: InvitationStatus = .pending,
         createdAt: Date = Date(),
         expiresAt: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!) {
        self.id = id
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.fromUserEmail = fromUserEmail
        self.toUserId = toUserId
        self.invitationCode = invitationCode
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let fromUserId = data["fromUserId"] as? String,
              let fromUserName = data["fromUserName"] as? String,
              let fromUserEmail = data["fromUserEmail"] as? String,
              let invitationCode = data["invitationCode"] as? String,
              let statusRaw = data["status"] as? String,
              let status = InvitationStatus(rawValue: statusRaw),
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let expiresAtTimestamp = data["expiresAt"] as? Timestamp
        else { return nil }

        self.id = document.documentID
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.fromUserEmail = fromUserEmail
        self.toUserId = data["toUserId"] as? String
        self.invitationCode = invitationCode
        self.status = status
        self.createdAt = createdAtTimestamp.dateValue()
        self.expiresAt = expiresAtTimestamp.dateValue()
    }

    var isExpired: Bool {
        return Date() > expiresAt
    }
}

enum InvitationStatus: String, Codable {
    case pending
    case accepted
    case declined
    case expired
}

// MARK: - Story Partnership Model

struct StoryPartnership: Codable, Identifiable {
    let id: String
    let user1Id: String
    let user2Id: String
    let createdAt: Date
    var lastStoryDate: Date?
    var nextAuthorId: String?
    var enabledCategories: [String]
    var sharedTripDate: Date?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "user1Id": user1Id,
            "user2Id": user2Id,
            "createdAt": Timestamp(date: createdAt),
            "enabledCategories": enabledCategories
        ]
        if let lastStoryDate = lastStoryDate {
            dict["lastStoryDate"] = Timestamp(date: lastStoryDate)
        }
        if let nextAuthorId = nextAuthorId {
            dict["nextAuthorId"] = nextAuthorId
        }
        if let sharedTripDate = sharedTripDate {
            dict["sharedTripDate"] = Timestamp(date: sharedTripDate)
        }
        return dict
    }

    init(id: String = UUID().uuidString,
         user1Id: String,
         user2Id: String,
         createdAt: Date = Date(),
         lastStoryDate: Date? = nil,
         nextAuthorId: String? = nil,
         enabledCategories: [String] = ["park", "ride", "food"],
         sharedTripDate: Date? = nil) {
        self.id = id
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.createdAt = createdAt
        self.lastStoryDate = lastStoryDate
        self.nextAuthorId = nextAuthorId
        self.enabledCategories = enabledCategories
        self.sharedTripDate = sharedTripDate
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let user1Id = data["user1Id"] as? String,
              let user2Id = data["user2Id"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let enabledCategories = data["enabledCategories"] as? [String]
        else { return nil }

        self.id = document.documentID
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.createdAt = createdAtTimestamp.dateValue()
        self.enabledCategories = enabledCategories

        if let lastStoryDateTimestamp = data["lastStoryDate"] as? Timestamp {
            self.lastStoryDate = lastStoryDateTimestamp.dateValue()
        }

        self.nextAuthorId = data["nextAuthorId"] as? String

        if let sharedTripDateTimestamp = data["sharedTripDate"] as? Timestamp {
            self.sharedTripDate = sharedTripDateTimestamp.dateValue()
        }
    }

    func getPartnerId(for userId: String) -> String? {
        if user1Id == userId {
            return user2Id
        } else if user2Id == userId {
            return user1Id
        }
        return nil
    }
}
