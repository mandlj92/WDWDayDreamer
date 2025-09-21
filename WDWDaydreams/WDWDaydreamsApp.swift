import SwiftUI
import FirebaseCore
import FirebaseRemoteConfig
import GoogleSignIn
import FirebaseAuth
import FirebaseAppCheck

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
    let notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) var scenePhase

    init() {
        AppCheck.setAppCheckProviderFactory(YourAppCheckProviderFactory())
        FirebaseApp.configure()
        
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
            Group {
                if authViewModel.isAuthenticated {
                    AuthenticatedView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(weatherManager)
            .environmentObject(themeManager)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                print("App became active.")
                weatherManager.fetchWeather()
            }
        }
    }
}

struct AuthenticatedView: View {
    @StateObject private var manager = ScenarioManager()
    
    var body: some View {
        ContentView()
            .environmentObject(manager)
    }
}
