import Foundation
import SwiftUI

@Observable
final class QueueViewModel {

    private(set) var items: [DownloadItem] = []
    private let engine: DownloadEngine = YTDLPEngine()
    private var isProcessing = false

    /// Injected by SettingsStore's toggle via ContentView environment reads;
    /// simplest to mirror it here so enqueue() knows how to behave without
    /// threading Settings through every call site.
    var queueModeEnabled = true

    func probeFormats(for link: MediaLink) async throws -> ProbedMedia {
        try await engine.probe(link)
    }

    func enqueue(link: MediaLink, format: VideoFormat) {
        let item = DownloadItem(link: link, format: format)
        withAnimation {
            items.insert(item, at: 0)
        }
        HapticManager.success()

        if queueModeEnabled {
            processQueueIfNeeded()
        } else {
            Task { await run(item) }
        }
    }

    func retry(_ item: DownloadItem) {
        item.status = .queued
        if queueModeEnabled {
            processQueueIfNeeded()
        } else {
            Task { await run(item) }
        }
    }

    func cancel(_ item: DownloadItem) {
        engine.cancel(item.link) // actor call is async but fire-and-forget is fine for a cancel signal
        item.status = .cancelled
        HapticManager.warning()
    }

    func remove(_ item: DownloadItem) {
        withAnimation {
            items.removeAll { $0.id == item.id }
        }
    }

    private func processQueueIfNeeded() {
        guard !isProcessing else { return }
        guard let next = items.first(where: { $0.status == .queued }) else { return }
        isProcessing = true
        Task {
            await run(next)
            isProcessing = false
            processQueueIfNeeded()
        }
    }

    private func run(_ item: DownloadItem) async {
        item.status = .fetchingInfo
        do {
            let fileURL = try await engine.download(item.link, format: item.format) { [weak item] progress, speed in
                Task { @MainActor in
                    item?.status = .downloading(progress: progress, speed: speed)
                }
            }
            item.status = .completed(fileURL: fileURL)
            HapticManager.success()
            ToastCenter.shared.show("\(item.title) saved", style: .success)
        } catch is CancellationError {
            item.status = .cancelled
        } catch let error as DownloadEngineError {
            item.status = .failed(message: error.errorDescription ?? "Download failed")
            HapticManager.error()
        } catch {
            item.status = .failed(message: error.localizedDescription)
            HapticManager.error()
        }
    }
}
