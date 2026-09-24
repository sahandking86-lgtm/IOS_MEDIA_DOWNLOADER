import Foundation
import PythonKit

/// Runs the bundled yt-dlp (pure-Python) inside an embedded CPython runtime
/// via PythonKit, off the main thread, behind an actor so all Python calls
/// are serialized (CPython's GIL makes concurrent calls unsafe anyway).
actor YTDLPEngine: DownloadEngine {

    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private var cancelledLinks: Set<UUID> = []
    private let ffmpeg = FFmpegService()

    /// Replaces the plain Bool bootstrap check: on failure this carries a
    /// human-readable dump of what's actually inside the app bundle, which
    /// gets threaded through to the on-screen error toast. There's no way
    /// to attach an Xcode console to a sideloaded/LiveContainer install, so
    /// this is the only debugging channel available — make it count.
    private static let bootstrapStatus: String = {
        let bundlePath = Bundle.main.bundlePath
        var lines: [String] = ["bundle: \(bundlePath)"]

        let topLevel = (try? FileManager.default.contentsOfDirectory(atPath: bundlePath))?.sorted() ?? []
        lines.append("top-level (\(topLevel.count)): \(topLevel.joined(separator: ", "))")

        let pythonHome = bundlePath + "/python"
        let pythonExists = FileManager.default.fileExists(atPath: pythonHome)
        lines.append("python/ exists: \(pythonExists)")
        if pythonExists {
            let pythonContents = (try? FileManager.default.contentsOfDirectory(atPath: pythonHome))?.sorted() ?? []
            lines.append("python/ contents: \(pythonContents.joined(separator: ", "))")
        }

        guard pythonExists else {
            return "MISSING python/ — " + lines.joined(separator: " | ")
        }
        setenv("PYTHONHOME", pythonHome, 1)

        // Copied directly into the bundle root by a postbuildScript (see
        // project.yml) rather than relying on Xcode's resource bundling,
        // which wasn't reliably including this folder.
        let resourcePath = bundlePath + "/ytdlp-site-packages"
        let resourceExists = FileManager.default.fileExists(atPath: resourcePath)
        lines.append("ytdlp-site-packages/ exists: \(resourceExists)")

        guard resourceExists else {
            return "MISSING ytdlp-site-packages — " + lines.joined(separator: " | ")
        }

        // PythonKit's `Python.import(_:)` is throwing in the current
        // release (`try Python.import("sys")` per its own README) — used
        // without `try` it silently falls back to a legacy variant that
        // crashes the whole process on failure instead of raising a
        // catchable error. Using `try`/`do`/`catch` here turns that crash
        // into a readable message in this diagnostic string instead.
        do {
            let sys = try Python.import("sys")
            sys.path.append(resourcePath)
        } catch {
            return "PYTHON IMPORT FAILED (sys) — \(error) | " + lines.joined(separator: " | ")
        }
        return "OK"
    }()

    private static var bootstrapped: Bool { bootstrapStatus == "OK" }

    func probe(_ link: MediaLink) async throws -> ProbedMedia {
        guard Self.bootstrapped else {
            throw DownloadEngineError.extractionFailed(Self.bootstrapStatus)
        }

        let ytdlp: PythonObject
        do {
            ytdlp = try Python.import("yt_dlp")
        } catch {
            throw DownloadEngineError.extractionFailed("yt_dlp import failed: \(error)")
        }
        let options: PythonObject = [
            "quiet": true,
            "no_warnings": true,
            "skip_download": true,
        ]

        return try await Task.detached(priority: .userInitiated) {
            let extractor = ytdlp.YoutubeDL(options)
            let info = try extractor.extract_info.dynamicallyCall(
                withKeywordArguments: ["url": link.url.absoluteString, "download": false]
            )

            let title = String(info["title"]) ?? link.url.absoluteString
            let thumbnail = (String(info["thumbnail"])).flatMap(URL.init(string:))
            let duration = Int(info["duration"])

            var formats: [VideoFormat] = []
            let rawFormats = Array(info["formats"])
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
            throw DownloadEngineError.extractionFailed(Self.bootstrapStatus)
        }
        cancelledLinks.remove(link.id)

        let destinationDir = try DownloadPaths.documentsSubdirectory("Downloads")
        let outputTemplate = destinationDir.appendingPathComponent("%(title)s.%(ext)s").path

        return try await Task.detached(priority: .userInitiated) { [weak self] in
            let ytdlp = try Python.import("yt_dlp")

            let progressHook = PythonFunction { (args: [PythonObject]) -> PythonConvertible in
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
