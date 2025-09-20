import SwiftUI
import FirebaseCore

@main
struct WDWDaydreamsApp: App {
    @StateObject var manager = ScenarioManager()
    @StateObject var weatherManager = WDWWeatherManager() // Add weather manager
    let notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        print("=== Loaded fonts ===")
        for family in UIFont.familyNames.sorted() {
            for name in UIFont.fontNames(forFamilyName: family) {
                print(name)
            }
        }

        // Initialize Firebase
        FirebaseApp.configure()
        
        // Initialize notifications
        NotificationManager.shared.requestPermission()
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            LoginView()
                .environmentObject(manager)
                .environmentObject(weatherManager) // Add weather manager to environment
                .onAppear {
                    // We'll handle prompt generation after login in ContentView
                    // to ensure user is authenticated first
                }
        }
        // --- Updated onChange syntax ---
        .onChange(of: scenePhase) { oldPhase, newPhase in
             if newPhase == .background {
                 print("App entered background.")
             } else if newPhase == .active {
                 print("App became active.")
                 weatherManager.fetchWeather() // Fetch weather when app becomes active
             }
         }
        // --- End of update ---
    }
}
