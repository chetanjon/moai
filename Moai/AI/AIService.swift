import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AIError: LocalizedError {
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .badResponse(let message):
            return message
        }
    }
}

/// One brain, keyless: Apple's on-device model answers quick
/// questions and translates loose phrasings into verbs. Long-form
/// conversation belongs to the Chat tab, where the user's own
/// Claude, ChatGPT, or Gemini subscription does the heavy lifting.
/// The API-key era (three cloud SSE providers, Keychain fields)
/// was removed 2026-07-21: two ways to the same answer, one of
/// them worse.
struct AIService {
    static let systemPrompt =
        "You are Moai, a tiny assistant living in the Mac notch. Answer in as few words as possible. Plain text only, no markdown."

    /// True when Apple's on-device model can answer right now:
    /// Apple Silicon, new-enough macOS, Apple Intelligence turned on.
    static var localModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        #endif
        return false
    }

    /// Map a loose phrasing onto one canonical command, or nil. Runs
    /// when the deterministic verbs miss; the reply goes back through
    /// the same engine, so natural language still ends in real
    /// actions and nobody memorizes a vocabulary.
    static func translateToVerb(_ utterance: String) async -> String? {
        let prompt = """
        Translate the request into exactly one Moai command from this list, \
        filling in the user's own words and times:
        remind me to <thing> at <time> / schedule <thing> <day> at <time> / \
        cancel <event> / move <event> to <time> / what's next / agenda / \
        what's due / done with <reminder> / undo / focus <minutes> / \
        timer <minutes> / stop focus / stop timer / rain / fire / cafe / \
        brown noise / stop noise / play / pause / next / previous / \
        open <app or folder> / quit <app> / left half / right half / fill / \
        center / note: <text> / notes / find <words> / screenshot / \
        lock screen / dark mode
        Reply with the single command only, no quotes, no explanation. \
        If nothing fits, reply NONE.
        Request: \(utterance)
        """
        do {
            var reply = ""
            try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    var collected = ""
                    for try await delta in stream(prompt: prompt) {
                        collected += delta
                        if collected.count > 200 { break }
                    }
                    return collected
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 8_000_000_000)
                    throw CancellationError()
                }
                reply = try await group.next() ?? ""
                group.cancelAll()
            }
            let line = reply
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines).first ?? ""
            let cleaned = line.trimmingCharacters(
                in: CharacterSet(charactersIn: " \"'`.")
            )
            guard !cleaned.isEmpty,
                  cleaned.uppercased() != "NONE",
                  cleaned.count < 120
            else { return nil }
            return cleaned
        } catch {
            return nil
        }
    }

    /// Streams the answer as text deltas so the island can type it
    /// out live instead of sitting on ThinkingDots until the whole
    /// reply lands. Apple's local model streams cumulative snapshots,
    /// not deltas; diff against the last snapshot.
    static func stream(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    #if canImport(FoundationModels)
                    if #available(macOS 26.0, *) {
                        guard case .available = SystemLanguageModel.default.availability else {
                            throw AIError.badResponse(
                                "The Mac's on-device model isn't ready. Turn on Apple Intelligence in System Settings."
                            )
                        }
                        let session = LanguageModelSession(instructions: systemPrompt)
                        var previous = ""
                        for try await snapshot in session.streamResponse(to: prompt) {
                            let text = snapshot.content
                            if text.hasPrefix(previous) {
                                let delta = String(text.dropFirst(previous.count))
                                if !delta.isEmpty { continuation.yield(delta) }
                            } else {
                                continuation.yield(text)
                            }
                            previous = text
                        }
                        continuation.finish()
                        return
                    }
                    #endif
                    throw AIError.badResponse(
                        "The on-device model needs a newer macOS."
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
