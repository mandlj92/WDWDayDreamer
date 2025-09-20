// Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: ScenarioManager
    @State private var viewModel: SettingsViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Apply a subtle background
                DisneyColors.backgroundCream
                    .edgesIgnoringSafeArea(.all)
                
                if let viewModel = viewModel {
                    Form {
                        Section {
                            VStack(alignment: .center, spacing: 12) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 40))
                                    .foregroundColor(DisneyColors.magicBlue)
                                
                                Text("Disney Daydreams Settings")
                                    .font(.disneyTitle(18))
                                    .foregroundColor(DisneyColors.magicBlue)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .listRowBackground(DisneyColors.backgroundCream)
                        }
                        
                        // Category section
                        Section(header: SectionHeader(title: "Enable Categories For Prompts")) {
                            ForEach(Category.allCases) { category in
                                CategoryToggleRow(
                                    category: category,
                                    isEnabled: Binding(
                                        get: { viewModel.isCategoryEnabled(category) },
                                        set: { viewModel.toggleCategory(category, isEnabled: $0) }
                                    )
                                )
                            }
                        }
                        .listRowBackground(Color.white)

                        // Trip countdown section
                        Section(header: SectionHeader(title: "Trip Countdown")) {
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
                            .foregroundColor(DisneyColors.magicBlue)

                            // Display the countdown
                            if viewModel.showTripCountdown {
                                TripCountdownRow(days: viewModel.daysUntilTrip)
                            } else if viewModel.tripDate.wrappedValue != nil {
                                Text("Trip date has passed.")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .listRowBackground(Color.white)

                        // Danger zone section
                        Section(header: Text("Danger Zone")
                                    .foregroundColor(DisneyColors.mickeyRed)
                                    .font(.headline)) {
                            Button(action: {
                                showClearConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.white)
                                    Text("Clear All Story History")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(DisneyColors.mickeyRed)
                                .cornerRadius(10)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .listRowBackground(DisneyColors.backgroundCream)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .alert(isPresented: $showClearConfirmation) {
                        Alert(
                            title: Text("Clear History"),
                            message: Text("Are you sure you want to clear all story history? This cannot be undone."),
                            primaryButton: .destructive(Text("Clear All")) {
                                viewModel.clearHistory()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                } else {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle(tint: DisneyColors.magicBlue))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DisneyColors.magicBlue)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                self.viewModel = SettingsViewModel(manager: manager)
            }
        }
    }
}

// Settings components
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .foregroundColor(DisneyColors.magicBlue)
            .font(.headline)
    }
}

struct CategoryToggleRow: View {
    let category: Category
    @Binding var isEnabled: Bool
    
    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Image(systemName: CategoryHelper.icon(for: category))
                    .foregroundColor(CategoryHelper.color(for: category))
                
                Text(category.rawValue.capitalized)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: CategoryHelper.color(for: category)))
    }
}

struct TripCountdownRow: View {
    let days: Int
    
    var body: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(DisneyColors.mickeyRed)
            
            Text("\(days) day\(days == 1 ? "" : "s") until your trip!")
                .foregroundColor(DisneyColors.mickeyRed)
                .font(.headline)
        }
        .padding(.vertical, 4)
    }
}
