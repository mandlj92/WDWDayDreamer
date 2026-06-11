// DesignSystem.swift
import SwiftUI

/// Centralized design system tokens for consistent UI/UX.
///
/// The visual language is typography-first: hierarchy comes from type scale,
/// weight, case, and alignment — not from cards, boxes, or borders.
struct DesignSystem {

    // MARK: - Corner Radius System
    /// Reserved for interactive controls (buttons, input fields). Content is
    /// never wrapped in rounded containers.
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

        /// Standard leading/trailing page margin
        static let pageMargin: CGFloat = 20

        /// Fixed width of the label column in aligned label/value rows,
        /// so values line up vertically across rows
        static let labelColumn: CGFloat = 92
    }

    // MARK: - Typography
    /// Semantic type scale. All styles are Dynamic Type compatible.
    enum Typography {
        /// Page-level title (navigation bars, hero headings)
        static let pageTitle = Font.system(.title2, design: .rounded).weight(.bold)

        /// Section heading within a page
        static let sectionTitle = Font.system(.headline, design: .rounded)

        /// Small uppercase label used for section markers and metadata keys
        static let label = Font.system(.caption, design: .rounded).weight(.semibold)

        /// Metadata line (dates, authorship, status)
        static let meta = Font.system(.caption2, design: .rounded).weight(.medium)

        /// Prompt text — distinguished from story prose by italics
        static let prompt = Font.system(.callout).italic()

        /// Story prose
        static let body = Font.system(.body)

        /// Supporting copy under headings
        static let subtext = Font.system(.subheadline)
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

// MARK: - Section Label
/// Uppercase, tracked caption used to mark sections typographically
/// (in place of boxed section headers).
struct SectionLabel: View {
    let text: String
    var color: Color?
    @Environment(\.theme) private var theme: Theme

    init(_ text: String, color: Color? = nil) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(DesignSystem.Typography.label)
            .tracking(1.2)
            .foregroundColor(color ?? theme.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Hairline
/// A 1px rule used to separate content regions without enclosing them.
struct Hairline: View {
    @Environment(\.theme) private var theme: Theme

    var body: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(height: 1)
    }
}

// MARK: - Labeled Row
/// Aligned label/value pair: fixed-width label column so values form a
/// scannable left edge across consecutive rows.
struct LabeledRow: View {
    let label: String
    let value: String
    var labelColor: Color?
    @Environment(\.theme) private var theme: Theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
            Text(label.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(0.8)
                .foregroundColor(labelColor ?? theme.secondaryText)
                .frame(width: DesignSystem.Spacing.labelColumn, alignment: .leading)

            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
