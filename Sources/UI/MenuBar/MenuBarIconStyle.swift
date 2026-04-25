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

    /// SF Symbol name passed to `MenuBarExtra(_:systemImage:)`.
    ///
    /// - `filled` → `cup.and.saucer.fill` — default; the app's identity.
    /// - `outline` → `cup.and.saucer` — minimalist; pairs well with thin
    ///   menu bars.
    /// - `clock` → `cup.and.heat.waves.fill` — the cup with steam waves,
    ///   conveying "active / time passing." We chose this over a literal
    ///   clock-and-cup composite because no single SF Symbol composes both,
    ///   and using two symbols would require a custom view that breaks
    ///   `MenuBarExtra`'s built-in tinting.
    public var symbolName: String {
        switch self {
        case .filled:  return "cup.and.saucer.fill"
        case .outline: return "cup.and.saucer"
        case .clock:   return "cup.and.heat.waves.fill"
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
