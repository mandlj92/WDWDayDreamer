//
//  FCMService.swift
//  WDWDaydreams
//
//  Created by Jonathan Mandl on 9/21/25.
//

// Services/FCMService.swift
import Foundation
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

class FCMService: NSObject, ObservableObject {
    static let shared = FCMService()
    
    private let db = Firestore.firestore()
    @Published var fcmToken: String?
    @Published var hasPermission: Bool = false
    
    private override init() {
        super.init()
        setupFCM()
    }
    
    // MARK: - Setup and Configuration
    
    private func setupFCM() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        requestNotificationPermission()
        
        // Get initial token
        retrieveFCMToken()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                
                if granted {
                    print("🔔 FCM: Notification permission granted")
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                } else {
                    print("❌ FCM: Notification permission denied")
                    if let error = error {
                        print("❌ FCM: Permission error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Token Management
    
    func retrieveFCMToken() {
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("❌ FCM: Error fetching token: \(error.localizedDescription)")
                return
            }
            
            guard let token = token else {
                print("❌ FCM: No token received")
                return
            }
            
            print("✅ FCM: Token retrieved: \(token.prefix(20))...")
            
            DispatchQueue.main.async {
                self?.fcmToken = token
                self?.saveFCMToken(token)
            }
        }
    }
    
    private func saveFCMToken(_ token: String) {
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ FCM: No authenticated user to save token for")
            return
        }
        
        let userId = currentUser.uid
        let userRef = db.collection("users").document(userId)
        
        let tokenData: [String: Any] = [
            "fcmToken": token,
            "platform": "ios",
            "lastUpdated": Timestamp(date: Date()),
            "email": currentUser.email ?? ""
        ]
        
        userRef.setData(tokenData, merge: true) { error in
            if let error = error {
                print("❌ FCM: Error saving token to Firestore: \(error.localizedDescription)")
            } else {
                print("✅ FCM: Token saved to Firestore successfully")
            }
        }
    }
    
    // MARK: - Partner Token Retrieval
    
    func getPartnerFCMToken(completion: @escaping (String?) -> Void) {
        guard Auth.auth().currentUser != nil else {
            completion(nil)
            return
        }
        
        // Get all users to find the partner (the other user)
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("❌ FCM: Error fetching users: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(nil)
                return
            }
            
            // Find the partner (not the current user)
            let currentUserId = Auth.auth().currentUser?.uid ?? ""
            
            for document in documents {
                if document.documentID != currentUserId {
                    let token = document.data()["fcmToken"] as? String
                    print("✅ FCM: Found partner token: \(token?.prefix(20) ?? "nil")...")
                    completion(token)
                    return
                }
            }
            
            print("❌ FCM: No partner found")
            completion(nil)
        }
    }
    
    // MARK: - Send Notifications
    
    func notifyPartnerOfStoryCompletion(authorName: String, storyPrompt: String) {
        getPartnerFCMToken { [weak self] partnerToken in
            guard let partnerToken = partnerToken else {
                print("❌ FCM: No partner token available for notification")
                return
            }
            
            self?.sendPushNotification(
                to: partnerToken,
                title: "Story Complete! ✨",
                body: "\(authorName) just finished their Disney Daydream! Your turn now!",
                data: [
                    "type": "story_completed",
                    "author": authorName,
                    "prompt": storyPrompt
                ]
            )
        }
    }
    
    func notifyPartnerOfNewPrompt(assignedAuthor: String, promptPreview: String) {
        getPartnerFCMToken { [weak self] partnerToken in
            guard let partnerToken = partnerToken else {
                print("❌ FCM: No partner token available for notification")
                return
            }
            
            let title = "New Disney Daydream! ✨"
            let body = "It's \(assignedAuthor)'s turn to write today's story!"
            
            self?.sendPushNotification(
                to: partnerToken,
                title: title,
                body: body,
                data: [
                    "type": "new_prompt",
                    "assigned_author": assignedAuthor,
                    "prompt_preview": promptPreview
                ]
            )
        }
    }
    
    private func sendPushNotification(to token: String, title: String, body: String, data: [String: String] = [:]) {
        // This will be handled by Cloud Functions
        // For now, we'll save the notification request to Firestore
        // and let Cloud Functions pick it up and send it
        
        let notificationData: [String: Any] = [
            "targetToken": token,
            "title": title,
            "body": body,
            "data": data,
            "timestamp": Timestamp(date: Date()),
            "processed": false
        ]
        
        db.collection("notificationQueue").addDocument(data: notificationData) { error in
            if let error = error {
                print("❌ FCM: Error queuing notification: \(error.localizedDescription)")
            } else {
                print("✅ FCM: Notification queued for Cloud Functions processing")
            }
        }
    }
    
    // MARK: - Handle Incoming Notifications
    
    func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        print("🔔 FCM: Received notification payload: \(userInfo)")
        
        guard let type = userInfo["type"] as? String else {
            print("❌ FCM: No notification type found")
            return
        }
        
        switch type {
        case "story_completed":
            handleStoryCompletedNotification(userInfo)
        case "new_prompt":
            handleNewPromptNotification(userInfo)
        case "daily_reminder":
            handleDailyReminderNotification(userInfo)
        default:
            print("❌ FCM: Unknown notification type: \(type)")
        }
    }
    
    private func handleStoryCompletedNotification(_ userInfo: [AnyHashable: Any]) {
        let authorName = userInfo["author"] as? String ?? "Your partner"
        
        DispatchQueue.main.async {
            // Trigger haptic feedback
            HapticManager.instance.notification(type: .success)
            
            // Show local notification if app is active
            NotificationManager.shared.sendLocalCompletionNotification(from: authorName)
            
            // Post notification for the app to refresh data
            NotificationCenter.default.post(
                name: NSNotification.Name("StoryCompletedRemotely"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    private func handleNewPromptNotification(_ userInfo: [AnyHashable: Any]) {
        DispatchQueue.main.async {
            // Trigger haptic feedback
            HapticManager.instance.notification(type: .success)
            
            // Post notification for the app to refresh data
            NotificationCenter.default.post(
                name: NSNotification.Name("NewPromptAvailable"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    private func handleDailyReminderNotification(_ userInfo: [AnyHashable: Any]) {
        DispatchQueue.main.async {
            // Post notification for the app to handle daily reminder
            NotificationCenter.default.post(
                name: NSNotification.Name("DailyReminderReceived"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
}

// MARK: - Messaging Delegate
extension FCMService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("✅ FCM: Registration token updated: \(fcmToken?.prefix(20) ?? "nil")...")
        
        DispatchQueue.main.async {
            self.fcmToken = fcmToken
            if let token = fcmToken {
                self.saveFCMToken(token)
            }
        }
    }
}

// MARK: - Notification Center Delegate
extension FCMService: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        handleNotificationPayload(userInfo)
        
        // Show the notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationPayload(userInfo)
        
        completionHandler()
    }
}
