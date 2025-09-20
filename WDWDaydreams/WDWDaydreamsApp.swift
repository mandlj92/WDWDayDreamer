import SwiftUI
import FirebaseCore

@main
struct WDWDaydreamsApp: App {
    @StateObject var manager = ScenarioManager()
    @StateObject var weatherManager = WDWWeatherManager()
    @StateObject private var authViewModel: AuthViewModel
    let notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) var scenePhase

    init() {
        print("=== Loaded fonts ===")
        for family in UIFont.familyNames.sorted() {
            for name in UIFont.fontNames(forFamilyName: family) {
                print(name)
            }
        }

        FirebaseApp.configure()
        _authViewModel = StateObject(wrappedValue: AuthViewModel())

        NotificationManager.shared.requestPermission()
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(manager)
            .environmentObject(weatherManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                print("App entered background.")
            } else if newPhase == .active {
                print("App became active.")
                weatherManager.fetchWeather()
            }
        }
    }
}
