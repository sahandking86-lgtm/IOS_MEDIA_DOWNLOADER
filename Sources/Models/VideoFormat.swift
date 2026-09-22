import Foundation

struct VideoFormat: Identifiable, Hashable {
    let id: String              // yt-dlp format_id
    let label: String           // "1080p" / "Audio · 256 kbps"
    let isAudioOnly: Bool
    let approxSizeMB: Double?
    let ext: String

    /// Sentinel used when the user has "Don't ask for preferences" enabled —
    /// resolved to the true best video+audio combo inside the engine.
    static let bestAvailable = VideoFormat(
        id: "bestvideo+bestaudio/best",
        label: "Best available",
        isAudioOnly: false,
        approxSizeMB: nil,
        ext: "mp4"
    )
}

struct ProbedMedia: Identifiable {
    var id: UUID { link.id }
    let link: MediaLink
    let title: String
    let thumbnailURL: URL?
    let durationSeconds: Int?
    let formats: [VideoFormat]
}
