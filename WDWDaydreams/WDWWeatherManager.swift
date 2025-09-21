import Foundation
import Combine
import SwiftUI
import FirebaseRemoteConfig

class WDWWeatherManager: ObservableObject {
    @Published var weatherIcon: String = "cloud.sun"
    @Published var temperature: String = "--°"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var lastUpdated: Date?
    
    private var cancellable: AnyCancellable?
    private var remoteConfig: RemoteConfig
    private var apiKey: String = ""
    
    init() {
        // Initialize Firebase Remote Config
        remoteConfig = RemoteConfig.remoteConfig()
        
        // Set default values for Remote Config
        let defaults: [String: NSObject] = [
            "weather_api_key": "" as NSString // Empty default - must be set in Firebase console
        ]
        remoteConfig.setDefaults(defaults)
        
        // Configure Remote Config settings for development
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0 // Allow immediate fetching in debug builds
        #else
        settings.minimumFetchInterval = 3600 // 1 hour minimum in production
        #endif
        remoteConfig.configSettings = settings
        
        // Fetch the API key on initialization
        fetchRemoteConfig()
    }
    
    private func fetchRemoteConfig() {
        print("🔧 Fetching Remote Config...")
        
        remoteConfig.fetch { [weak self] status, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Remote Config fetch error: \(error.localizedDescription)")
                // You might want to fall back to a cached value or show an error
                DispatchQueue.main.async {
                    self.errorMessage = "Configuration error. Please check your connection."
                }
                return
            }
            
            // Activate the fetched config
            self.remoteConfig.activate { [weak self] changed, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Remote Config activation error: \(error.localizedDescription)")
                    return
                }
                
                // Get the API key from Remote Config
                let configValue = self.remoteConfig["weather_api_key"].stringValue
                
                if configValue.isEmpty {
                    print("⚠️ Weather API key not found in Remote Config")
                    self.apiKey = ""
                    DispatchQueue.main.async {
                        self.errorMessage = "Weather service not configured"
                    }
                } else {
                    print("✅ Weather API key loaded from Remote Config: \(configValue.prefix(8))...")
                    self.apiKey = configValue
                    // Clear any previous configuration errors
                    DispatchQueue.main.async {
                        if self.errorMessage == "Configuration error. Please check your connection." ||
                           self.errorMessage == "Weather service not configured" {
                            self.errorMessage = ""
                        }
                    }
                }
            }
        }
    }
    
    // Get weather for Walt Disney World (Orlando area)
    func fetchWeather() {
        // Ensure we have an API key before making the request
        guard !apiKey.isEmpty else {
            print("⚠️ Cannot fetch weather: API key not available")
            DispatchQueue.main.async {
                self.errorMessage = "Weather service not configured"
            }
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        let lat = 28.3852 // Disney World coordinates
        let lon = -81.5639
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&units=imperial&appid=\(apiKey)"

        guard let url = URL(string: urlString) else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }

        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: WeatherResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    // Check for specific API errors
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            self?.errorMessage = "No internet connection"
                        case .timedOut:
                            self?.errorMessage = "Request timed out"
                        default:
                            self?.errorMessage = "Network error"
                        }
                    } else {
                        self?.errorMessage = "Weather data unavailable"
                    }
                    print("Weather fetch error: \(error)")
                }
            }, receiveValue: { [weak self] response in
                self?.weatherIcon = self?.mapIcon(from: response.weather.first?.icon ?? "") ?? "cloud.sun"
                self?.temperature = "\(Int(response.main.temp))°F"
                self?.lastUpdated = Date()
                self?.isLoading = false
                self?.errorMessage = "" // Clear any previous errors
            })
    }
    
    // Public method to refresh Remote Config (useful for settings or manual refresh)
    func refreshConfiguration() {
        fetchRemoteConfig()
    }

    // Add a method to get a themed weather color based on the current conditions
    func weatherColor() -> Color {
        switch weatherIcon {
        case "sun.max.fill":
            return DisneyColors.mainStreetGold
        case "cloud.sun.fill", "cloud.moon.fill":
            return DisneyColors.tomorrowlandSilver.opacity(0.8)
        case "cloud.fill", "smoke.fill":
            return DisneyColors.tomorrowlandSilver
        case "cloud.drizzle.fill", "cloud.rain.fill":
            return DisneyColors.magicBlue
        case "cloud.bolt.rain.fill":
            return DisneyColors.fantasyPurple
        case "cloud.snow.fill":
            return Color.white
        case "cloud.fog.fill":
            return DisneyColors.tomorrowlandSilver.opacity(0.5)
        default:
            return DisneyColors.mainStreetGold
        }
    }

    private func mapIcon(from apiIcon: String) -> String {
        switch apiIcon {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.stars.fill"
        case "02d": return "cloud.sun.fill"
        case "02n": return "cloud.moon.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d", "10n": return "cloud.rain.fill"
        case "11d", "11n": return "cloud.bolt.rain.fill"
        case "13d", "13n": return "cloud.snow.fill"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.sun.fill"
        }
    }
    
    // Convenience method to check if we should refresh
    func shouldRefreshWeather() -> Bool {
        // Refresh if we haven't fetched weather yet
        guard let lastUpdated = lastUpdated else {
            return true
        }
        
        // Refresh if it's been more than 30 minutes
        let thirtyMinutesAgo = Date().addingTimeInterval(-30 * 60)
        return lastUpdated < thirtyMinutesAgo
    }
}

struct WeatherResponse: Codable {
    struct Weather: Codable {
        let icon: String
    }
    struct Main: Codable {
        let temp: Double
    }
    let weather: [Weather]
    let main: Main
}
