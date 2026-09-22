import SwiftUI

struct QueueRowView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(QueueViewModel.self) private var queue
    @Bindable var item: DownloadItem

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: item.link.platform.symbolName)
                        .font(.caption2)
                    Text(item.link.platform.displayName)
                    Text("·")
                    Text(item.format.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                statusRow
            }

            Spacer(minLength: 0)

            actionButton
        }
        .padding(12)
        .background(settings.theme.cardMaterial, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
            if let url = item.thumbnailURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            } else {
                Image(systemName: item.link.platform.symbolName)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var statusRow: some View {
        switch item.status {
        case .queued:
            Text("Waiting…")
                .font(.caption2)
                .foregroundStyle(.tertiary)

        case .fetchingInfo:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Preparing…")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

        case .downloading(let progress, let speed):
            VStack(alignment: .leading, spacing: 3) {
                ProgressBar(progress: progress, tint: settings.theme.accent)
                    .frame(height: 4)
                HStack {
                    Text("\(Int(progress * 100))%")
                    if let speed { Text("· \(speed)") }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

        case .merging:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Merging audio & video…")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

        case .completed:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(1)

        case .cancelled:
            Label("Cancelled", systemImage: "xmark.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch item.status {
        case .downloading, .fetchingInfo, .merging:
            Button {
                HapticManager.tap()
                queue.cancel(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }

        case .failed, .cancelled:
            Button {
                HapticManager.tap()
                queue.retry(item)
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(settings.theme.accent)
            }

        case .completed:
            Button {
                HapticManager.tap()
                queue.remove(item)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.tertiary)
        }
    }
}

/// Lightweight animated progress bar (rather than the default ProgressView
/// style) so it can pick up the active theme's accent color smoothly.
private struct ProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: geo.size.width * max(0, min(progress, 1)))
                    .animation(.easeOut(duration: 0.25), value: progress)
            }
        }
        .clipShape(Capsule())
    }
}
