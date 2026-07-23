import AppKit
import ScreenCaptureKit
import Vision

/// Reads the frontmost window into words, on this Mac only: one
/// ScreenCaptureKit shot, one Vision pass, and the text joins the
/// ask pipeline like any dropped file. Nothing is stored and nothing
/// leaves the machine; the capture lives exactly as long as the OCR.
enum ScreenReader {
    enum Outcome {
        case text(app: String, words: String)
        case empty(app: String)
        case noWindow
        case denied
        case needsGrant
    }

    /// The Screen Recording dialog must never be awaited: ask without
    /// waiting and say plainly what to do next (the R94 wedge rule).
    /// macOS applies this grant on the app's NEXT launch more often
    /// than not; the copy says it again rather than promising magic.
    static func preflight() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestGrant() {
        CGRequestScreenCaptureAccess()
    }

    static func readFrontWindow() async -> Outcome {
        guard preflight() else { return .needsGrant }
        guard let content = try? await SCShareableContent
            .excludingDesktopWindows(true, onScreenWindowsOnly: true)
        else { return .denied }

        // The frontmost app's largest on-screen window; Moai itself
        // never counts, the island is not a document.
        let frontApp = NSWorkspace.shared.frontmostApplication
        let candidates = content.windows.filter { window in
            guard let app = window.owningApplication else { return false }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }
            guard window.isOnScreen, window.frame.width > 200,
                  window.frame.height > 150 else { return false }
            if let front = frontApp?.bundleIdentifier {
                return app.bundleIdentifier == front
            }
            return true
        }
        guard let window = candidates.max(by: {
            $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height
        }) else { return .noWindow }

        let appName = window.owningApplication?.applicationName ?? "the front app"

        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width) * 2
        configuration.height = Int(window.frame.height) * 2
        configuration.showsCursor = false
        let filter = SCContentFilter(desktopIndependentWindow: window)
        guard let image = try? await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: configuration
        ) else { return .denied }

        let words = await recognize(image)
        guard !words.isEmpty else { return .empty(app: appName) }
        return .text(app: appName, words: words)
    }

    private static func recognize(_ image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                try? handler.perform([request])
                let lines = request.results?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
        }
    }
}
