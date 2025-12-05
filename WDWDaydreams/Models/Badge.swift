import Foundation

struct Badge: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let requirement: String

    static let allBadges: [Badge] = [
        Badge(id: "first_story", name: "Storyteller", icon: "✍️", description: "Write your first story", requirement: "1 story"),
        Badge(id: "ten_stories", name: "Prolific", icon: "📚", description: "Write 10 stories", requirement: "10 stories"),
        Badge(id: "week_streak", name: "Consistent", icon: "🔥", description: "Maintain a 7-day streak", requirement: "7-day streak"),
        Badge(id: "daily_master", name: "Daily Master", icon: "⭐", description: "Write every day for 30 days", requirement: "30-day streak")
    ]
}
