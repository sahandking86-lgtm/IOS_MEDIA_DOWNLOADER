import SwiftUI

enum SaveDestination: String, CaseIterable, Identifiable, Codable {
    case documentsOnly, documentsAndPhotos
    var id: String { rawValue }

    var label: String {
        switch self {
        case .documentsOnly: "Files app only"
        case .documentsAndPhotos: "Files app + Photos Library"
        }
    }
}

@Observable
final class SettingsStore {

    var skipPreferencePrompt: Bool {
        didSet { UserDefaults.standard.set(skipPreferencePrompt, forKey: Keys.skipPrompt) }
    }
    var queueModeEnabled: Bool {
        didSet { UserDefaults.standard.set(queueModeEnabled, forKey: Keys.queueMode) }
    }
    var saveDestination: SaveDestination {
        didSet { UserDefaults.standard.set(saveDestination.rawValue, forKey: Keys.saveDestination) }
    }
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }
    var useSystemAppearance: Bool {
        didSet { UserDefaults.standard.set(useSystemAppearance, forKey: Keys.systemAppearance) }
    }

    var colorSchemeOverride: ColorScheme? { useSystemAppearance ? nil : .dark }

    private enum Keys {
        static let skipPrompt = "settings.skipPreferencePrompt"
        static let queueMode = "settings.queueModeEnabled"
        static let saveDestination = "settings.saveDestination"
        static let theme = "settings.theme"
        static let systemAppearance = "settings.useSystemAppearance"
    }

    init() {
        let d = UserDefaults.standard
        skipPreferencePrompt = d.bool(forKey: Keys.skipPrompt)
        queueModeEnabled = d.object(forKey: Keys.queueMode) == nil ? true : d.bool(forKey: Keys.queueMode)
        saveDestination = SaveDestination(rawValue: d.string(forKey: Keys.saveDestination) ?? "") ?? .documentsOnly
        theme = AppTheme(rawValue: d.string(forKey: Keys.theme) ?? "") ?? .ocean
        useSystemAppearance = d.object(forKey: Keys.systemAppearance) == nil ? true : d.bool(forKey: Keys.systemAppearance)
    }
}
