import Foundation

/// Abstraction over "whatever actually talks to yt-dlp". Kept as a protocol
/// so the UI/ViewModel layer never depends on PythonKit directly, and so a
/// mock engine can back SwiftUI previews and unit tests.
protocol DownloadEngine: Sendable {
    /// Fetches title, thumbnail, duration, and the real list of available
    /// formats for a link, without downloading anything.
    func probe(_ link: MediaLink) async throws -> ProbedMedia

    /// Downloads (and, when needed, muxes) the given format, streaming
    /// progress updates back to the caller. Returns the final file URL on
    /// disk inside the app's Documents directory.
    func download(
        _ link: MediaLink,
        format: VideoFormat,
        onProgress: @escaping @Sendable (Double, String?) -> Void
    ) async throws -> URL

    func cancel(_ link: MediaLink) async
}

enum DownloadEngineError: LocalizedError {
    case extractionFailed(String)
    case unsupportedPlatform
    case networkUnavailable
    case diskSpaceLow
    case cancelled

    var errorDescription: String? {
        switch self {
        case .extractionFailed(let reason): reason
        case .unsupportedPlatform: "This link's platform isn't supported yet."
        case .networkUnavailable: "No network connection."
        case .diskSpaceLow: "Not enough free storage to finish this download."
        case .cancelled: "Download cancelled."
        }
    }
}
