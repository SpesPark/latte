import Foundation
import SwiftUI

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

    /// Resolves the user-visible colour for a trigger. Override hex wins
    /// if it parses; falls through to the static default; falls through
    /// again to system accent for unknown triggers (never returns clear,
    /// which would silently hide bars).
    public static func color(for triggerId: String, overrides: [String: String]) -> Color {
        if let raw = overrides[triggerId], let parsed = Color(hex: raw) {
            return parsed
        }
        if let defaultRaw = defaultHex[triggerId], let parsed = Color(hex: defaultRaw) {
            return parsed
        }
        return .accentColor
    }

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

// MARK: - Color hex

extension Color {

    /// Parses `#RRGGBB` (or `RRGGBB`) into an sRGB Color. Returns nil for
    /// anything else — including 3-digit shorthand and 8-digit RGBA, which
    /// the chart settings UI never produces. 8-bit precision per channel
    /// is sufficient for the picker round-trip.
    public init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespaces)
        let stripped = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard stripped.count == 6,
              let value = UInt32(stripped, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }

    /// "#RRGGBB" representation rounded to 8-bit channels. Reads from the
    /// sRGB component space — the colour pickers we emit hex from already
    /// produce sRGB. Returns nil if the underlying NSColor cannot be
    /// resolved (system colours, asset-catalog tints).
    public var hexString: String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int((components.redComponent * 255).rounded())
        let g = Int((components.greenComponent * 255).rounded())
        let b = Int((components.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
