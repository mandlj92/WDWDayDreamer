import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else {
                print("Notification permission denied.")
            }
        }
    }
    
    // Clear badge count when app becomes active (iOS 17+ compatible)
    func clearBadge() {
        DispatchQueue.main.async {
            if #available(iOS 16.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(0) { error in
                    if let error = error {
                        print("Error clearing badge: \(error.localizedDescription)")
                    }
                }
            } else {
                // Fallback for older iOS versions
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }
    
    // Local notification for when partner completes story (triggered by FCM or locally)
    func sendLocalCompletionNotification(from author: String) {
        let content = UNMutableNotificationContent()
        content.title = "New Disney Story! ✨"
        content.body = "\(author) just wrote a magical Disney Daydream! Check it out!"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "story_completion_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing local completion notification: \(error.localizedDescription)")
            } else {
                print("Local notification triggered for completed story by \(author)")
            }
        }
    }
    
    // Handle notification display when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Clear badge when user taps notification
        clearBadge()
        
        // Handle what happens when user taps notification
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String {
            switch type {
            case "story_completed":
                // Maybe navigate to the completed story or refresh data
                NotificationCenter.default.post(
                    name: NSNotification.Name("StoryCompletedTapped"),
                    object: nil,
                    userInfo: userInfo
                )
            default:
                break
            }
        }
        
        completionHandler()
    }
}
