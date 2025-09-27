import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseRemoteConfig
import FirebaseMessaging
import GoogleSignIn
import FirebaseAuth
import FirebaseAppCheck
import UserNotifications

// Custom class to provide a debug App Check provider
class YourAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    #if DEBUG
      return AppCheckDebugProvider(app: app)
    #else
      return AppAttestProvider(app: app)
    #endif
  }
}

@main
struct WDWDaydreamsApp: App {
    @StateObject private var authViewModel: AuthViewModel
    @StateObject var weatherManager = WDWWeatherManager()
    @StateObject var themeManager = ThemeManager()
    @StateObject var fcmService = FCMService.shared
    let notificationManager = NotificationManager.shared
    
    // Create a UIApplicationDelegateAdaptor for handling push notifications
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        AppCheck.setAppCheckProviderFactory(YourAppCheckProviderFactory())
        FirebaseApp.configure()
        
        // Enable Firestore offline persistence
        do {
            let settings = Firestore.firestore().settings
            settings.isPersistenceEnabled = true
            settings.cacheSizeBytes = 50 * 1024 * 1024 // 50MB cache
            Firestore.firestore().settings = settings
            print("✅ Firestore offline persistence enabled with 50MB cache")
        } catch {
            print("❌ Failed to enable Firestore offline persistence: \(error.localizedDescription)")
        }
        
        Self.configureRemoteConfig()
        Self.configureGoogleSignIn()
        
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
        
        NotificationManager.shared.requestPermission()
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }

    private static func configureRemoteConfig() {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
        let defaults: [String: NSObject] = ["weather_api_key": "" as NSString]
        remoteConfig.setDefaults(defaults)
        print("✅ Remote Config initialized")
    }
    
    private static func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ CLIENT_ID not found in GoogleService-Info.plist")
            return
        }
        print("✅ Configuring Google Sign-In with CLIENT_ID: \(clientId)")
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(authViewModel)
                .environmentObject(weatherManager)
                .environmentObject(themeManager)
                .environmentObject(fcmService)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

// MARK: - Main App View (handles scene phase)
struct MainAppView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var weatherManager: WDWWeatherManager
    @EnvironmentObject var fcmService: FCMService
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                AuthenticatedView()
            } else {
                LoginView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StoryCompletedRemotely"))) { notification in
            // Handle story completion notification
            print("🔔 App: Received story completion notification")
            // You can trigger UI updates or data refresh here
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewPromptAvailable"))) { notification in
            // Handle new prompt notification
            print("🔔 App: Received new prompt notification")
            // You can trigger UI updates or data refresh here
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                print("App became active.")
                weatherManager.fetchWeather()
                // Refresh FCM token when app becomes active
                fcmService.retrieveFCMToken()
            }
        }
    }
}

// MARK: - App Delegate for Push Notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("✅ AppDelegate: Application did finish launching")
        
        // Set messaging delegate
        Messaging.messaging().delegate = FCMService.shared
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("✅ AppDelegate: Successfully registered for remote notifications")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ AppDelegate: Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("🔔 AppDelegate: Received remote notification: \(userInfo)")
        
        // Handle the notification payload
        FCMService.shared.handleNotificationPayload(userInfo)
        
        completionHandler(.newData)
    }
}

struct AuthenticatedView: View {
    @StateObject private var manager = ScenarioManager()
    
    var body: some View {
        ContentView()
            .environmentObject(manager)
    }
}
