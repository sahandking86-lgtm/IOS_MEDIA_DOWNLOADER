import Foundation

enum SourcePlatform: String, Codable {
    case youtube, tiktok, facebook, instagram, twitter, unknown

    var displayName: String {
        switch self {
        case .youtube: "YouTube"
        case .tiktok: "TikTok"
        case .facebook: "Facebook"
        case .instagram: "Instagram"
        case .twitter: "X / Twitter"
        case .unknown: "Unknown"
        }
    }

    var symbolName: String {
        switch self {
        case .youtube: "play.rectangle.fill"
        case .tiktok: "music.note"
        case .facebook: "f.circle.fill"
        case .instagram: "camera.circle.fill"
        case .twitter: "at.circle.fill"
        case .unknown: "link.circle.fill"
        }
    }
}

struct MediaLink: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let platform: SourcePlatform

    init?(rawURL: String) {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else { return nil }
        self.url = url
        self.platform = Self.detect(host: host)
        guard platform != .unknown else { return nil }
    }

    private static func detect(host: String) -> SourcePlatform {
        if host.contains("youtube.com") || host.contains("youtu.be") { return .youtube }
        if host.contains("tiktok.com") { return .tiktok }
        if host.contains("facebook.com") || host.contains("fb.watch") { return .facebook }
        if host.contains("instagram.com") { return .instagram }
        if host.contains("twitter.com") || host.contains("x.com") { return .twitter }
        return .unknown
    }
}
