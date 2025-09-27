// Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: ScenarioManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.theme) var theme: Theme
    
    @State private var viewModel: SettingsViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    @State private var testResults: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Use the dynamic theme background color
                theme.backgroundCream
                    .edgesIgnoringSafeArea(.all)
                
                if let viewModel = viewModel {
                    Form {
                        // Title Section
                        Section {
                            VStack(alignment: .center, spacing: 12) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 40))
                                    .foregroundColor(theme.magicBlue)
                                
                                Text("Disney Daydreams Settings")
                                    .font(.disneyTitle(18))
                                    .foregroundColor(theme.magicBlue)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .listRowBackground(theme.backgroundCream)
                        }
                        
                        // App Appearance Section
                        Section(header: SectionHeader(title: "Appearance", theme: theme)) {
                            Picker("Theme", selection: $themeManager.selectedTheme) {
                                ForEach(ThemeOption.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .listRowBackground(theme.cardBackground)

                        // Category Section
                        Section(header: SectionHeader(title: "Enable Categories For Prompts", theme: theme)) {
                            ForEach(Category.allCases) { category in
                                CategoryToggleRow(
                                    category: category,
                                    viewModel: viewModel,
                                    theme: theme
                                )
                            }
                            
                            let enabledCount = Category.allCases.filter { viewModel.isCategoryEnabled($0) }.count
                            if enabledCount == 1 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("At least one category must be enabled")
                                        .font(.caption)
                                }
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                            }
                        }
                        .listRowBackground(theme.cardBackground)

                        // Trip Countdown Section
                        Section(header: SectionHeader(title: "Trip Countdown", theme: theme)) {
                            DatePicker(
                                "Trip Date",
                                selection: Binding(
                                    get: { viewModel.tripDate.wrappedValue ?? Date() },
                                    set: { viewModel.tripDate.wrappedValue = $0 }
                                ),
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .colorScheme(themeManager.selectedTheme == .dark ? .dark : .light)
                            .foregroundColor(theme.primaryText)

                            if viewModel.showTripCountdown {
                                TripCountdownRow(days: viewModel.daysUntilTrip, theme: theme)
                            }
                        }
                        .listRowBackground(theme.cardBackground)

                        // System Tests Section
                        Section(header: SectionHeader(title: "System Tests", theme: theme)) {
                            Button("Test Firebase Connection") {
                                testFirebaseConnection()
                            }
                            .buttonStyle(DisneyButtonStyle(color: theme.magicBlue))
                            
                            if !testResults.isEmpty {
                                Text(testResults)
                                    .font(.caption)
                                    .foregroundColor(testResults.contains("✅") ? .green : .red)
                                    .padding(.top, 4)
                            }
                        }
                        .listRowBackground(theme.cardBackground)

                        // Danger Zone Section
                        Section(header: Text("Danger Zone").foregroundColor(theme.mickeyRed).font(.headline)) {
                            Button(action: {
                                showClearConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Clear All Story History")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(DisneyButtonStyle(color: theme.mickeyRed))
                            .listRowBackground(theme.backgroundCream)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .alert(isPresented: $showClearConfirmation) {
                        Alert(
                            title: Text("Clear History"),
                            message: Text("Are you sure? This cannot be undone."),
                            primaryButton: .destructive(Text("Clear All")) {
                                viewModel.clearHistory()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                } else {
                    ProgressView("Loading...").progressViewStyle(CircularProgressViewStyle(tint: theme.magicBlue))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.magicBlue)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                self.viewModel = SettingsViewModel(manager: manager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // Test Firebase connection
    private func testFirebaseConnection() {
        testResults = "Testing..."
        
        FirebaseDataService.shared.testFirebaseConnection { success, message in
            DispatchQueue.main.async {
                testResults = success ? "✅ \(message)" : "❌ \(message)"
            }
        }
    }
}

// MARK: - Subviews
struct SectionHeader: View {
    let title: String
    let theme: Theme
    
    var body: some View {
        Text(title)
            .foregroundColor(theme.magicBlue)
            .font(.headline)
    }
}

struct CategoryToggleRow: View {
    let category: Category
    let viewModel: SettingsViewModel
    let theme: Theme
    
    private var isEnabled: Binding<Bool> {
        Binding(
            get: { viewModel.isCategoryEnabled(category) },
            set: { newValue in
                let currentlyEnabled = Category.allCases.filter { viewModel.isCategoryEnabled($0) }
                if !newValue && currentlyEnabled.count <= 1 { return }
                viewModel.toggleCategory(category, isEnabled: newValue)
            }
        )
    }
    
    private var isLastEnabled: Bool {
        let currentlyEnabled = Category.allCases.filter { viewModel.isCategoryEnabled($0) }
        return currentlyEnabled.count == 1 && viewModel.isCategoryEnabled(category)
    }
    
    var body: some View {
        Toggle(isOn: isEnabled) {
            HStack {
                Image(systemName: CategoryHelper.icon(for: category))
                    .foregroundColor(CategoryHelper.color(for: category))
                
                Text(category.rawValue.capitalized)
                    .foregroundColor(theme.primaryText)
                
                if isLastEnabled {
                    Spacer()
                    Image(systemName: "lock.fill").foregroundColor(.orange).font(.caption)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: CategoryHelper.color(for: category)))
        .disabled(isLastEnabled)
    }
}

struct TripCountdownRow: View {
    let days: Int
    let theme: Theme
    
    var body: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
            Text("\(days) day\(days == 1 ? "" : "s") until your trip!")
                .font(.headline)
        }
        .foregroundColor(theme.mickeyRed)
        .padding(.vertical, 4)
    }
}
