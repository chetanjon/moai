import SwiftUI

struct ShelfView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var shelf: ShelfStore
    @Environment(\.moaiAccent) private var accent

    init(model: NotchViewModel) {
        self.model = model
        self.shelf = model.shelf
    }

    var body: some View {
        if shelf.items.isEmpty {
            VStack {
                Spacer()
                Text("Drop files on the notch to stash them here.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(shelf.items) { item in
                        row(item)
                    }
                }
            }
        }
    }

    private func row(_ item: ShelfStore.Item) -> some View {
        let extractedText = shelf.extractText(item)
        return HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            IconActionButton(symbol: "square.and.arrow.up") {
                shelf.airDrop(item)
            }
            if let extractedText {
                IconActionButton(symbol: "sparkles", tint: accent) {
                    model.askAbout(name: item.name, text: extractedText)
                }
            }
            IconActionButton(symbol: "xmark", dim: true) {
                shelf.remove(item)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .moaiCard(radius: Theme.Radius.row)
        // Drag the file back out to Finder or any app
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }
}
