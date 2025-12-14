import Foundation
import SwiftUI

class NavigationCoordinator: ObservableObject {
    @Published var targetPartnershipId: String?
    @Published var targetStoryDate: String?
    @Published var shouldNavigate = false

    static let shared = NavigationCoordinator()

    private init() {}

    func navigateToStory(partnershipId: String, storyDate: String) {
        self.targetPartnershipId = partnershipId
        self.targetStoryDate = storyDate
        self.shouldNavigate = true
    }

    func clearNavigation() {
        targetPartnershipId = nil
        targetStoryDate = nil
        shouldNavigate = false
    }
}
