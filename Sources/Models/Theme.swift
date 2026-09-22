import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case sunset, rose, slate, amber, ocean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sunset: "Sunset"
        case .rose: "Rose"
        case .slate: "Slate"
        case .amber: "Amber"
        case .ocean: "Ocean"
        }
    }

    var accent: Color {
        switch self {
        case .sunset: Color(hue: 0.04, saturation: 0.85, brightness: 0.95)
        case .rose: Color(hue: 0.94, saturation: 0.65, brightness: 0.92)
        case .slate: Color(hue: 0.61, saturation: 0.25, brightness: 0.65)
        case .amber: Color(hue: 0.11, saturation: 0.80, brightness: 0.95)
        case .ocean: Color(hue: 0.55, saturation: 0.70, brightness: 0.85)
        }
    }

    private var gradientStops: [Color] {
        switch self {
        case .sunset: [Color(hue: 0.03, saturation: 0.55, brightness: 1.0),
                        Color(hue: 0.95, saturation: 0.45, brightness: 0.98)]
        case .rose:   [Color(hue: 0.95, saturation: 0.35, brightness: 1.0),
                        Color(hue: 0.90, saturation: 0.30, brightness: 0.96)]
        case .slate:  [Color(hue: 0.60, saturation: 0.12, brightness: 0.98),
                        Color(hue: 0.62, saturation: 0.15, brightness: 0.90)]
        case .amber:  [Color(hue: 0.13, saturation: 0.45, brightness: 1.0),
                        Color(hue: 0.09, saturation: 0.40, brightness: 0.97)]
        case .ocean:  [Color(hue: 0.56, saturation: 0.30, brightness: 0.98),
                        Color(hue: 0.60, saturation: 0.35, brightness: 0.92)]
        }
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(colors: gradientStops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var cardMaterial: Material { .ultraThinMaterial }
}
