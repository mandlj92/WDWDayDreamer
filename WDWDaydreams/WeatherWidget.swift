import SwiftUI

// Create a reusable weather widget component
struct WeatherWidget: View {
    @ObservedObject var weatherManager: WDWWeatherManager
    @Environment(\.theme) var theme: Theme
    var showRefreshButton: Bool = true
    
    var body: some View {
        HStack(spacing: 8) {
            // Weather icon with theme color
            Image(systemName: weatherManager.weatherIcon)
                .font(.system(size: 20))
                .foregroundColor(weatherManager.weatherColor())
                .shadow(color: Color.black.opacity(0.1), radius: 1)
            
            // Temperature with Disney styling
            Text(weatherManager.temperature)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(theme.magicBlue)
            
            // Optional refresh button
            if showRefreshButton {
                Button(action: {
                    weatherManager.fetchWeather()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(theme.magicBlue)
                        .opacity(weatherManager.isLoading ? 0.5 : 1.0)
                        .rotationEffect(weatherManager.isLoading ? .degrees(360) : .degrees(0))
                        .animation(weatherManager.isLoading ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: weatherManager.isLoading)
                }
                .disabled(weatherManager.isLoading)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.mainStreetGold.opacity(0.5), lineWidth: 1)
        )
    }
}

// Add a preview for the WeatherWidget
struct WeatherWidget_Previews: PreviewProvider {
    static var previews: some View {
        WeatherWidget(weatherManager: WDWWeatherManager())
            .padding()
            .background(DisneyColors.backgroundCream)
            .environment(\.theme, LightTheme())
    }
}
