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

struct FeedbackBanner: Identifiable, Equatable {
    let id: UUID
    let message: String
    let style: FeedbackStyle
    let duration: TimeInterval
    let retryAction: (() -> Void)?

    init(message: String, style: FeedbackStyle, duration: TimeInterval = 5.0, retryAction: (() -> Void)? = nil) {
        self.id = UUID()
        self.message = message
        self.style = style
        self.duration = duration
        self.retryAction = retryAction
    }

    static func == (lhs: FeedbackBanner, rhs: FeedbackBanner) -> Bool {
        lhs.id == rhs.id
    }
}

final class UIFeedbackCenter: ObservableObject {
    @Published var currentBanner: FeedbackBanner?
    private var dismissTask: Task<Void, Never>?

    // Shared singleton for easy access from services
    static let shared = UIFeedbackCenter()

    private init() {}

    func present(message: String, style: FeedbackStyle = .info, duration: TimeInterval = 5.0, retryAction: (() -> Void)? = nil) {
        dismissTask?.cancel()

        let banner = FeedbackBanner(
            message: message,
            style: style,
            duration: duration,
            retryAction: retryAction
        )

        DispatchQueue.main.async {
            self.currentBanner = banner

            // Auto-dismiss after duration (unless it's an error with retry)
            if style != .error || retryAction == nil {
                self.dismissTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                    await MainActor.run {
                        if self.currentBanner?.id == banner.id {
                            self.currentBanner = nil
                        }
                    }
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        currentBanner = nil
    }
}

struct FeedbackBannerView: View {
    @Binding var banner: FeedbackBanner?

    var body: some View {
        VStack {
            Spacer()
            if let currentBanner = banner {
                HStack {
                    Image(systemName: iconName(for: currentBanner.style))
                        .foregroundColor(.white)

                    Text(currentBanner.message)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Spacer()

                    if let retryAction = currentBanner.retryAction {
                        Button("Retry") {
                            retryAction()
                            withAnimation {
                                banner = nil
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                    }

                    Button(action: {
                        withAnimation {
                            UIFeedbackCenter.shared.dismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                .background(currentBanner.style.color.opacity(0.9))
                .cornerRadius(12)
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: banner)
    }

    private func iconName(for style: FeedbackStyle) -> String {
        switch style {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}
