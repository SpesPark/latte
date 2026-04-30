import Foundation

/// One of the four Settings tabs. The `rawValue` is the path component
/// used in `latte://settings/<tab>` URLs (see `SettingsURLHandler`).
public enum SettingsTab: String, CaseIterable, Sendable {
    case general
    case triggers
    case activity
    case about
}

/// Parses `latte://...` URLs into `SettingsTab` selections.
///
/// Supported forms:
///   - `latte://settings`            → `.general` (default)
///   - `latte://settings/general`    → `.general`
///   - `latte://settings/triggers`   → `.triggers`
///   - `latte://settings/activity`   → `.activity`
///   - `latte://settings/about`      → `.about`
///
/// Anything outside the `latte` scheme or the `settings` host returns nil.
/// Unknown tab paths fall back to `.general` rather than failing — the goal
/// is "open Settings for marketing capture", not strict validation.
public enum SettingsURLHandler {

    public static let scheme = "latte"
    public static let settingsHost = "settings"

    public static func parse(_ url: URL) -> SettingsTab? {
        guard url.scheme == scheme, url.host == settingsHost else {
            return nil
        }
        let trimmed = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.isEmpty {
            return .general
        }
        return SettingsTab(rawValue: trimmed) ?? .general
    }
}
