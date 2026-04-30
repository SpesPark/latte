import Foundation

/// One of the four Settings tabs. The `rawValue` is the path component
/// used in `latte://settings/<tab>` URLs (see `SettingsURLHandler`).
public enum SettingsTab: String, CaseIterable, Sendable {
    case general
    case triggers
    case activity
    case about
}

/// Settings deep-link target — tab selection plus an optional `focusedTriggerId`
/// that the Triggers tab uses to scroll-to + outline a row (C-3 deferred D).
public struct SettingsRoute: Equatable, Sendable {
    public let tab: SettingsTab
    public let focusedTriggerId: String?

    public init(tab: SettingsTab, focusedTriggerId: String? = nil) {
        self.tab = tab
        self.focusedTriggerId = focusedTriggerId
    }
}

/// Parses `latte://...` URLs into `SettingsTab` selections.
///
/// Supported forms:
///   - `latte://settings`                    → `.general` (default)
///   - `latte://settings/general`            → `.general`
///   - `latte://settings/triggers`           → `.triggers`
///   - `latte://settings/triggers?focus=wifi` → `.triggers`, focus="wifi" (D)
///   - `latte://settings/activity`           → `.activity`
///   - `latte://settings/about`              → `.about`
///
/// Anything outside the `latte` scheme or the `settings` host returns nil.
/// Unknown tab paths fall back to `.general` rather than failing — the goal
/// is "open Settings for marketing capture", not strict validation.
public enum SettingsURLHandler {

    public static let scheme = "latte"
    public static let settingsHost = "settings"
    /// Query parameter name for the focused trigger ID (D).
    public static let focusQueryParam = "focus"

    /// Tab-only parse — kept as a thin convenience wrapper. New callers
    /// should prefer `parseRoute(_:)`, which also surfaces the optional
    /// focused trigger ID for the Triggers tab.
    public static func parse(_ url: URL) -> SettingsTab? {
        parseRoute(url)?.tab
    }

    /// Full route parse — tab + optional focused trigger ID.
    public static func parseRoute(_ url: URL) -> SettingsRoute? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == scheme,
              components.host == settingsHost else {
            return nil
        }
        let trimmed = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let tab: SettingsTab
        if trimmed.isEmpty {
            tab = .general
        } else {
            tab = SettingsTab(rawValue: trimmed) ?? .general
        }
        // Focus is only meaningful on the Triggers tab — drop it elsewhere
        // so a stray ?focus=wifi on /general doesn't silently change behaviour.
        let focus: String? = (tab == .triggers)
            ? components.queryItems?.first(where: { $0.name == focusQueryParam })?.value
            : nil
        return SettingsRoute(tab: tab, focusedTriggerId: focus)
    }
}
