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

    /// SF Symbol name shown when Latte is **at rest** (Mac is sleeping
    /// or no triggers are voting awake). Mirrors the user-selected style.
    ///
    /// V2-01 (S8b research): paired with `awakeSymbolName(_:)` so the
    /// menu bar icon visibly distinguishes the two states. Closes a
    /// 15-year category-standard UX gap (Caffeine's full-cup/empty-cup).
    ///
    /// - `filled` → `cup.and.saucer` (outline cup at rest; awake variant
    ///   is the filled cup).
    /// - `outline` → `cup.and.saucer` (same outline at rest; awake
    ///   variant is the filled cup).
    /// - `clock` → `mug` (a quieter mug glyph at rest; awake variant
    ///   shows steam — the "active / time passing" connotation).
    ///
    /// The `filled` and `outline` cases share the at-rest glyph because
    /// the awake variant is what visually distinguishes them now;
    /// follow-up cleanup (v1.x) may consolidate the two cases.
    public var symbolName: String {
        symbolName(awake: false)
    }

    /// SF Symbol used by `MenuBarExtra(_:systemImage:)`. Returns the
    /// at-rest or awake glyph based on the live `manager.isAwake` value.
    ///
    /// Both glyphs in each pair are members of the SF Symbols 5 catalog
    /// shipping with macOS 13+, so no runtime fallback is needed.
    public func symbolName(awake: Bool) -> String {
        switch self {
        case .filled:
            return awake ? "cup.and.saucer.fill" : "cup.and.saucer"
        case .outline:
            return awake ? "cup.and.saucer.fill" : "cup.and.saucer"
        case .clock:
            return awake ? "cup.and.heat.waves.fill" : "mug"
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
