import SwiftUI

struct ClipboardView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var clipboard: ClipboardStore
    @Environment(\.moaiAccent) private var accent

    init(model: NotchViewModel) {
        self.model = model
        self.clipboard = model.clipboard
    }

    var body: some View {
        if clipboard.clips.isEmpty {
            VStack {
                Spacer()
                Text("Everything you copy lands here.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(clipboard.clips) { clip in
                        row(clip)
                    }
                }
            }
        }
    }

    private func row(_ clip: ClipboardStore.Clip) -> some View {
        HStack(spacing: 10) {
            Text(clip.text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Copy it back to the pasteboard
            IconActionButton(symbol: "doc.on.doc") {
                clipboard.copyBack(clip)
            }
            // Hand it to the Do surface: summarize, rewrite, translate
            IconActionButton(symbol: "sparkles", tint: accent) {
                model.askAbout(name: "clipboard", text: clip.text)
            }
            IconActionButton(symbol: "xmark", dim: true) {
                clipboard.remove(clip)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .moaiCard(radius: Theme.Radius.row)
    }
}
