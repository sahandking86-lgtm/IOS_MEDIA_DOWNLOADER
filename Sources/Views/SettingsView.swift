import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            List {
                Section("Downloading") {
                    Toggle("Don't ask for preferences", isOn: $settings.skipPreferencePrompt)
                    Text("Grabs the best available quality with audio automatically, skipping the format sheet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Queue mode", isOn: $settings.queueModeEnabled)
                    Text("When off, every pasted link starts downloading immediately instead of waiting in line.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Saving") {
                    Picker("Save to", selection: $settings.saveDestination) {
                        ForEach(SaveDestination.allCases) { destination in
                            Text(destination.label).tag(destination)
                        }
                    }
                }

                Section("Appearance") {
                    ThemePickerView(selection: $settings.theme)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)

                    Toggle("Match system appearance", isOn: $settings.useSystemAppearance)
                }

                Section {
                    Label("Personal use only. Please respect each platform's terms of service and applicable copyright law.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
