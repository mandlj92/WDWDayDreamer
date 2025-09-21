//
//  HapticManager.swift
//  WDWDaydreams
//
//  Created by Jonathan Mandl on 9/21/25.
//

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
}
