// Theme.swift
import SwiftUI

// MARK: - Theme Protocol
protocol Theme {
    var magicBlue: Color { get }
    var castlePink: Color { get }
    var mickeyRed: Color { get }
    var adventureGreen: Color { get }
    var fantasyPurple: Color { get }
    var tomorrowlandSilver: Color { get }
    var mainStreetGold: Color { get }
    var backgroundCream: Color { get }
    var primaryText: Color { get }
    var secondaryText: Color { get }
    var cardBackground: Color { get }
}

// MARK: - Light Theme
struct LightTheme: Theme {
    let magicBlue = Color(red: 25/255, green: 113/255, blue: 184/255)
    let castlePink = Color(red: 247/255, green: 168/255, blue: 184/255)
    let mickeyRed = Color(red: 204/255, green: 0/255, blue: 0/255)
    let adventureGreen = Color(red: 39/255, green: 111/255, blue: 78/255)
    let fantasyPurple = Color(red: 143/255, green: 88/255, blue: 178/255)
    let tomorrowlandSilver = Color(red: 164/255, green: 174/255, blue: 184/255)
    let mainStreetGold = Color(red: 227/255, green: 197/255, blue: 102/255)
    let backgroundCream = Color(red: 252/255, green: 250/255, blue: 245/255)
    let primaryText = Color.primary
    let secondaryText = Color.secondary
    let cardBackground = Color.white
}

// MARK: - Dark Theme
struct DarkTheme: Theme {
    let magicBlue = Color(red: 75/255, green: 153/255, blue: 224/255)
    let castlePink = Color(red: 200/255, green: 120/255, blue: 135/255)
    let mickeyRed = Color(red: 255/255, green: 59/255, blue: 48/255)
    let adventureGreen = Color(red: 85/255, green: 170/255, blue: 125/255)
    let fantasyPurple = Color(red: 173/255, green: 138/255, blue: 208/255)
    let tomorrowlandSilver = Color(red: 180/255, green: 190/255, blue: 200/255)
    let mainStreetGold = Color(red: 237/255, green: 207/255, blue: 112/255)
    let backgroundCream = Color(red: 28/255, green: 28/255, blue: 30/255) // Dark Gray
    let primaryText = Color.white
    let secondaryText = Color(red: 170/255, green: 170/255, blue: 170/255) // Light Gray
    let cardBackground = Color(red: 44/255, green: 44/255, blue: 46/255)
}


// MARK: –– Disney‑Style Fonts
extension Font {
    static func disneyTitle(_ size: CGFloat) -> Font {
        Font.custom("WaltographUI-Bold", size: size)
    }
    static func disneyBody(_ size: CGFloat) -> Font {
        Font.custom("WaltographUI-Bold", size: size * 0.6)
    }
}

// MARK: - Disney Button Style
struct DisneyButtonStyle: ButtonStyle {
    var color: Color
    var textColor: Color = .white
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(textColor)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) {
                if configuration.isPressed {
                    HapticManager.instance.impact(style: .light)
                }
            }
    }
}

// MARK: - Disney UI Elements
extension View {
    func disneyCard(theme: Theme) -> some View {
        self
            .padding()
            .background(theme.cardBackground)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(theme.mainStreetGold.opacity(0.3), lineWidth: 1)
            )
    }
    
    func disneyHeader(theme: Theme) -> some View {
        self
            .font(.system(.headline, design: .rounded))
            .foregroundColor(theme.magicBlue)
    }
}
