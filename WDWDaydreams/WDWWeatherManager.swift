import Foundation
import Combine
import SwiftUI

class WDWWeatherManager: ObservableObject {
    @Published var weatherIcon: String = "cloud.sun"
    @Published var temperature: String = "--°"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var lastUpdated: Date?
    
    private var cancellable: AnyCancellable?
    
    // Get weather for Walt Disney World (Orlando area)
    func fetchWeather() {
        isLoading = true
        errorMessage = ""
        
        let apiKey = "ee8e9e609121b1c94d07c64379c612d4" // Replace with your own API key from OpenWeatherMap
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
                    self?.errorMessage = "Weather error: \(error.localizedDescription)"
                    print("Weather fetch error: \(error)")
                }
            }, receiveValue: { [weak self] response in
                self?.weatherIcon = self?.mapIcon(from: response.weather.first?.icon ?? "") ?? "cloud.sun"
                self?.temperature = "\(Int(response.main.temp))°F"
                self?.lastUpdated = Date()
                self?.isLoading = false
            })
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
