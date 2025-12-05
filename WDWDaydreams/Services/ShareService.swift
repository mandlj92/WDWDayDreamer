import Foundation

final class ShareService {
    static let shared = ShareService()
    private init() {}

    /// Returns a shareable string containing a deep link plus App Store fallback.
    func shareText(for promptText: String, storyText: String?) -> String {
        // Deep link scheme (configure your Universal Link / URL scheme in app)
        let deepLink = "wdwdaydreams://"

        var body = "I just wrote a Disney Daydream!\n\nPrompt: \(promptText)"
        if let s = storyText {
            body += "\n\nStory:\n\(s)"
        }

        // Fallback App Store link - replace with your real App Store ID
        let appStore = "https://apps.apple.com/app/idYOUR_APP_ID"

        body += "\n\nOpen in app: \(deepLink) or get it on the App Store: \(appStore)"
        return body
    }
}
