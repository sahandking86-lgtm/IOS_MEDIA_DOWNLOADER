# VideoDownloader (personal-use, SwiftUI + yt-dlp)

A SwiftUI iOS app scaffold: paste a link (YouTube / TikTok / Facebook /
Instagram / X), pick a quality in a HIG-style bottom sheet, download with a
live progress queue. Built to compile via XcodeGen + a GitHub Actions
`macos-latest` runner into a sideloadable `.ipa`.

## What's actually in this scaffold

- Full SwiftUI app: link input, animated queue list, format-picker sheet,
  settings (skip-prompt toggle, queue-mode toggle, save destination, 5
  themes, appearance), haptics, floating toasts, glassmorphism cards.
- `@Observable` ViewModels (`QueueViewModel`, `SettingsStore`) + Swift
  Concurrency throughout — no engine work happens on the main thread.
- A `DownloadEngine` protocol so the UI never depends on the extraction
  internals, plus a `YTDLPEngine` implementation written against
  **PythonKit**, ready to drive the real `yt_dlp` module once it's bundled.
- `project.yml` (XcodeGen) wiring up PythonKit and ffmpeg-kit-ios as Swift
  Package dependencies, and `.github/workflows/build.yml` that generates
  the Xcode project and archives an unsigned `.ipa` on every push.

## What you still need to add — and why

I can generate all the Swift/config code, but I can't produce the actual
**compiled binary frameworks** this app depends on (a Python runtime built
for iOS, and yt-dlp's own Python source) — those are large prebuilt
artifacts you fetch, not source code. Two things are still needed before
`YTDLPEngine` will run for real:

1. **An iOS-compiled Python runtime.** [Python-Apple-support](https://github.com/beeware/Python-Apple-support)
   publishes `Python.xcframework` releases you can drop into `Frameworks/`
   and reference from `project.yml`. `PythonKit` (already a dependency)
   talks to it via `PYTHONHOME`, set at launch — add that bootstrap call
   near the top of `VideoDownloaderApp.init()`.
2. **yt-dlp itself**, as a pure-Python source tree copied into
   `Resources/ytdlp-site-packages` (e.g. `pip download yt-dlp --no-deps -d
   Resources/ytdlp-site-packages`), which `YTDLPEngine` adds to `sys.path`
   on first use.

`FFmpegService` is stubbed the same way: `ffmpeg-kit-ios` is declared as a
package dependency, but the actual mux/extract calls (commented out) need
uncommenting once the package resolves in your Xcode project, and yt-dlp's
`ffmpeg_location` needs pointing at a small shim executable that forwards
into FFmpegKit in-process (iOS apps can't spawn subprocesses).

Both are called out inline as `TODO`s / doc comments at the exact call
sites (`YTDLPEngine.swift`, `FFmpegService.swift`, `build.yml`).

## Building locally

```bash
brew install xcodegen
xcodegen generate
open VideoDownloader.xcodeproj
```

## Building via CI

Push to `main` (or run the workflow manually) — `.github/workflows/build.yml`
generates the project, resolves packages, archives unsigned, and uploads
`VideoDownloader.ipa` as a workflow artifact. It's unsigned, so sideloading
still requires re-signing with your own Apple ID/certificate (AltStore,
Sideloadly, or a paid developer account) — GitHub Actions can't sign with
your personal credentials for you, and doing so isn't something to wire
into a public CI file anyway.

## A note on scope

This is a personal media tool. Downloading from these platforms may
conflict with their individual Terms of Service even when done for
personal, non-redistributed use — that's a call for you to make per
platform, not something this scaffold enforces or bypasses.
