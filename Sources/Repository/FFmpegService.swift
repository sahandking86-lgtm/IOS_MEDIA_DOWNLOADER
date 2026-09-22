import Foundation

/// Thin wrapper around FFmpegKit. yt-dlp shells out to an `ffmpeg` binary
/// for merging separate video/audio streams and for audio extraction —
/// since iOS apps can't spawn arbitrary subprocesses, `ffmpeg_location`
/// is pointed at a small shim that forwards into FFmpegKit's in-process
/// FFmpeg instead (see README.md "FFmpeg integration").
struct FFmpegService {

    /// Path to the shim executable/script yt-dlp is configured to invoke.
    /// Populated at build time by the Run Script phase described in the
    /// README; falls back to the bundled binary name for local debugging.
    static var binaryPath: String {
        Bundle.main.path(forResource: "ffmpeg-shim", ofType: nil)
            ?? "/usr/bin/env ffmpeg"
    }

    /// Extracts audio only (used for the "Audio only" quick action on a
    /// completed video download) via FFmpegKit directly, bypassing yt-dlp.
    func extractAudio(from videoURL: URL, to destination: URL) async throws {
        // FFmpegKit.execute("-i \"\(videoURL.path)\" -vn -acodec aac \"\(destination.path)\"")
        // Left as an integration point — wire up once ffmpeg-kit-ios is
        // resolved via SPM (see project.yml packages).
        throw DownloadEngineError.extractionFailed("FFmpegKit not yet linked in this build target.")
    }
}
