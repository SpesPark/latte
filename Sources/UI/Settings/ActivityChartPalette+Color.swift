import Foundation
import SwiftUI

// SwiftUI rendering for `ActivityChartPalette`. Kept out of `Sources/Core`
// so Core stays SwiftUI-free (02-architecture.md §3.2) and can lift cleanly
// into a UI-agnostic layer for the OQ-04 SwiftData migration. The pure data
// + JSON (triggerOrder, defaultHex, encode/decode) live in Core; only the
// `Color` resolution belongs here.

public extension ActivityChartPalette {

    /// Resolves the user-visible colour for a trigger. Override hex wins
    /// if it parses; falls through to the static default; falls through
    /// again to system accent for unknown triggers (never returns clear,
    /// which would silently hide bars).
    static func color(for triggerId: String, overrides: [String: String]) -> Color {
        if let raw = overrides[triggerId], let parsed = Color(hex: raw) {
            return parsed
        }
        if let defaultRaw = defaultHex[triggerId], let parsed = Color(hex: defaultRaw) {
            return parsed
        }
        return .accentColor
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
