import SwiftUI
import FirebaseCore
import FirebaseRemoteConfig
import GoogleSignIn
import FirebaseAuth
import FirebaseAppCheck // <-- 1. Add this import

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
    let notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) var scenePhase

    init() {
        // <-- 2. Set the App Check provider factory BEFORE configuring Firebase
        AppCheck.setAppCheckProviderFactory(YourAppCheckProviderFactory())

        print("=== Loaded fonts ===")
        for family in UIFont.familyNames.sorted() {
            for name in UIFont.fontNames(forFamilyName: family) {
                print(name)
            }
        }

        // Configure Firebase first
        FirebaseApp.configure()
        
        // Initialize Remote Config with default settings
        Self.configureRemoteConfig()
        
        // Configure Google Sign-In with better error handling
        Self.configureGoogleSignIn()
        
        // Initialize AuthViewModel after configuration
        _authViewModel = StateObject(wrappedValue: AuthViewModel())

        NotificationManager.shared.requestPermission()
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }
    
    // Add Remote Config initialization
    private static func configureRemoteConfig() {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        
        #if DEBUG
        settings.minimumFetchInterval = 0 // Allow immediate fetching in debug
        #else
        settings.minimumFetchInterval = 3600 // 1 hour in production
        #endif
        
        remoteConfig.configSettings = settings
        
        // Set defaults
        let defaults: [String: NSObject] = [
            "weather_api_key": "" as NSString
        ]
        remoteConfig.setDefaults(defaults)
        
        print("✅ Remote Config initialized")
    }
    
    // Made static so it can be called before instance initialization
    private static func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("⚠️ GoogleService-Info.plist not found in bundle")
            return
        }
        
        guard let plist = NSDictionary(contentsOfFile: path) else {
            print("⚠️ Could not read GoogleService-Info.plist")
            return
        }
        
        guard let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ CLIENT_ID not found in GoogleService-Info.plist")
            print("Available keys: \(plist.allKeys)")
            return
        }
        
        print("✅ Configuring Google Sign-In with CLIENT_ID: \(clientId)")
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
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
            .onOpenURL { url in
                // Handle Google Sign-In URL
                GIDSignIn.sharedInstance.handle(url)
            }
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
