import Foundation
import SwiftUI // Added for Color

// MARK: - Data Definitions

// Represents who is assigned to write the story
enum StoryAuthor: String, Codable, CaseIterable {
    case user = "Jon" // Use "Jon" for display
    case wife = "Carolyn"

    var displayName: String {
        return self.rawValue
    }

    func next() -> StoryAuthor {
        return self == .user ? .wife : .user
    }
}

// Represents a single day's prompt and response
struct DaydreamStory: Identifiable, Codable, Equatable { // <-- ADDED EQUATABLE HERE
    let id: UUID
    var dateAssigned: Date
    var items: [Category: String] // The generated scenario items
    var assignedAuthor: StoryAuthor
    var storyText: String? // The actual story written
    var isFavorite: Bool // << --- ADDED THIS PROPERTY ---

    // Default initializer - UPDATED
    init(id: UUID = UUID(), dateAssigned: Date, items: [Category: String], assignedAuthor: StoryAuthor, storyText: String? = nil, isFavorite: Bool = false) { // Added isFavorite here
        self.id = id
        self.dateAssigned = dateAssigned
        self.items = items
        self.assignedAuthor = assignedAuthor
        self.storyText = storyText
        self.isFavorite = isFavorite // << --- ASSIGN isFavorite ---
    }

    // Helper to get a short prompt text from items
    var promptText: String {
        // Example: "Ride: Space Mountain, Food: Dole Whip, Park: Magic Kingdom"
        items.sorted { $0.key.rawValue < $1.key.rawValue }
             .map { "\($0.key.rawValue.capitalized): \($0.value)" }
             .joined(separator: ", ")
    }

    // Check if story is written for this prompt
    var isWritten: Bool {
        storyText != nil && !(storyText?.isEmpty ?? true)
    }

    // Determine if this story is for today
    var isToday: Bool {
        Calendar.current.isDateInToday(dateAssigned)
    }
}

// Category remains the same
enum Category: String, CaseIterable, Codable, Identifiable {
    case hotel, park, ride, food, beverage, souvenir, character, event
    var id: String { rawValue }

    // Added for potential display variation
    var promptPrefix: String {
        switch self {
        case .hotel: return "Staying at"
        case .park: return "Visiting"
        case .ride: return "Riding"
        case .food: return "Eating"
        case .beverage: return "Drinking"
        case .souvenir: return "Buying"
        case .character: return "Meeting"
        case .event: return "Attending"
        }
    }
}

// DataModel remains the same structure
class DataModel {
    static let shared = DataModel()

    // --- Use YOUR full lists of items here ---
    let hotels = [
        "All‑Star Movies Resort","All‑Star Music Resort","All‑Star Sports Resort",
        "Art of Animation Resort","Pop Century Resort",
        "Caribbean Beach Resort","Coronado Springs Resort",
        "Port Orleans – Riverside","Port Orleans – French Quarter","Fort Wilderness Campground",
        "Animal Kingdom Lodge","Beach Club Resort","BoardWalk Inn",
        "Contemporary Resort","Grand Floridian Resort & Spa",
        "Polynesian Village Resort","Wilderness Lodge","Yacht Club Resort",
        "Animal Kingdom Villas – Jambo House","Kidani Village",
        "Bay Lake Tower","Boulder Ridge Villas","Copper Creek Villas",
        "Polynesian Villas & Bungalows","Riviera Resort",
        "Beach Club Villas","BoardWalk Villas","Old Key West Resort","Saratoga Springs"
    ]
    let parks = ["Magic Kingdom","Epcot","Hollywood Studios","Animal Kingdom"]
    let rides = [
        "Seven Dwarfs Mine Train","Space Mountain","Big Thunder Mountain Railroad",
        "Haunted Mansion","Jungle Cruise","Peter Pan's Flight","Tron Lightcycle / Run",
        "Spaceship Earth","Soarin' Around the World","Test Track","Frozen Ever After",
        "Remy's Ratatouille Adventure","Guardians of the Galaxy: Cosmic Rewind",
        "Star Wars: Rise of the Resistance","Slinky Dog Dash","Tower of Terror",
        "Rock 'n' Roller Coaster","Mickey & Minnie's Runaway Railway",
        "Avatar Flight of Passage","Kilimanjaro Safaris","Expedition Everest",
        "Kali River Rapids","DINOSAUR","it's Tough to be a Bug!"
    ]
    let foods = ["Dole Whip","Churros","Le Cellier Steakhouse","Mickey Ice Cream Bar", "Beignets (Port Orleans)", "Zebra Domes (AKL)"]
    let beverages = ["Frozen Margarita (La Cava)","School Bread (Kringla)","Pongu Lumpia (AK)", "Mint Julep (MK)"]
    let souvenirs = ["Mickey Ear Hat","Figment Plush","MagicBand+","Loungefly Backpack", "Spirit Jersey"]
    let characters = ["Meeting Cinderella","Meeting Mickey","Meet & Greet Buzz Lightyear", "Hugging Chewbacca", "Finding Winnie the Pooh"]
    let events = ["Food & Wine Festival","Not‑So‑Scary Halloween Party","Festival of the Arts", "Flower & Garden Festival", "Candlelight Processional"]
    // --- End of data lists ---


    func list(for category: Category) -> [String] {
        switch category {
        case .hotel:      return hotels
        case .park:       return parks
        case .ride:       return rides
        case .food:       return foods
        case .beverage:   return beverages
        case .souvenir:   return souvenirs
        case .character:  return characters
        case .event:      return events
        }
    }

    // Helper to get a random item for a category
    func randomItem(for category: Category) -> String? {
        return list(for: category).randomElement()
    }
}
