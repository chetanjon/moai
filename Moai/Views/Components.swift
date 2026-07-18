import SwiftUI

/// The standard card treatment: quiet surface fill with a faint hairline.
private struct MoaiCard: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairlineFaint, lineWidth: 1)
            )
    }
}

extension View {
    func moaiCard(radius: CGFloat = Theme.Radius.card) -> some View {
        modifier(MoaiCard(radius: radius))
    }
}

/// Small icon-only row action (copy, delete, share...).
struct IconActionButton: View {
    let symbol: String
    var tint: Color = Theme.textSecondary
    var dim = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(dim ? Theme.textTertiary : tint)
        }
        .buttonStyle(.plain)
    }
}

/// Two blobs of the album color drifting on slow orbits inside the
/// glass. Lives only while the island is open, so it costs nothing
/// when collapsed.
struct AuroraView: View {
    let accent: Color

    var body: some View {
        // Radial gradients, not live blurs: a blur filter re-renders
        // every tick and stutters the expand animation; a gradient
        // composites for free and looks the same at these opacities.
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            let calm = Theme.Motion.ambientSlow
            let t = context.date.timeIntervalSinceReferenceDate / calm
            let dim = calm > 1 ? 0.85 : 1.0
            ZStack {
                blob(size: CGSize(width: 340, height: 240), fade: 0.16 * dim)
                    .offset(
                        x: -170 + CGFloat(sin(t / 9)) * 28,
                        y: -70 + CGFloat(cos(t / 7)) * 18
                    )
                blob(size: CGSize(width: 380, height: 260), fade: 0.12 * dim)
                    .hueRotation(.degrees(-14))
                    .saturation(1.2)
                    .offset(
                        x: 160 + CGFloat(cos(t / 11)) * 32,
                        y: 100 + CGFloat(sin(t / 8)) * 20
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func blob(size: CGSize, fade: Double) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [accent.opacity(fade), accent.opacity(0)],
                    center: .center,
                    startRadius: 8,
                    endRadius: size.width / 2
                )
            )
            .frame(width: size.width, height: size.height)
    }
}

/// Three dots doing a gentle wave while Moai works.
struct ThinkingDots: View {
    @Environment(\.moaiAccent) private var accent
    @State private var bouncing = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
                    .scaleEffect(bouncing ? 1.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: bouncing
                    )
            }
        }
        .onAppear { bouncing = true }
    }
}
