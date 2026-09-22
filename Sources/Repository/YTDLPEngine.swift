import Foundation
import PythonKit

/// Runs the bundled yt-dlp (pure-Python) inside an embedded CPython runtime
/// via PythonKit, off the main thread, behind an actor so all Python calls
/// are serialized (CPython's GIL makes concurrent calls unsafe anyway).
///
/// Setup this relies on (see README.md "Native yt-dlp engine"):
///   1. Python.xcframework embedded in the app bundle (e.g. via
///      https://github.com/beeware/Python-Apple-support) and
///      PYTHONHOME pointed at its Resources/lib/python3.x.
///   2. yt-dlp's pure-Python source tree bundled as an app resource and
///      added to `sys.path` at launch (`Resources/ytdlp-site-packages`).
///   3. FFmpegKit (via FFmpegService) available on PATH-equivalent so
///      yt-dlp's postprocessors can shell out to it for muxing.
actor YTDLPEngine: DownloadEngine {

    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private var cancelledLinks: Set<UUID> = []
    private let ffmpeg = FFmpegService()

    private static let bootstrapped: Bool = {
        guard let resourcePath = Bundle.main.path(forResource: "ytdlp-site-packages", ofType: nil) else {
            return false
        }
        let sys = Python.import("sys")
        sys.path.append(resourcePath)
        return true
    }()

    func probe(_ link: MediaLink) async throws -> ProbedMedia {
        guard Self.bootstrapped else {
            throw DownloadEngineError.extractionFailed("yt-dlp runtime isn't bundled in this build.")
        }

        let ytdlp = Python.import("yt_dlp")
        let options: PythonObject = [
            "quiet": true,
            "no_warnings": true,
            "skip_download": true,
        ]

        return try Task.detached(priority: .userInitiated) {
            let extractor = ytdlp.YoutubeDL(options)
            let info = try extractor.extract_info.dynamicallyCall(
                withKeywordArguments: ["url": link.url.absoluteString, "download": false]
            )

            let title = String(info["title"]) ?? link.url.absoluteString
            let thumbnail = (String(info["thumbnail"])).flatMap(URL.init(string:))
            let duration = Int(info["duration"])

            var formats: [VideoFormat] = []
            if let rawFormats = Array(info["formats"]) {
                for raw in rawFormats {
                    guard let id = String(raw["format_id"]) else { continue }
                    let hasVideo = raw["vcodec"] != Python.None && String(raw["vcodec"]) != "none"
                    let hasAudio = raw["acodec"] != Python.None && String(raw["acodec"]) != "none"
                    let height = Int(raw["height"])
                    let abr = Double(raw["abr"])
                    let sizeMB = Double(raw["filesize"]).map { $0 / 1_048_576 }
                    let ext = String(raw["ext"]) ?? "mp4"

                    let label: String
                    if hasVideo {
                        label = height.map { "\($0)p" } ?? "Video · \(ext)"
                    } else if hasAudio {
                        label = abr.map { "Audio · \(Int($0)) kbps" } ?? "Audio · \(ext)"
                    } else {
                        continue
                    }

                    formats.append(VideoFormat(
                        id: id,
                        label: label,
                        isAudioOnly: hasAudio && !hasVideo,
                        approxSizeMB: sizeMB,
                        ext: ext
                    ))
                }
            }

            return ProbedMedia(link: link, title: title, thumbnailURL: thumbnail,
                                durationSeconds: duration, formats: formats)
        }.value
    }

    func download(
        _ link: MediaLink,
        format: VideoFormat,
        onProgress: @escaping @Sendable (Double, String?) -> Void
    ) async throws -> URL {
        guard Self.bootstrapped else {
            throw DownloadEngineError.extractionFailed("yt-dlp runtime isn't bundled in this build.")
        }
        cancelledLinks.remove(link.id)

        let destinationDir = try DownloadPaths.documentsSubdirectory("Downloads")
        let outputTemplate = destinationDir.appendingPathComponent("%(title)s.%(ext)s").path

        return try await Task.detached(priority: .userInitiated) { [weak self] in
            let ytdlp = Python.import("yt_dlp")

            let progressHook = PythonInstanceMethod { args in
                guard let status = args.first else { return Python.None }
                let state = String(status["status"]) ?? ""
                if state == "downloading" {
                    let downloaded = Double(status["downloaded_bytes"]) ?? 0
                    let total = Double(status["total_bytes"]) ?? Double(status["total_bytes_estimate"]) ?? 1
                    let speed = (String(status["_speed_str"])) ?? nil
                    onProgress(min(downloaded / max(total, 1), 1.0), speed)
                }
                return Python.None
            }

            let options: PythonObject = [
                "format": PythonObject(format.id),
                "outtmpl": PythonObject(outputTemplate),
                "quiet": true,
                "no_warnings": true,
                "progress_hooks": PythonObject([PythonObject(progressHook)]),
                "merge_output_format": "mp4",
                "ffmpeg_location": PythonObject(FFmpegService.binaryPath),
            ]

            let extractor = ytdlp.YoutubeDL(options)
            _ = try extractor.extract_info.dynamicallyCall(
                withKeywordArguments: ["url": link.url.absoluteString, "download": true]
            )

            guard await self?.cancelledLinks.contains(link.id) != true else {
                throw DownloadEngineError.cancelled
            }

            guard let finalURL = try FileManager.default
                .contentsOfDirectory(at: destinationDir, includingPropertiesForKeys: [.contentModificationDateKey])
                .max(by: { lhs, rhs in
                    let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                    let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                    return l < r
                })
            else {
                throw DownloadEngineError.extractionFailed("Download finished but the output file couldn't be located.")
            }
            return finalURL
        }.value
    }

    func cancel(_ link: MediaLink) {
        cancelledLinks.insert(link.id)
        activeTasks[link.id]?.cancel()
        activeTasks[link.id] = nil
    }
}

enum DownloadPaths {
    static func documentsSubdirectory(_ name: String) throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = docs.appendingPathComponent(name, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
