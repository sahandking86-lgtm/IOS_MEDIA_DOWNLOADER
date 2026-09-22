import SwiftUI

enum ToastStyle {
    case success, error, info

    var color: Color {
        switch self {
        case .success: .green
        case .error: .red
        case .info: .primary
        }
    }

    var symbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let style: ToastStyle

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool { lhs.id == rhs.id }
}

/// Simple observable singleton so any layer (ViewModel, Repository) can
/// surface a non-jarring floating toast without threading a binding
/// through every call site — deliberately lightweight, not a full event bus.
@Observable
final class ToastCenter {
    static let shared = ToastCenter()
    private init() {}

    var current: ToastMessage?

    func show(_ text: String, style: ToastStyle = .info) {
        let message = ToastMessage(text: text, style: style)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            current = message
        }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard current?.id == message.id else { return }
            withAnimation(.easeOut(duration: 0.25)) { current = nil }
        }
    }
}

struct ToastHost: View {
    var body: some View {
        if let message = ToastCenter.shared.current {
            HStack(spacing: 8) {
                Image(systemName: message.style.symbol)
                    .foregroundStyle(message.style.color)
                Text(message.text)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: .capsule)
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
