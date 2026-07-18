import SwiftUI

/// Quiet premium: near-black glass, hairline edges, soft white text,
/// and one restrained accent that follows the current album artwork.
enum Theme {
    // MARK: Surfaces

    static let backdropTop = Color(red: 0.043, green: 0.043, blue: 0.051)
    static let backdropBottom = Color(red: 0.024, green: 0.024, blue: 0.031)

    static var backdrop: LinearGradient {
        LinearGradient(
            colors: [backdropTop, backdropBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Cards and strips sitting on the backdrop.
    static let surface = Color.white.opacity(0.05)
    /// Text fields, slightly brighter than cards.
    static let field = Color.white.opacity(0.07)
    /// The island's glass edge.
    static let hairline = Color.white.opacity(0.10)
    /// Strokes on interior cards.
    static let hairlineFaint = Color.white.opacity(0.06)

    /// Top-lit edge for the island: brighter where light would catch it.
    static var specularEdge: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Text hierarchy

    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.32)

    static let danger = Color(red: 1.0, green: 0.45, blue: 0.45)

    /// Accent when nothing is playing: soft warm-white, near zero chroma.
    static let accentFallback = Color(hue: 0.6, saturation: 0.05, brightness: 0.82)

    // Fixed accent choices, pre-clamped to the same quiet range the
    // artwork extractor produces.
    static let accentBlue = Color(hue: 0.58, saturation: 0.42, brightness: 0.80)
    static let accentMint = Color(hue: 0.42, saturation: 0.38, brightness: 0.78)
    static let accentRose = Color(hue: 0.97, saturation: 0.42, brightness: 0.80)

    /// nil means "album" — follow the artwork-derived accent.
    static func fixedAccent(for mode: String) -> Color? {
        switch mode {
        case "silver": return accentFallback
        case "blue": return accentBlue
        case "mint": return accentMint
        case "rose": return accentRose
        default: return nil
        }
    }

    // MARK: Scales

    enum Radius {
        static let card: CGFloat = 12
        static let row: CGFloat = 10
        static let field: CGFloat = 12
        static let artwork: CGFloat = 8
    }

    /// Droplet silhouette parameters per island state.
    enum Island {
        static let eaveCollapsed: CGFloat = 12
        static let eaveExpanded: CGFloat = 22
        static let radiusCollapsed: CGFloat = 16
        static let radiusExpanded: CGFloat = 44
        static let bellyCollapsed: CGFloat = 1.5
        static let bellyExpanded: CGFloat = 10
    }

    /// Motion personality, user-selectable in settings. Serene is the
    /// default: glides and slow breath, never a visible bounce. Still
    /// is pure glass — no ambient motion at all.
    enum Feel: String {
        case still, serene, balanced, lively

        static var current: Feel {
            Feel(rawValue: UserDefaults.standard.string(forKey: "motionFeel") ?? "")
                ?? .serene
        }

        /// Ambient effects (aurora, glow, sweep, glyph shimmer) run at all.
        var ambient: Bool { self != .still }
    }

    enum Motion {
        static var island: Animation {
            switch Feel.current {
            case .still: return .spring(response: 0.42, dampingFraction: 1.0)
            case .serene: return .spring(response: 0.45, dampingFraction: 0.92)
            case .balanced: return .spring(response: 0.38, dampingFraction: 0.82)
            case .lively: return .spring(response: 0.38, dampingFraction: 0.72)
            }
        }

        static var hover: Animation {
            switch Feel.current {
            case .still: return .spring(response: 0.30, dampingFraction: 1.0)
            case .serene: return .spring(response: 0.30, dampingFraction: 0.90)
            case .balanced: return .spring(response: 0.26, dampingFraction: 0.80)
            case .lively: return .spring(response: 0.26, dampingFraction: 0.70)
            }
        }

        static var content: Animation {
            switch Feel.current {
            case .still: return .smooth(duration: 0.28)
            case .serene: return .smooth(duration: 0.32)
            case .balanced: return .snappy(duration: 0.25)
            case .lively: return .snappy(duration: 0.22)
            }
        }

        static let accent = Animation.easeInOut(duration: 1.0)

        /// Rim light on expand: slower and fainter the calmer the feel.
        static var sweepDuration: Double {
            switch Feel.current {
            case .still: return 0
            case .serene: return 1.5
            case .balanced: return 1.1
            case .lively: return 0.9
            }
        }

        static var sweepPeak: Double {
            switch Feel.current {
            case .still: return 0
            case .serene: return 0.45
            case .balanced: return 0.7
            case .lively: return 0.9
            }
        }

        /// Ambient loops (aurora drift, glow breath) stretch by this factor.
        static var ambientSlow: Double {
            switch Feel.current {
            case .still: return 2.0
            case .serene: return 1.6
            case .balanced: return 1.0
            case .lively: return 0.8
            }
        }
    }

    /// Holding the notch this long starts listening; shorter is a tap.
    static let pressToTalkDelay: TimeInterval = 0.32
}

// MARK: - Adaptive accent environment

private struct MoaiAccentKey: EnvironmentKey {
    static let defaultValue: Color = Theme.accentFallback
}

extension EnvironmentValues {
    /// The album-artwork-derived accent, kept quiet by AccentExtractor's
    /// saturation/brightness clamps. Injected once at the root.
    var moaiAccent: Color {
        get { self[MoaiAccentKey.self] }
        set { self[MoaiAccentKey.self] = newValue }
    }
}
