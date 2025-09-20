import Foundation
import UserNotifications

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
    
    // Updated function to accept whose turn it might be
    func scheduleDailyNotification(atHour hour: Int, minute: Int, authorName: String?) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("Cannot schedule notification: Not authorized.")
                return
            }
            
            // Remove existing pending requests to avoid duplicates
            center.removeAllPendingNotificationRequests()
            
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true // Repeats daily at the specified time
            )
            
            let content = UNMutableNotificationContent()
            content.title = "Time for a Disney Daydream! ✨"
            
            // Customize body based on whose turn it is (if known)
            if let author = authorName {
                content.body = "It's \(author)'s turn to write today's Disney story. Tap to see the prompt!"
            } else {
                content.body = "Let's imagine a magical Disney moment! Tap to open WDW Daydreams."
            }
            
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "dailyDaydreamPrompt", // Use a unique identifier
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling daily notification: \(error.localizedDescription)")
                } else {
                    print("Daily notification scheduled successfully for \(hour):\(String(format: "%02d", minute)).")
                }
            }
        }
    }
    
    // Helper to update the notification when the app starts or author changes
    // You might call this from WDWDaydreamsApp init or when a new prompt is generated
    func updateScheduledNotification(basedOn manager: ScenarioManager) {
        let authorName = manager.currentStoryPrompt?.assignedAuthor.displayName
        // Schedule for 9:00 AM, for example
        scheduleDailyNotification(atHour: 9, minute: 0, authorName: authorName)
    }
    
    func sendLocalCompletionNotification(from author: String) {
        let content = UNMutableNotificationContent()
        content.title = "Story Complete! ✨"
        content.body = "\(author) finished writing today's Daydream! Your turn now!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing local completion notification: \(error.localizedDescription)")
            } else {
                print("Local notification triggered for completed story.")
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
