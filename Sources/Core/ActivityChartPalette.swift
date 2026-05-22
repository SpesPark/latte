import Foundation

/// Per-trigger colour palette for the Activity tab's hourly stacked bar
/// chart. Defaults are hand-picked to be hue-distinct under the macOS
/// system tint; users may override any/all per trigger via Settings.
///
/// Storage: `[String: String]` (triggerId → "#RRGGBB") JSON-encoded into
/// `SettingsKey.activityChartColors`. Empty map = "all defaults" (key
/// absent on disk). See `docs/design/09-c3-activity-history.md` §15.
public enum ActivityChartPalette {

    /// Canonical render order. `HourlyAwakeChart` reads this directly so
    /// the chart domain and the legend swatches cannot drift. Any new
    /// trigger added to the project must extend this list.
    public static let triggerOrder: [String] = [
        "wifi", "calendar", "focus", "app", "schedule", "external-display"
    ]

    /// Default hex per trigger. Hue choice mirrors the v1.3 ship palette
    /// (.blue/.red/.purple/.green/.orange/.teal). Frozen so a user who
    /// never touches the colour picker continues to see the same chart
    /// across upgrades.
    public static let defaultHex: [String: String] = [
        "wifi":             "#0A84FF",   // .blue
        "calendar":         "#FF453A",   // .red
        "focus":            "#BF5AF2",   // .purple
        "app":              "#32D74B",   // .green
        "schedule":         "#FF9F0A",   // .orange
        "external-display": "#5AC8FA"    // .teal
    ]

    /// Encodes overrides for `SettingsStore.setData`. Returns nil for an
    /// empty map so the caller can clear the key — preserves the "absent
    /// = never customised" invariant a future migration may rely on.
    public static func encode(overrides: [String: String]) -> Data? {
        guard !overrides.isEmpty else { return nil }
        return try? JSONEncoder().encode(overrides)
    }

    /// Tolerant decode. Returns `[:]` on nil / corrupt payload — the
    /// chart falls back to defaults and the user can re-customise.
    public static func decode(overrides data: Data?) -> [String: String] {
        guard let data else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
}
