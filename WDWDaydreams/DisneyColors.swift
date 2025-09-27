//
//  DisneyColors.swift
//  WDWDaydreams
//
//  Created by Jonathan Mandl on 9/21/25.
//

// DisneyColors.swift
// This is a compatibility layer that bridges your existing DisneyColors references
// to the theme system. This allows gradual migration to the theme-based approach.

import SwiftUI

struct DisneyColors {
    // These static colors will use the light theme colors as defaults
    // In the future, you should migrate all references to use @Environment(\.theme) instead
    
    static let magicBlue = Color(red: 25/255, green: 113/255, blue: 184/255)
    static let castlePink = Color(red: 247/255, green: 168/255, blue: 184/255)
    static let mickeyRed = Color(red: 204/255, green: 0/255, blue: 0/255)
    static let adventureGreen = Color(red: 39/255, green: 111/255, blue: 78/255)
    static let fantasyPurple = Color(red: 143/255, green: 88/255, blue: 178/255)
    static let tomorrowlandSilver = Color(red: 164/255, green: 174/255, blue: 184/255)
    static let mainStreetGold = Color(red: 227/255, green: 197/255, blue: 102/255)
    static let backgroundCream = Color(red: 252/255, green: 250/255, blue: 245/255)
}

// Extension for DisneyButtonStyle to work with both static colors and theme
extension DisneyButtonStyle {
    // Convenience initializer that uses the default magic blue
    init() {
        self.init(color: DisneyColors.magicBlue)
    }
    
    // Theme-aware initializer
    init(theme: Theme) {
        self.init(color: theme.magicBlue)
    }
}
