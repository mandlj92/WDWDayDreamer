import Foundation
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

/// Manages FCM registration and queues semantic notification requests.
///
/// The client never reads another user's FCM token and never supplies notification
/// title/body text. Cloud Functions validate the relationship, resolve the target
/// token, and generate approved notification copy.
final class FCMService: NSObject, ObservableObject {
    static let shared = FCMService()

    private let db = Firestore.firestore()

    @Published var fcmToken: String?
    @Published var hasPermission = false

    private override init() {
        super.init()
        setupFCM()
    }

    // MARK: - Setup

    private func setupFCM() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        retrieveFCMToken()
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                if let error {
                    print("❌ FCM: Permission error: \(error.localizedDescription)")
                } else {
                    print(granted ? "🔔 FCM: Notification permission granted" : "ℹ️ FCM: Notification permission denied")
                }
            }
        }
    }

    // MARK: - Token management

    func retrieveFCMToken() {
        Messaging.messaging().token { [weak self] token, error in
            if let error {
                print("❌ FCM: Error fetching token: \(error.localizedDescription)")
                return
            }

            guard let token else {
                print("❌ FCM: No token received")
                return
            }

            DispatchQueue.main.async {
                self?.fcmToken = token
                self?.saveFCMToken(token)
            }
        }
    }

    private func saveFCMToken(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("ℹ️ FCM: Deferring token save until authentication")
            return
        }

        let tokenRef = db.collection("users")
            .document(userId)
            .collection("private")
            .document("notifications")

        tokenRef.setData([
            "fcmToken": token,
            "platform": "ios",
            "lastUpdated": FieldValue.serverTimestamp(),
            "tokenVersion": 1,
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error {
                print("❌ FCM: Error saving token: \(error.localizedDescription)")
            } else {
                print("✅ FCM: Token saved to private storage")
            }
        }
    }

    // MARK: - Notification requests

    func notifyPartnerOfStoryCompletion(
        authorName: String,
        storyPrompt: String,
        partnerUserId: String,
        partnershipId: String,
        storyDate: String
    ) {
        queueNotification(
            targetUserId: partnerUserId,
            type: "story_completed",
            partnershipId: partnershipId,
            storyId: storyDate
        )
    }

    func notifyPartnerOfNewPrompt(
        assignedAuthor: String,
        promptPreview: String,
        partnerUserId: String
    ) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ FCM: No authenticated user")
            return
        }

        let partnershipId = Self.partnershipId(userA: currentUserId, userB: partnerUserId)
        queueNotification(
            targetUserId: partnerUserId,
            type: "new_prompt",
            partnershipId: partnershipId,
            storyId: nil
        )
    }

    private func queueNotification(
        targetUserId: String,
        type: String,
        partnershipId: String,
        storyId: String?
    ) {
        guard let requesterId = Auth.auth().currentUser?.uid else {
            print("❌ FCM: No authenticated user to queue notification")
            return
        }

        guard targetUserId != requesterId else {
            print("❌ FCM: Refusing self-targeted notification")
            return
        }

        var request: [String: Any] = [
            "requesterId": requesterId,
            "targetUserId": targetUserId,
            "type": type,
            "partnershipId": partnershipId,
            "createdAt": Timestamp(date: Date()),
            "processed": false
        ]

        if let storyId, !storyId.isEmpty {
            request["storyId"] = storyId
        }

        db.collection("notificationQueue").addDocument(data: request) { error in
            if let error {
                print("❌ FCM: Error queuing notification: \(error.localizedDescription)")
            } else {
                print("✅ FCM: Semantic notification request queued")
            }
        }
    }

    private static func partnershipId(userA: String, userB: String) -> String {
        userA < userB ? "\(userA)_\(userB)" : "\(userB)_\(userA)"
    }

    // MARK: - Incoming notifications

    func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else {
            print("❌ FCM: Notification type missing")
            return
        }

        switch type {
        case "story_completed":
            handleStoryCompletedNotification(userInfo)
        case "new_prompt":
            handleNewPromptNotification(userInfo)
        case "daily_reminder":
            handleDailyReminderNotification(userInfo)
        case "moderation_review":
            NotificationCenter.default.post(
                name: NSNotification.Name("ModerationReviewReceived"),
                object: nil,
                userInfo: userInfo
            )
        default:
            print("❌ FCM: Unknown notification type: \(type)")
        }
    }

    private func handleStoryCompletedNotification(_ userInfo: [AnyHashable: Any]) {
        let authorName = userInfo["authorName"] as? String
            ?? userInfo["author"] as? String
            ?? "Your partner"

        DispatchQueue.main.async {
            HapticManager.instance.notification(type: .success)
            NotificationManager.shared.sendLocalCompletionNotification(from: authorName)
            NotificationCenter.default.post(
                name: NSNotification.Name("StoryCompletedRemotely"),
                object: nil,
                userInfo: userInfo
            )
        }
    }

    private func handleNewPromptNotification(_ userInfo: [AnyHashable: Any]) {
        DispatchQueue.main.async {
            HapticManager.instance.notification(type: .success)
            NotificationCenter.default.post(
                name: NSNotification.Name("NewPromptAvailable"),
                object: nil,
                userInfo: userInfo
            )
        }
    }

    private func handleDailyReminderNotification(_ userInfo: [AnyHashable: Any]) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("DailyReminderReceived"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
}

// MARK: - MessagingDelegate

extension FCMService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        DispatchQueue.main.async {
            self.fcmToken = fcmToken
            if let fcmToken {
                self.saveFCMToken(fcmToken)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension FCMService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handleNotificationPayload(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationPayload(response.notification.request.content.userInfo)
        completionHandler()
    }
}
