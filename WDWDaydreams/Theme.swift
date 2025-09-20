//
//  Theme.swift
//  WDWDaydreams
//
//  Created by Jonathan Mandl on 4/20/25.
//

import SwiftUI

// MARK: –– Disney‑Style Fonts
extension Font {
    /// "Waltograph" title font; size in points
    static func disneyTitle(_ size: CGFloat) -> Font {
        Font.custom("WaltographUI-Bold", size: size)
    }
    /// "Waltograph" body font; scaled down
    static func disneyBody(_ size: CGFloat) -> Font {
        Font.custom("WaltographUI-Bold", size: size * 0.6)
    }
}

// MARK: - Disney Colors
struct DisneyColors {
    static let magicBlue = Color(red: 25/255, green: 113/255, blue: 184/255)
    static let castlePink = Color(red: 247/255, green: 168/255, blue: 184/255)
    static let mickeyRed = Color(red: 204/255, green: 0/255, blue: 0/255)
    static let adventureGreen = Color(red: 39/255, green: 111/255, blue: 78/255)
    static let fantasyPurple = Color(red: 143/255, green: 88/255, blue: 178/255)
    static let tomorrowlandSilver = Color(red: 164/255, green: 174/255, blue: 184/255)
    static let mainStreetGold = Color(red: 227/255, green: 197/255, blue: 102/255)
    static let backgroundCream = Color(red: 252/255, green: 250/255, blue: 245/255)
}

// MARK: - Disney Button Style
struct DisneyButtonStyle: ButtonStyle {
    var color: Color = DisneyColors.magicBlue
    var textColor: Color = .white
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(textColor)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white, lineWidth: 2)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

// MARK: - Disney UI Elements
extension View {
    func disneyCard() -> some View {
        self
            .padding()
            .background(DisneyColors.backgroundCream)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(DisneyColors.mainStreetGold.opacity(0.3), lineWidth: 1)
            )
    }
    
    func disneyHeader() -> some View {
        self
            .font(.system(.headline, design: .rounded))
            .foregroundColor(DisneyColors.magicBlue)
    }
}
