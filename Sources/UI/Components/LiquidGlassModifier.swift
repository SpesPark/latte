import SwiftUI

/// Glass-material background.
///
/// On **macOS 26+** this uses `.regularMaterial`, which is the OS-level
/// "Liquid Glass" material with dynamic vibrancy and depth.
///
/// On **macOS 13~25** it falls back to `.ultraThinMaterial` — the closest
/// standard vibrancy material that ships across all supported OS versions.
/// The fallback is intentionally subtler than `.regularMaterial` so the
/// menu-bar window still feels lightweight on older systems.
///
/// Apply this *deliberately*, not globally. The menu-bar window opts in;
/// Settings tabs do not (`Form(.grouped)` already provides the standard
/// macOS settings material).
public struct LiquidGlassBackground: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.background(.regularMaterial)
        } else {
            content.background(.ultraThinMaterial)
        }
    }
}

/// Glass-material *card* — a clipped rectangle with a soft border. Used for
/// hero panels (e.g. About tab) where a free-floating block needs visual
/// elevation against the system Settings background.
public struct LiquidGlassCard: ViewModifier {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                if #available(macOS 26, *) {
                    shape.fill(.regularMaterial)
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            }
            .overlay {
                shape.strokeBorder(
                    Color.primary.opacity(0.06),
                    lineWidth: 0.5
                )
            }
            .clipShape(shape)
    }
}

public extension View {
    /// Liquid Glass background on macOS 26+; `.ultraThinMaterial` fallback
    /// on macOS 13~25.
    func liquidGlassBackground() -> some View {
        modifier(LiquidGlassBackground())
    }

    /// Liquid Glass *card* — rounded, bordered, clipped. Use for free-floating
    /// hero panels.
    func liquidGlassCard(cornerRadius: CGFloat = Theme.Radius.large) -> some View {
        modifier(LiquidGlassCard(cornerRadius: cornerRadius))
    }
}
