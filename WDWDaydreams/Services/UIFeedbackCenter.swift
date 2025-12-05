import Foundation
import SwiftUI

enum FeedbackStyle {
    case info
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct FeedbackBanner: Identifiable {
    let id = UUID()
    let message: String
    let style: FeedbackStyle
}

final class UIFeedbackCenter: ObservableObject {
    @Published var currentBanner: FeedbackBanner?

    func present(message: String, style: FeedbackStyle = .info) {
        DispatchQueue.main.async {
            self.currentBanner = FeedbackBanner(message: message, style: style)
        }
    }
}

struct FeedbackBannerView: View {
    @Binding var banner: FeedbackBanner?

    var body: some View {
        VStack {
            Spacer()
            if let currentBanner = banner {
                Text(currentBanner.message)
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(currentBanner.style.color.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                self.banner = nil
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: banner)
    }
}
