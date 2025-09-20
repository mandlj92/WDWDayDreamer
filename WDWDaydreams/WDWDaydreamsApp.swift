import SwiftUI
import FirebaseCore

@main
struct WDWDaydreamsApp: App {
    @StateObject private var authViewModel: AuthViewModel
    @StateObject var weatherManager = WDWWeatherManager()
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
                    AuthenticatedView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authViewModel)
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

// Separate view that only creates ScenarioManager AFTER authentication
struct AuthenticatedView: View {
    @StateObject private var manager = ScenarioManager()
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var weatherManager: WDWWeatherManager
    
    var body: some View {
        ContentView()
            .environmentObject(manager)
            .onAppear {
                print("🔐 ✅ User is authenticated, ScenarioManager can now safely initialize")
            }
    }
}
