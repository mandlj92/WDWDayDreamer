// Helpers/HapticManager.swift
import SwiftUI

class HapticManager {
    static let instance = HapticManager() // Singleton
    
    private init() {}

    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    // MARK: - Convenience Methods

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    func success() {
        notification(type: .success)
    }

    func warning() {
        notification(type: .warning)
    }

    func error() {
        notification(type: .error)
    }
}
