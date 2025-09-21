//
//  ThemeManager.swift
//  WDWDaydreams
//
//  Created by Jonathan Mandl on 9/21/25.
//

// ThemeManager.swift
import SwiftUI

// Enum to define the available themes
enum ThemeOption: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var selectedTheme: ThemeOption = .system {
        didSet {
            // Save the selected theme to UserDefaults
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    init() {
        // Load the saved theme from UserDefaults
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") {
            self.selectedTheme = ThemeOption(rawValue: savedTheme) ?? .system
        }
    }
}
