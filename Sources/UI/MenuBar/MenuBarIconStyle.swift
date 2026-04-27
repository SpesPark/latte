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

    /// SF Symbol shown when Latte is at rest. Each style has a
    /// distinct asleep glyph **and** a distinct awake variant so the
    /// user's option choice carries through both states (S8b owner
    /// feedback during smoke: an earlier fix shared a single steam-cup
    /// across all styles, making the styles indistinguishable when
    /// awake).
    ///
    /// Style → (asleep, awake):
    /// - `filled`  → `cup.and.saucer.fill` ↔ `cup.and.heat.waves.fill`
    ///   (bold cup; awake adds rising steam)
    /// - `outline` → `cup.and.saucer` ↔ `cup.and.heat.waves`
    ///   (thin cup; awake adds rising steam, still outlined)
    /// - `clock`   → `mug` ↔ `mug.fill`
    ///   (taller mug shape; awake fills the cup. SF Symbols ships
    ///   no `mug.and.heat.waves` so this style does not display
    ///   steam — a known limitation for v1.0; consider a custom
    ///   asset in a follow-up if owner wants steam everywhere.)
    public var symbolName: String {
        symbolName(awake: false)
    }

    /// SF Symbol used by `MenuBarExtra(_:systemImage:)`. Returns the
    /// at-rest or awake glyph based on the live `manager.isAwake` value.
    ///
    /// All glyphs are members of the SF Symbols 5 catalog shipping with
    /// macOS 13+, so no runtime fallback is needed.
    public func symbolName(awake: Bool) -> String {
        switch (self, awake) {
        case (.filled, false):  return "cup.and.saucer.fill"
        case (.filled, true):   return "cup.and.heat.waves.fill"
        case (.outline, false): return "cup.and.saucer"
        case (.outline, true):  return "cup.and.heat.waves"
        case (.clock, false):   return "mug"
        case (.clock, true):    return "mug.fill"
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
