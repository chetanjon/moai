import SwiftUI
import UniformTypeIdentifiers

struct NotchRootView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var music: MusicController
    @ObservedObject var timer: CountdownController
    @ObservedObject var focus: FocusController
    @ObservedObject var voice: VoiceController
    @State private var isDropTargeted = false
    @State private var pressStarted: Date?
    @State private var sweepAngle = 0.0
    @State private var sweepOpacity = 0.0

    @AppStorage("expandedSizePreset") private var sizePreset = "compact"
    // Declared so the view re-renders (and re-reads Theme.Motion) the
    // moment the user changes the feel in settings.
    @AppStorage("motionFeel") private var motionFeel = "serene"
    @AppStorage("auroraOn") private var auroraOn = true
    @AppStorage("sweepOn") private var sweepOn = true
    @AppStorage("glowOn") private var glowOn = true
    @AppStorage("idleEdgeOn") private var idleEdgeOn = true
    @AppStorage("accentMode") private var accentMode = "album"

    /// This view injects the accent into the environment for everything
    /// below it, so it reads the source directly rather than @Environment
    /// (which would resolve from the parent scope and never update).
    private var accent: Color {
        Theme.fixedAccent(for: accentMode) ?? music.accent
    }

    init(model: NotchViewModel) {
        self.model = model
        self.music = model.music
        self.timer = model.timer
        self.focus = model.focus
        self.voice = model.voice
    }

    private var hasLeftWing: Bool {
        focus.isActive || timer.isActive || music.nowPlaying?.isPlaying == true
    }

    private var statusWings: CGFloat {
        hasLeftWing ? 88 : 0
    }

    /// Stable per-state sizes: content is framed to its own state's
    /// size (not the live island size), so an outgoing view fades out
    /// at its natural size instead of being crushed into the pill.
    private var collapsedSize: CGSize {
        let growW: CGFloat = model.isHovering ? 14 : 0
        let growH: CGFloat = model.isHovering ? 4 : 0
        return CGSize(
            width: model.notchSize.width + statusWings + growW,
            height: model.notchSize.height + growH
        )
    }

    private static let listeningSize = CGSize(width: 440, height: 180)

    private var islandSize: CGSize {
        switch model.state {
        case .collapsed: return collapsedSize
        case .listening: return Self.listeningSize
        case .expanded: return NotchViewModel.expandedSize(for: sizePreset)
        }
    }

    private var islandShape: IslandShape {
        if model.state == .collapsed {
            // On hover the droplet "reaches" — shoulders widen, belly
            // sags — a soft beat of anticipation before opening.
            let reaching = model.isHovering && motionFeel != "still"
            return IslandShape(
                eave: Theme.Island.eaveCollapsed + (reaching ? 1.5 : 0),
                bottomRadius: Theme.Island.radiusCollapsed,
                belly: reaching ? 3 : Theme.Island.bellyCollapsed
            )
        }
        return IslandShape(
            eave: Theme.Island.eaveExpanded,
            bottomRadius: Theme.Island.radiusExpanded,
            belly: Theme.Island.bellyExpanded
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // A soft accent glow breathes under the notch while
                // music plays and the island is closed.
                if glowOn, motionFeel != "still", model.state == .collapsed,
                   music.nowPlaying?.isPlaying == true {
                    breathingGlow
                        .transition(.opacity)
                }

                // The droplet clings to the top edge of the screen; its
                // meniscus shoulders keep it flush with the notch.
                islandShape
                    .fill(
                        model.state == .collapsed
                            ? AnyShapeStyle(Color.black)
                            : AnyShapeStyle(Theme.backdrop)
                    )
                    // Album-colored aurora drifting inside the glass.
                    .overlay {
                        if auroraOn, motionFeel != "still", model.state != .collapsed {
                            AuroraView(accent: accent)
                                .clipShape(islandShape)
                                .transition(.opacity)
                        }
                    }
                    // Top-lit glass edge; brighter where light would catch it.
                    .overlay(
                        islandShape
                            .strokeBorder(Theme.specularEdge, lineWidth: 1)
                            .opacity(
                                model.state == .collapsed
                                    ? (model.isHovering || hasLeftWing ? 0.9 : (idleEdgeOn ? 0.7 : 0.5))
                                    : 1
                            )
                    )
                    // Bottom-lit lip: keeps the idle droplet findable
                    // over fullscreen apps' pure black top strip.
                    .overlay(
                        islandShape
                            .strokeBorder(Theme.lipLight, lineWidth: 1)
                            .opacity(idleEdgeOn && model.state == .collapsed ? 1 : 0)
                    )
                    // One-shot light sweep around the rim on expand.
                    .overlay(
                        islandShape
                            .strokeBorder(
                                AngularGradient(
                                    colors: [.clear, .clear, .white.opacity(0.55), .clear, .clear],
                                    center: .center,
                                    angle: .degrees(sweepAngle - 90)
                                ),
                                lineWidth: 1.5
                            )
                            .opacity(sweepOpacity)
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        islandShape
                            .strokeBorder(accent.opacity(0.8), lineWidth: 1.5)
                            .opacity(isDropTargeted ? 1 : 0)
                    )
                    .shadow(
                        color: Color.black.opacity(model.state == .collapsed ? 0 : 0.5),
                        radius: 22, y: 8
                    )

                contentLayer
            }
            .frame(width: islandSize.width, height: islandSize.height)
            .contentShape(Rectangle())
            // Hover is tracked by NotchWindowController against stable
            // state-based zones; tracking this animating view flickers.
            .onLongPressGesture(
                minimumDuration: Theme.pressToTalkDelay,
                maximumDistance: 60,
                pressing: { pressing in
                    if pressing {
                        pressStarted = Date()
                    } else {
                        if model.state == .listening {
                            model.endListening()
                        } else if model.state == .collapsed,
                                  let start = pressStarted,
                                  Date().timeIntervalSince(start) < Theme.pressToTalkDelay {
                            model.expand()
                        }
                        pressStarted = nil
                    }
                },
                perform: {
                    model.beginListening()
                }
            )
            .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
            .animation(Theme.Motion.island, value: model.state)
            .animation(Theme.Motion.hover, value: model.isHovering)
            .animation(Theme.Motion.hover, value: statusWings)
            .onChange(of: model.state) { _, newState in
                guard sweepOn, Theme.Feel.current.ambient, newState == .expanded
                else { return }
                let duration = Theme.Motion.sweepDuration
                sweepAngle = 0
                sweepOpacity = Theme.Motion.sweepPeak
                withAnimation(.easeInOut(duration: duration)) {
                    sweepAngle = 360
                }
                withAnimation(.easeOut(duration: 0.6).delay(duration * 0.6)) {
                    sweepOpacity = 0
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .environment(\.moaiAccent, music.accent)
    }

    /// State contents at their own natural sizes, clipped to the
    /// morphing droplet. On close, content vanishes in a fast fade and
    /// the shell does the shrinking; on open, the shell leads and
    /// content breathes in just behind it.
    private var contentLayer: some View {
        ZStack(alignment: .top) {
            if model.state == .collapsed {
                collapsedContent
                    .frame(width: collapsedSize.width, height: collapsedSize.height)
                    .transition(contentTransition)
            }

            if model.state == .listening {
                listeningContent
                    .frame(width: Self.listeningSize.width, height: Self.listeningSize.height)
                    .transition(contentTransition)
            }

            if model.state == .expanded {
                ExpandedView(model: model)
                    .frame(
                        width: NotchViewModel.expandedSize(for: sizePreset).width,
                        height: NotchViewModel.expandedSize(for: sizePreset).height
                    )
                    .transition(contentTransition)
            }
        }
        .frame(width: islandSize.width, height: islandSize.height, alignment: .top)
        .clipShape(islandShape)
    }

    private var contentTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.easeIn(duration: 0.22).delay(0.09)),
            removal: .opacity.animation(.easeOut(duration: 0.1))
        )
    }

    /// Soft accent ellipse under the collapsed island, slowly rising
    /// and falling while a track plays.
    private var breathingGlow: some View {
        TimelineView(.animation(minimumInterval: 1 / 12)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Ellipse()
                .fill(accent)
                .frame(width: islandSize.width * 0.9, height: 14)
                .blur(radius: 12)
                .opacity(0.10 + 0.08 * (0.5 + 0.5 * sin(t / (1.8 * Theme.Motion.ambientSlow))))
                .offset(y: islandSize.height - 5)
        }
        .allowsHitTesting(false)
    }

    /// Wings beside the physical notch: countdown or waveform left,
    /// a live spark on the right.
    private var collapsedContent: some View {
        HStack {
            if focus.isActive {
                Text(focus.display)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.leading, 11)
            } else if timer.isActive {
                Text(timer.display)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.leading, 11)
            } else if music.nowPlaying?.isPlaying == true {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                    .symbolEffect(
                        .variableColor.iterative,
                        options: .repeating,
                        isActive: motionFeel != "still"
                    )
                    .padding(.leading, 11)
            }
            Spacer()
            if hasLeftWing || model.isHovering {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(model.isHovering ? Theme.textSecondary : Theme.textTertiary)
                    .symbolEffect(.bounce, value: model.isHovering)
                    .padding(.trailing, 12)
            }
        }
    }

    private var listeningContent: some View {
        VStack(spacing: 10) {
            Text("listening")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3)
                .foregroundStyle(Theme.textSecondary)
            levelBars
            Text(voice.transcript.isEmpty ? "Say it." : voice.transcript)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Text("RELEASE OR TAP TO RUN")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.top, model.notchSize.height + 8)
        .contentShape(Rectangle())
        .onTapGesture {
            model.endListening()
        }
    }

    private var levelBars: some View {
        HStack(spacing: 3.5) {
            ForEach(0..<21, id: \.self) { index in
                let center = 1 - abs(CGFloat(index) - 10) / 11
                Capsule()
                    .fill(accent.opacity(0.35 + center * 0.65))
                    .frame(
                        width: 3.5,
                        height: 4 + voice.level * 30 * (0.35 + center * 0.65)
                    )
            }
        }
        .frame(height: 36)
        .animation(.easeOut(duration: 0.1), value: voice.level)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            accepted = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    model.shelf.add(url)
                    model.tab = .shelf
                    model.expand()
                }
            }
        }
        return accepted
    }
}
