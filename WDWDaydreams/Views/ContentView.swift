// Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: ScenarioManager
    @EnvironmentObject var weatherManager: WDWWeatherManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSettings = false
    @State private var currentView = "Today"
    @State private var isInitializing = true
    @State private var showLogoutAlert = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            // Background
            DisneyColors.backgroundCream
                .edgesIgnoringSafeArea(.all)

            // Subtle sparkle decoration at the bottom (replacing the missing castle image)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 80))
                        .foregroundColor(DisneyColors.mainStreetGold.opacity(0.1))
                    Spacer()
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 60))
                        .foregroundColor(DisneyColors.magicBlue.opacity(0.1))
                    Spacer()
                }
                .offset(y: 20)
            }
            .edgesIgnoringSafeArea(.bottom)

            // Main content
            NavigationView {
                VStack {
                    // Tab selector
                    Picker("View", selection: $currentView) {
                        Text("Today").tag("Today")
                        Text("History").tag("History")
                        Text("Favorites").tag("Favorites")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .background(DisneyColors.backgroundCream)

                    // Content based on selected tab
                    if currentView == "Today" {
                        TodayView()
                    } else if currentView == "History" {
                        HistoryView()
                    } else if currentView == "Favorites" {
                        FavoritesView()
                    }
                }
                .navigationTitle("Disney Daydreams")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Disney Daydreams")
                            .font(.disneyTitle(24))
                            .foregroundColor(DisneyColors.magicBlue)
                    }

                    // Add weather widget in the toolbar
                    ToolbarItem(placement: .navigationBarLeading) {
                        WeatherWidget(weatherManager: weatherManager, showRefreshButton: false)
                            .onTapGesture {
                                // Refresh weather on tap
                                weatherManager.fetchWeather()
                            }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gear")
                                .foregroundColor(DisneyColors.magicBlue)
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(DisneyColors.magicBlue)
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
                .alert(isPresented: $showLogoutAlert) {
                    Alert(
                        title: Text("Sign Out"),
                        message: Text("Are you sure you want to sign out?"),
                        primaryButton: .destructive(Text("Sign Out")) {
                            authViewModel.signOut()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }

            // Loading overlay
            if isInitializing {
                LoadingOverlayView()
            }

            // Error toast
            if !errorMessage.isEmpty {
                ErrorToastView(message: $errorMessage)
            }
        }
        .onAppear {
            // Set up Firebase database structure and generate initial prompt
            setupApp()

            // Fetch weather data
            weatherManager.fetchWeather()
        }
        .onReceive(authViewModel.$errorMessage) { message in
            guard !message.isEmpty else { return }
            errorMessage = message
            authViewModel.errorMessage = ""
        }
    }

    private func setupApp() {
        isInitializing = true

        // First ensure database structure exists
        FirebaseDataService.shared.ensureDatabaseSetup { success in
            if success {
                // Now generate or update the daily prompt
                manager.generateOrUpdateDailyPrompt()

                // Set up notification
                NotificationManager.shared.updateScheduledNotification(basedOn: manager)
            } else {
                errorMessage = "Error setting up database. Please try again."
            }

            isInitializing = false
        }
    }
}

// Loading overlay component
struct LoadingOverlayView: View {
    var body: some View {
        Color.black.opacity(0.4)
            .edgesIgnoringSafeArea(.all)

        VStack {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(DisneyColors.mainStreetGold)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
                .padding()

            Text("Setting up your Disney Daydreams...")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white)
                .padding()
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DisneyColors.magicBlue)
                .shadow(radius: 10)
        )
    }
}

// Error toast component
struct ErrorToastView: View {
    @Binding var message: String

    var body: some View {
        VStack {
            Spacer()

            Text(message)
                .padding()
                .background(DisneyColors.mickeyRed.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 20)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            message = ""
                        }
                    }
                }
        }
        .transition(.move(edge: .bottom))
        .animation(.easeInOut, value: message)
    }
}
