import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    let avatarURL: String?
    let bio: String?
    let createdAt: Date
    let lastActiveAt: Date
    let connectionIds: [String] // Array of connected user IDs
    let pendingInvitations: [String] // Invitation codes they've sent
    let achievements: [String]
    let preferences: UserPreferences
    
    // Firestore document representation
    var dictionary: [String: Any] {
        return [
            "id": id,
            "email": email,
            "displayName": displayName,
            "avatarURL": avatarURL as Any,
            "bio": bio as Any,
            "createdAt": Timestamp(date: createdAt),
            "lastActiveAt": Timestamp(date: lastActiveAt),
            "connectionIds": connectionIds,
            "pendingInvitations": pendingInvitations,
            "achievements": achievements,
            "preferences": preferences.dictionary
        ]
    }
    
    // Initialize from Firestore document
    init?(document: DocumentSnapshot) {
          guard let data = document.data(),
              let id = data["id"] as? String,
              let email = data["email"] as? String,
              let displayName = data["displayName"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let lastActiveAtTimestamp = data["lastActiveAt"] as? Timestamp,
              let connectionIds = data["connectionIds"] as? [String],
              let pendingInvitations = data["pendingInvitations"] as? [String],
              let preferencesData = data["preferences"] as? [String: Any]
        else { return nil }
        
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarURL = data["avatarURL"] as? String
        self.bio = data["bio"] as? String
        self.createdAt = createdAtTimestamp.dateValue()
        self.lastActiveAt = lastActiveAtTimestamp.dateValue()
        self.connectionIds = connectionIds
        self.pendingInvitations = pendingInvitations
        self.achievements = data["achievements"] as? [String] ?? []
        self.preferences = UserPreferences(dictionary: preferencesData) ?? UserPreferences()
    }
    
    // Manual initializer for creating new profiles
    init(id: String, email: String, displayName: String, avatarURL: String? = nil, bio: String? = nil, createdAt: Date = Date(), connectionIds: [String] = [], pendingInvitations: [String] = [], achievements: [String] = [], preferences: UserPreferences = UserPreferences()) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.bio = bio
        self.createdAt = createdAt
        self.lastActiveAt = Date()
        self.connectionIds = connectionIds
        self.pendingInvitations = pendingInvitations
        self.achievements = achievements
        self.preferences = preferences
    }
    
    // Helper computed properties
    var hasConnections: Bool { !connectionIds.isEmpty }
    var connectionCount: Int { connectionIds.count }
    var hasPendingInvitations: Bool { !pendingInvitations.isEmpty }
}

struct UserPreferences: Codable {
    let notifications: NotificationPreferences
    let privacy: PrivacySettings
    let storyCategories: [String]
    let tripDate: Date?
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "notifications": notifications.dictionary,
            "privacy": privacy.dictionary,
            "storyCategories": storyCategories
        ]
        if let tripDate = tripDate {
            dict["tripDate"] = Timestamp(date: tripDate)
        }
        return dict
    }
    
    init(notifications: NotificationPreferences = NotificationPreferences(), privacy: PrivacySettings = PrivacySettings(), storyCategories: [String] = ["park", "ride", "food"], tripDate: Date? = nil) {
        self.notifications = notifications
        self.privacy = privacy
        self.storyCategories = storyCategories
        self.tripDate = tripDate
    }
    
    init?(dictionary: [String: Any]) {
        guard let notificationsData = dictionary["notifications"] as? [String: Any],
              let privacyData = dictionary["privacy"] as? [String: Any],
              let storyCategories = dictionary["storyCategories"] as? [String],
              let notifications = NotificationPreferences(dictionary: notificationsData),
              let privacy = PrivacySettings(dictionary: privacyData)
        else { return nil }
        
        self.notifications = notifications
        self.privacy = privacy
        self.storyCategories = storyCategories
        
        if let tripDateTimestamp = dictionary["tripDate"] as? Timestamp {
            self.tripDate = tripDateTimestamp.dateValue()
        } else {
            self.tripDate = nil
        }
    }
}

struct NotificationPreferences: Codable {
    let storyReminders: Bool
    let connectionRequests: Bool
    let newStoryNotifications: Bool
    let weeklyDigest: Bool
    
    var dictionary: [String: Any] {
        return [
            "storyReminders": storyReminders,
            "connectionRequests": connectionRequests,
            "newStoryNotifications": newStoryNotifications,
            "weeklyDigest": weeklyDigest
        ]
    }
    
    init(storyReminders: Bool = true, connectionRequests: Bool = true, newStoryNotifications: Bool = true, weeklyDigest: Bool = false) {
        self.storyReminders = storyReminders
        self.connectionRequests = connectionRequests
        self.newStoryNotifications = newStoryNotifications
        self.weeklyDigest = weeklyDigest
    }
    
    init?(dictionary: [String: Any]) {
        guard let storyReminders = dictionary["storyReminders"] as? Bool,
              let connectionRequests = dictionary["connectionRequests"] as? Bool,
              let newStoryNotifications = dictionary["newStoryNotifications"] as? Bool,
              let weeklyDigest = dictionary["weeklyDigest"] as? Bool
        else { return nil }
        
        self.storyReminders = storyReminders
        self.connectionRequests = connectionRequests
        self.newStoryNotifications = newStoryNotifications
        self.weeklyDigest = weeklyDigest
    }
}

struct PrivacySettings: Codable {
    let profileVisibility: ProfileVisibility
    let allowStorySharing: Bool
    let allowConnectionDiscovery: Bool
    
    var dictionary: [String: Any] {
        return [
            "profileVisibility": profileVisibility.rawValue,
            "allowStorySharing": allowStorySharing,
            "allowConnectionDiscovery": allowConnectionDiscovery
        ]
    }
    
    init(profileVisibility: ProfileVisibility = .connectionsOnly, allowStorySharing: Bool = true, allowConnectionDiscovery: Bool = true) {
        self.profileVisibility = profileVisibility
        self.allowStorySharing = allowStorySharing
        self.allowConnectionDiscovery = allowConnectionDiscovery
    }
    
    init?(dictionary: [String: Any]) {
        guard let profileVisibilityRaw = dictionary["profileVisibility"] as? String,
              let profileVisibility = ProfileVisibility(rawValue: profileVisibilityRaw),
              let allowStorySharing = dictionary["allowStorySharing"] as? Bool,
              let allowConnectionDiscovery = dictionary["allowConnectionDiscovery"] as? Bool
        else { return nil }
        
        self.profileVisibility = profileVisibility
        self.allowStorySharing = allowStorySharing
        self.allowConnectionDiscovery = allowConnectionDiscovery
    }
}

enum ProfileVisibility: String, Codable, CaseIterable {
    case everyone = "everyone"
    case connectionsOnly = "connectionsOnly"
    case privateOnly = "private"
    
    var displayName: String {
        switch self {
        case .everyone: return "Everyone"
        case .connectionsOnly: return "Story Partners Only"
        case .privateOnly: return "Private"
        }
    }
}
