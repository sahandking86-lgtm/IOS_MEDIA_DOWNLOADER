import SwiftUI

struct FormatPickerSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let probed: ProbedMedia
    var onPick: (VideoFormat) -> Void

    private var videoFormats: [VideoFormat] { probed.formats.filter { !$0.isAudioOnly } }
    private var audioFormats: [VideoFormat] { probed.formats.filter { $0.isAudioOnly } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        AsyncImage(url: probed.thumbnailURL) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Rectangle().fill(.quaternary)
                            }
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(probed.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            if let duration = probed.durationSeconds {
                                Text(formatted(duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                if !videoFormats.isEmpty {
                    Section("Video + Audio") {
                        ForEach(videoFormats) { format in
                            formatRow(format)
                        }
                    }
                }

                if !audioFormats.isEmpty {
                    Section("Audio Only") {
                        ForEach(audioFormats) { format in
                            formatRow(format)
                        }
                    }
                }
            }
            .navigationTitle("Choose Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func formatRow(_ format: VideoFormat) -> some View {
        Button {
            HapticManager.tap()
            onPick(format)
        } label: {
            HStack {
                Text(format.label)
                    .foregroundStyle(.primary)
                Spacer()
                if let size = format.approxSizeMB {
                    Text(String(format: "%.0f MB", size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func formatted(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
