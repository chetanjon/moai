import SwiftUI

struct MusicStrip: View {
    @ObservedObject var music: MusicController
    @Environment(\.moaiAccent) private var accent
    @State private var scrubPosition: Double?
    @State private var volumeDraft: Double?

    var body: some View {
        if let playing = music.nowPlaying {
            HStack(spacing: 12) {
                artworkView

                VStack(alignment: .leading, spacing: 3) {
                    Text(playing.track)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle(playing))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(Self.clock(scrubPosition ?? playing.position))
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary)
                        Slider(
                            value: Binding(
                                get: { scrubPosition ?? playing.position },
                                set: { scrubPosition = $0 }
                            ),
                            in: 0...max(playing.duration, 1),
                            onEditingChanged: { editing in
                                if !editing, let target = scrubPosition {
                                    music.seek(to: target)
                                    scrubPosition = nil
                                }
                            }
                        )
                        .controlSize(.mini)
                        .tint(accent)
                        Text(Self.clock(playing.duration))
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        transportButton("backward.fill", size: 11) {
                            music.previous()
                        }
                        Button {
                            playing.isPlaying ? music.pause() : music.play()
                        } label: {
                            Image(systemName: playing.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.black)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.white.opacity(0.92)))
                        }
                        .buttonStyle(.plain)
                        transportButton("forward.fill", size: 11) {
                            music.next()
                        }
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.textTertiary)
                        Slider(
                            value: Binding(
                                get: { volumeDraft ?? playing.volume },
                                set: { volumeDraft = $0 }
                            ),
                            in: 0...100,
                            onEditingChanged: { editing in
                                if !editing, let target = volumeDraft {
                                    music.setVolume(target)
                                    volumeDraft = nil
                                }
                            }
                        )
                        .controlSize(.mini)
                        .tint(accent)
                        .frame(width: 70)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .moaiCard()
        }
    }

    private var artworkView: some View {
        Group {
            if let artwork = music.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Theme.surface
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.artwork, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.artwork, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 5, y: 2)
    }

    private func subtitle(_ playing: MusicController.NowPlaying) -> String {
        playing.album.isEmpty
            ? playing.artist
            : "\(playing.artist) — \(playing.album)"
    }

    private func transportButton(
        _ symbol: String,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
