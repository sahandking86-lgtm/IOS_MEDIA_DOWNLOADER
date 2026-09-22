import Foundation

enum DownloadStatus: Equatable {
    case queued
    case fetchingInfo
    case downloading(progress: Double, speed: String?)
    case merging
    case completed(fileURL: URL)
    case failed(message: String)
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: true
        default: false
        }
    }
}

@Observable
final class DownloadItem: Identifiable {
    let id = UUID()
    let link: MediaLink
    let format: VideoFormat
    var title: String
    var thumbnailURL: URL?
    var status: DownloadStatus = .queued

    init(link: MediaLink, format: VideoFormat, title: String? = nil, thumbnailURL: URL? = nil) {
        self.link = link
        self.format = format
        self.title = title ?? link.url.absoluteString
        self.thumbnailURL = thumbnailURL
    }
}
