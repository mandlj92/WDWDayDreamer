// Theme.swift
import SwiftUI

// MARK: - Theme Protocol
protocol Theme {
    var primaryBlue: Color { get }
    var accentPink: Color { get }
    var accentRed: Color { get }
    var accentGreen: Color { get }
    var accentPurple: Color { get }
    var accentSilver: Color { get }
    var accentGold: Color { get }
    var backgroundCream: Color { get }
    var primaryText: Color { get }
    var secondaryText: Color { get }
    var cardBackground: Color { get }
}

// MARK: - Light Theme
struct LightTheme: Theme {
    let primaryBlue = Color(red: 25/255, green: 113/255, blue: 184/255)
    let accentPink = Color(red: 247/255, green: 168/255, blue: 184/255)
    let accentRed = Color(red: 204/255, green: 0/255, blue: 0/255)
    let accentGreen = Color(red: 39/255, green: 111/255, blue: 78/255)
    let accentPurple = Color(red: 108/255, green: 55/255, blue: 143/255)
    let accentSilver = Color(red: 92/255, green: 102/255, blue: 112/255)
    let accentGold = Color(red: 184/255, green: 143/255, blue: 30/255)
    let backgroundCream = Color(red: 252/255, green: 250/255, blue: 245/255)
    let primaryText = Color.primary
    let secondaryText = Color(red: 100/255, green: 100/255, blue: 100/255)
    let cardBackground = Color.white
}

// MARK: - Dark Theme
struct DarkTheme: Theme {
    let primaryBlue = Color(red: 75/255, green: 153/255, blue: 224/255)
    let accentPink = Color(red: 200/255, green: 120/255, blue: 135/255)
    let accentRed = Color(red: 255/255, green: 59/255, blue: 48/255)
    let accentGreen = Color(red: 85/255, green: 170/255, blue: 125/255)
    let accentPurple = Color(red: 198/255, green: 168/255, blue: 228/255)
    let accentSilver = Color(red: 210/255, green: 220/255, blue: 230/255)
    let accentGold = Color(red: 255/255, green: 215/255, blue: 120/255)
    let backgroundCream = Color(red: 28/255, green: 28/255, blue: 30/255) // Dark Gray
    let primaryText = Color.white
    let secondaryText = Color(red: 190/255, green: 190/255, blue: 190/255) // Light Gray
    let cardBackground = Color(red: 44/255, green: 44/255, blue: 46/255)
}

// MARK: - Theme Colors (Static Access)
// This provides static access to theme colors for gradual migration
struct ThemeColors {
    // Use light theme colors as static defaults
    static let primaryBlue = Color(red: 25/255, green: 113/255, blue: 184/255)
    static let accentPink = Color(red: 247/255, green: 168/255, blue: 184/255)
    static let accentRed = Color(red: 204/255, green: 0/255, blue: 0/255)
    static let accentGreen = Color(red: 39/255, green: 111/255, blue: 78/255)
    static let accentPurple = Color(red: 108/255, green: 55/255, blue: 143/255)
    static let accentSilver = Color(red: 92/255, green: 102/255, blue: 112/255)
    static let accentGold = Color(red: 184/255, green: 143/255, blue: 30/255)
    static let backgroundCream = Color(red: 252/255, green: 250/255, blue: 245/255)
}

// MARK: - Park Theme Fonts
extension Font {
    static func parkTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func parkBody(_ size: CGFloat) -> Font {
        .system(size: size * 0.6, weight: .semibold, design: .rounded)
    }
}

// MARK: - Park Button Style
struct ParkButtonStyle: ButtonStyle {
    var color: Color
    var textColor: Color = .white

    init(color: Color = ThemeColors.primaryBlue, textColor: Color = .white) {
        self.color = color
        self.textColor = textColor
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(textColor)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
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

// MARK: - Park UI Elements
extension View {
    func parkCard(theme: Theme) -> some View {
        self
            .padding()
            .background(theme.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(theme.accentGold.opacity(0.3), lineWidth: 1)
            )
    }

    func parkHeader(theme: Theme) -> some View {
        self
            .font(.system(.headline, design: .rounded))
            .foregroundColor(theme.primaryBlue)
    }
}
