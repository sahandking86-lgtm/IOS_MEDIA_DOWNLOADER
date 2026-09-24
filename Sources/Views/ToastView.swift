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
        // Error toasts (used for the Python bootstrap diagnostic dump) stay
        // up long enough to actually read and don't clip — there's no
        // console to fall back on for a sideloaded build, so this text
        // IS the debugging tool.
        let duration: Double = style == .error ? 20 : 2.6
        Task {
            try? await Task.sleep(for: .seconds(duration))
            guard current?.id == message.id else { return }
            withAnimation(.easeOut(duration: 0.25)) { current = nil }
        }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) { current = nil }
    }
}

struct ToastHost: View {
    var body: some View {
        if let message = ToastCenter.shared.current {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: message.style.symbol)
                    .foregroundStyle(message.style.color)
                Text(message.text)
                    .font(message.style == .error ? .caption : .subheadline)
                    .lineLimit(message.style == .error ? 12 : 2)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .onTapGesture { ToastCenter.shared.dismiss() }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
