import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

enum AnalyticsEvent: String {
    case onboardingCompleted = "onboarding_completed"
    case login = "login_success"
    case logout = "logout"
    case accountDeleted = "account_deleted"
}

final class AnalyticsService {
    static let shared = AnalyticsService()

    func log(_ event: AnalyticsEvent, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.rawValue, parameters: parameters)
        #else
        print("[Analytics] \(event.rawValue): \(parameters ?? [:])")
        #endif
    }

    func record(error: Error) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().record(error: error)
        #else
        print("[Crashlytics] \(error.localizedDescription)")
        #endif
    }
}
