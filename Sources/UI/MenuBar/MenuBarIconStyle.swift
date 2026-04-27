import Foundation

/// User-selected menu-bar icon variant. Persisted as a string under
/// `SettingsKey.menuBarIconStyle` and mirrored as a `@Published` property on
/// `AppEnvironment` so changes from the Settings picker propagate to
/// `MenuBarExtra` instantly.
///
/// Each variant maps to a built-in SF Symbol — we deliberately do **not**
/// rasterize custom PNGs because (a) SF Symbols adapt to system tinting
/// automatically, (b) the menu bar height varies across notch / non-notch
/// Macs, and (c) shipping a PNG would require dark-mode and high-DPI variants
/// per icon. SF Symbols are the documented Apple-native path for menu-bar
/// utilities.
public enum MenuBarIconStyle: String, CaseIterable, Sendable, Identifiable {
    case filled
    case outline
    case clock

    public var id: String { rawValue }

    /// SF Symbol shown when Latte is at rest. Each style keeps a
    /// distinct at-rest glyph so the user's option choice still has
    /// visible meaning, while every style shares the same awake
    /// glyph — a cup with steam waves — so "active" reads identically
    /// no matter which style is selected (S8b owner feedback during
    /// smoke: filled and outline became indistinguishable when both
    /// awake variants were `cup.and.saucer.fill`).
    ///
    /// At-rest glyphs:
    /// - `filled` → `cup.and.saucer.fill` (bold filled saucer-cup)
    /// - `outline` → `cup.and.saucer` (thin outline saucer-cup)
    /// - `clock` → `mug` (taller mug shape)
    ///
    /// Awake glyph (universal): `cup.and.heat.waves.fill` — the cup
    /// with rising steam, the unambiguous "Latte is keeping the Mac
    /// awake right now" signal.
    public var symbolName: String {
        symbolName(awake: false)
    }

    /// SF Symbol used by `MenuBarExtra(_:systemImage:)`. Returns the
    /// at-rest or awake glyph based on the live `manager.isAwake` value.
    ///
    /// All glyphs are members of the SF Symbols 5 catalog shipping with
    /// macOS 13+, so no runtime fallback is needed.
    public func symbolName(awake: Bool) -> String {
        if awake {
            return "cup.and.heat.waves.fill"
        }
        switch self {
        case .filled:  return "cup.and.saucer.fill"
        case .outline: return "cup.and.saucer"
        case .clock:   return "mug"
        }
    }

    /// Human-readable label for the Settings picker.
    public var displayName: String {
        switch self {
        case .filled:  return "Filled cup"
        case .outline: return "Outlined cup"
        case .clock:   return "Cup with steam"
        }
    }

    /// Default for new installs and for malformed persisted values.
    public static let `default`: MenuBarIconStyle = .filled

    /// Tolerant decode from the persisted raw string. Returns `.default`
    /// if the value is missing, empty, or unknown — never throws.
    public static func decode(_ raw: String?) -> MenuBarIconStyle {
        guard let raw, !raw.isEmpty else { return .default }
        return MenuBarIconStyle(rawValue: raw) ?? .default
    }
}
