import Foundation

struct GreetingHelper {
    static func generateGreeting(for name: String, tripDate: Date?) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        
        switch hour {
        case 5..<12:
            greeting = "Good morning"
        case 12..<17:
            greeting = "Good afternoon"
        case 17..<21:
            greeting = "Good evening"
        default:
            greeting = "Magical dreams tonight"
        }
        
        if let tripDate = tripDate {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: tripDate)).day ?? 0
            if days > 0 {
                return "\(greeting), \(name)! ✨ \(days) days until your trip!"
            }
        }

        return "\(greeting), \(name)! ✨"
    }
}
