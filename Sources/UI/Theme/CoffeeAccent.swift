import AppKit
import SwiftUI

/// Six hand-picked accent tones the user can choose from in Settings —
/// five coffee-inspired (espresso → caramel → mocha → latte → noir) plus
/// one `matcha` green pivot added in S30 by owner request. Each case
/// bundles light/dark sRGB pairs so the brand color stays consistent
/// regardless of the user's system tint, with appearance changes resolved
/// per-frame.
///
/// The colors live in code (not the asset catalog) because:
/// 1. `Color.accentColor` on macOS follows the user's system tint and would
///    override an asset-catalog value.
/// 2. SwiftUI `Canvas` does not always resolve `Color.primary` /
///    asset-catalog lookups against the current appearance — explicit
///    `NSColor` with a dynamic provider is the only fully reliable path.
public enum CoffeeAccent: String, CaseIterable, Sendable, Identifiable {
    case espresso
    case caramel
    case mocha
    case latte
    case matcha
    case noir

    public var id: String { rawValue }

    /// Default for new installs and for malformed persisted values.
    public static let `default`: CoffeeAccent = .espresso

    /// Human-readable picker label.
    public var displayName: String {
        switch self {
        case .espresso: return "Espresso"
        case .caramel:  return "Caramel"
        case .mocha:    return "Mocha"
        case .latte:    return "Latte"
        case .matcha:   return "Matcha"
        case .noir:     return "Noir"
        }
    }

    /// One-line picker subtitle / accessibility hint.
    public var shortDescription: String {
        switch self {
        case .espresso: return "Deep brown"
        case .caramel:  return "Warm amber"
        case .mocha:    return "Mid-tone brown"
        case .latte:    return "Light beige"
        case .matcha:   return "Green tea"
        case .noir:     return "Monochrome"
        }
    }

    /// Tolerant decode from a persisted raw string. Returns `.default` on
    /// nil / empty / unknown — never throws.
    public static func decode(_ raw: String?) -> CoffeeAccent {
        guard let raw, !raw.isEmpty else { return .default }
        return CoffeeAccent(rawValue: raw) ?? .default
    }

    // MARK: - Color matrix (light, dark) sRGB

    private struct ColorPair: Sendable {
        let light: (red: Double, green: Double, blue: Double)
        let dark:  (red: Double, green: Double, blue: Double)
    }

    private var pair: ColorPair {
        switch self {
        case .espresso: return ColorPair(
            light: (0.42, 0.24, 0.08),
            dark:  (0.62, 0.40, 0.18)
        )
        case .caramel: return ColorPair(
            light: (0.71, 0.51, 0.16),
            dark:  (0.85, 0.65, 0.30)
        )
        case .mocha: return ColorPair(
            light: (0.55, 0.35, 0.18),
            dark:  (0.72, 0.50, 0.30)
        )
        case .latte: return ColorPair(
            light: (0.78, 0.62, 0.40),
            dark:  (0.92, 0.80, 0.60)
        )
        case .matcha: return ColorPair(
            // Light: medium matcha green, lower R and B than the cup fill
            // (0.86, 0.80, 0.72) so it reads as green-on-tan, not muddy.
            // Dark: brighter saturated green against the near-white cup
            // body (0.95, 0.95, 0.97). Verified perceptibly distinct from
            // every other accent's hue ring.
            light: (0.46, 0.62, 0.32),
            dark:  (0.62, 0.78, 0.45)
        )
        case .noir: return ColorPair(
            light: (0.32, 0.32, 0.32),
            dark:  (0.55, 0.55, 0.55)
        )
        }
    }

    /// Dynamic `Color` that adapts to the current `NSAppearance` per-frame.
    /// Safe to call from a `View.body` or a `Canvas` draw closure.
    public var color: Color {
        let p = pair
        return Color(nsColor: NSColor(name: "CoffeeAccent.\(rawValue)") { appearance in
            let rgb = appearance.isDarkAqua ? p.dark : p.light
            return NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1.0)
        })
    }
}
