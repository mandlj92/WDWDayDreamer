// ViewModels/TodayViewModel.swift
import Foundation
import SwiftUI
import Combine

class TodayViewModel: ObservableObject {
    // Published properties
    @Published var storyText: String = ""
    @Published var isEditing: Bool = false
    
    // Dependencies
    private let manager: ScenarioManager
    
    init(manager: ScenarioManager) {
        self.manager = manager
        
        // Initialize text editor with existing story if available
        if let prompt = manager.currentStoryPrompt, prompt.isWritten {
            storyText = prompt.storyText ?? ""
        }
    }
    
    var currentPrompt: DaydreamStory? {
        manager.currentStoryPrompt
    }
    
    var isCurrentUsersTurn: Bool {
        manager.isCurrentUsersTurn()
    }
    
    var showTripCountdown: Bool {
        guard let tripDate = manager.tripDate else { return false }
        let days = daysUntilTrip
        return tripDate > Date() && days >= 0
    }
    
    var daysUntilTrip: Int {
        guard let tripDate = manager.tripDate else { return 0 }
        return Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: tripDate)).day ?? 0
    }
    
    func toggleFavorite() {
        manager.toggleFavorite()
    }
    
    func saveStory() {
        guard let prompt = manager.currentStoryPrompt else { return }
        manager.saveStoryText(storyText, for: prompt.id)
        isEditing = false
    }
    
    func beginEditing() {
        if let prompt = manager.currentStoryPrompt, prompt.isWritten {
            storyText = prompt.storyText ?? ""
        }
        isEditing = true
    }
    
    func generateNewPrompt() {
        manager.next()
    }
}

// ViewModels/HistoryViewModel.swift
import Foundation
import SwiftUI

class HistoryViewModel: ObservableObject {
    // Published properties
    @Published var isRefreshing: Bool = false
    
    // Dependencies
    private let manager: ScenarioManager
    
    init(manager: ScenarioManager) {
        self.manager = manager
    }
    
    var storyHistory: [DaydreamStory] {
        manager.storyHistory
    }
    
    var isEmpty: Bool {
        storyHistory.isEmpty
    }
    
    func refreshHistory() {
        isRefreshing = true
        manager.fetchStoryHistory()
        
        // Simulate refreshing state for feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isRefreshing = false
        }
    }
    
    func clearHistory() {
        manager.clearHistory()
    }
}

// ViewModels/FavoritesViewModel.swift
import Foundation
import SwiftUI

class FavoritesViewModel: ObservableObject {
    // Dependencies
    private let manager: ScenarioManager
    
    init(manager: ScenarioManager) {
        self.manager = manager
    }
    
    var favorites: [DaydreamStory] {
        manager.favorites
    }
    
    var isEmpty: Bool {
        favorites.isEmpty
    }
    
    func removeFavorite(at offsets: IndexSet) {
        manager.removeFavorite(at: offsets)
    }
}

// ViewModels/SettingsViewModel.swift
import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    // Dependencies
    private let manager: ScenarioManager
    
    init(manager: ScenarioManager) {
        self.manager = manager
    }
    
    var enabledCategories: Binding<[Category]> {
        Binding(
            get: { self.manager.enabledCategories },
            set: { self.manager.enabledCategories = $0 }
        )
    }
    
    var tripDate: Binding<Date?> {
        Binding(
            get: { self.manager.tripDate },
            set: { self.manager.tripDate = $0 }
        )
    }
    
    var showTripCountdown: Bool {
        guard let tripDate = manager.tripDate else { return false }
        return tripDate > Date() && daysUntilTrip >= 0
    }
    
    var daysUntilTrip: Int {
        guard let tripDate = manager.tripDate else { return 0 }
        return Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: tripDate)).day ?? 0
    }
    
    func isCategoryEnabled(_ category: Category) -> Bool {
        manager.enabledCategories.contains(category)
    }
    
    func toggleCategory(_ category: Category, isEnabled: Bool) {
        if isEnabled {
            if !manager.enabledCategories.contains(category) {
                manager.enabledCategories.append(category)
                manager.enabledCategories.sort(by: { $0.rawValue < $1.rawValue })
            }
        } else {
            manager.enabledCategories.removeAll { $0 == category }
        }
    }
    
    func clearHistory() {
        manager.clearHistory()
    }
}

// ViewModels/LoginViewModel.swift
import Foundation
import SwiftUI

class LoginViewModel: ObservableObject {
    // Published properties
    @Published var isLoggedIn: Bool = false
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false
    
    // Dependencies
    private let firebaseService = FirebaseDataService.shared
    
    func loginAs(email: String, password: String) {
        isLoading = true
        errorMessage = ""
        
        firebaseService.loginUser(email: email, password: password) { success, errorMsg in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    self.isLoggedIn = true
                } else if let errorMsg = errorMsg {
                    self.errorMessage = errorMsg
                    print("Login error: \(errorMsg)")
                }
            }
        }
    }
    
    func createTestAccounts() {
        firebaseService.createTestAccounts { success, message in
            if !success, let message = message {
                print("Account creation error: \(message)")
            }
        }
    }
}
