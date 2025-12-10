import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseRemoteConfig
import FirebaseMessaging
import GoogleSignIn
import FirebaseAuth
import FirebaseAppCheck
import UserNotifications

// Enhanced App Check provider with better security
class YourAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        // Debug mode: Use debug provider for testing
        print("⚠️ Using AppCheckDebugProvider - DEBUG MODE ONLY")
        return AppCheckDebugProvider(app: app)
        #else
        // Production: Use AppAttest for iOS 14+, fallback to DeviceCheck
        if #available(iOS 14.0, *) {
            print("✅ Using AppAttestProvider for App Check")
            return AppAttestProvider(app: app)
        } else {
            print("✅ Using DeviceCheckProvider for App Check")
            return DeviceCheckProvider(app: app)
        }
        #endif
    }
}

@main
struct WDWDaydreamsApp: App {
    @StateObject private var authViewModel: AuthViewModel
    @StateObject var themeManager = ThemeManager()
    @StateObject var fcmService = FCMService.shared
    @StateObject var feedbackCenter: UIFeedbackCenter
    let notificationManager = NotificationManager.shared
    
    // Create a UIApplicationDelegateAdaptor for handling push notifications
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        AppCheck.setAppCheckProviderFactory(YourAppCheckProviderFactory())
        FirebaseApp.configure()

        // Enable Firestore offline persistence with security hardening
        let settings = Firestore.firestore().settings
        if #available(iOS 15.0, *) {
            // Modern cache settings for iOS 15+ with reduced size for security
            settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 10 * 1024 * 1024)) // 10MB (reduced from 50MB)
        } else {
            // Fallback for older iOS versions
            settings.isPersistenceEnabled = true
            settings.cacheSizeBytes = 10 * 1024 * 1024 // 10MB (reduced from 50MB)
        }
        Firestore.firestore().settings = settings
        print("✅ Firestore offline persistence enabled with 10MB cache (security hardened)")

        // Apply file protection to Firestore cache directory
        Self.applyFileLevelEncryption()

        Self.configureRemoteConfig()
        Self.configureGoogleSignIn()

        _authViewModel = StateObject(wrappedValue: AuthViewModel())
        _feedbackCenter = StateObject(wrappedValue: UIFeedbackCenter.shared)

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
        remoteConfig.setDefaults([:])
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

    /// Apply file-level encryption to Firestore cache directory
    /// Uses iOS Data Protection API to encrypt cache at rest
    private static func applyFileLevelEncryption() {
        // Get Firestore cache directory path
        guard let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            print("⚠️ Failed to locate Library directory for cache protection")
            return
        }

        // Firestore stores cache in Library/Application Support/firestore
        let firestoreCachePath = libraryPath
            .appendingPathComponent("Application Support")
            .appendingPathComponent("firestore")

        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: firestoreCachePath, withIntermediateDirectories: true)

            // Apply Data Protection: .completeUnlessOpen
            // This ensures data is encrypted when device is locked
            // but allows Firestore to access cache when app is in use
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUnlessOpen],
                ofItemAtPath: firestoreCachePath.path
            )

            print("✅ File-level encryption applied to Firestore cache (.completeUnlessOpen)")
        } catch {
            print("⚠️ Failed to apply file-level encryption to Firestore cache: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .environmentObject(fcmService)
                .environmentObject(feedbackCenter)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

// MARK: - Main App View (handles scene phase)
struct MainAppView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var fcmService: FCMService
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if authViewModel.requiresOnboarding {
                    OnboardingView()
                        .environmentObject(authViewModel)
                } else {
                    AuthenticatedView()
                }
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

                // Clear notification badge when app becomes active
                NotificationManager.shared.clearBadge()

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
