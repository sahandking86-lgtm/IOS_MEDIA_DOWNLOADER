import SwiftUI

@main
struct VideoDownloaderApp: App {

    @State private var settings = SettingsStore()
    @State private var queue = QueueViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(queue)
                .preferredColorScheme(settings.colorSchemeOverride)
                .tint(settings.theme.accent)
        }
    }
}
