// DesignSystem.swift
import SwiftUI

/// Centralized design system tokens for consistent UI/UX
struct DesignSystem {

    // MARK: - Corner Radius System
    /// Standardized corner radius values following 3-tier system
    enum CornerRadius {
        /// Small radius for input fields, small badges, and compact UI elements
        static let small: CGFloat = 8

        /// Medium radius for cards, buttons, and standard UI elements
        static let medium: CGFloat = 12

        /// Large radius for modal sheets, hero cards, and prominent containers
        static let large: CGFloat = 20
    }

    // MARK: - Spacing System
    /// 8pt grid-based spacing system for consistent layouts
    enum Spacing {
        /// Extra extra small spacing (4pt)
        static let xxs: CGFloat = 4

        /// Extra small spacing (8pt) - base unit of grid
        static let xs: CGFloat = 8

        /// Small spacing (12pt)
        static let sm: CGFloat = 12

        /// Medium spacing (16pt)
        static let md: CGFloat = 16

        /// Large spacing (24pt)
        static let lg: CGFloat = 24

        /// Extra large spacing (32pt)
        static let xl: CGFloat = 32
    }

    // MARK: - Animation Constants
    /// Standardized animation timings for consistent micro-interactions
    enum Animation {
        /// Quick animation for small transitions (0.2s)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)

        /// Standard animation for most UI transitions (0.3s)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)

        /// Slow animation for deliberate, prominent transitions (0.5s)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)

        /// Spring animation for playful, natural-feeling interactions
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
}
