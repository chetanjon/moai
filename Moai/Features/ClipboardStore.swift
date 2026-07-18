import AppKit

@MainActor
final class ClipboardStore: ObservableObject {
    struct Clip: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let date: Date
    }

    @Published var clips: [Clip] = []

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let maxClips = 30

    /// Standard flag password managers set on sensitive copies.
    /// Moai never stores anything marked with it.
    private let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let types = pasteboard.types,
           types.contains(concealedType) || types.contains(transientType) {
            return
        }
        guard let text = pasteboard.string(forType: .string) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if clips.first?.text == text { return }

        clips.insert(Clip(text: text, date: Date()), at: 0)
        if clips.count > maxClips {
            clips.removeLast(clips.count - maxClips)
        }
    }

    func copyBack(_ clip: Clip) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(clip.text, forType: .string)
    }

    func remove(_ clip: Clip) {
        clips.removeAll { $0.id == clip.id }
    }
}
