import XCTest
import SwiftUI
@testable import Latte

final class ActivityChartPaletteTests: XCTestCase {

    // MARK: - Default palette

    func testTriggerOrderMatchesActivityTabDomain() {
        // The 24h chart's chartForegroundStyleScale uses the same six-trigger
        // domain — drift between palette and chart silently mis-renders the
        // legend swatches. Anchor the order here.
        XCTAssertEqual(
            ActivityChartPalette.triggerOrder,
            ["wifi", "calendar", "focus", "app", "schedule", "external-display"]
        )
    }

    func testDefaultHexHasOneEntryPerTrigger() {
        for triggerId in ActivityChartPalette.triggerOrder {
            XCTAssertNotNil(
                ActivityChartPalette.defaultHex[triggerId],
                "missing default hex for \(triggerId) — palette would fall back to system tint"
            )
        }
    }

    func testDefaultHexValuesParseAsValidColors() {
        for (triggerId, hex) in ActivityChartPalette.defaultHex {
            XCTAssertNotNil(
                Color(hex: hex),
                "trigger \(triggerId) has unparseable hex \(hex) — chart would render with clear/black"
            )
        }
    }

    // MARK: - Resolve

    func testResolveFallsBackToDefaultWhenOverrideMissing() {
        let defaultColor = Color(hex: ActivityChartPalette.defaultHex["wifi"]!)
        let resolved = ActivityChartPalette.color(for: "wifi", overrides: [:])
        XCTAssertEqual(resolved, defaultColor)
    }

    func testResolveAppliesOverride() {
        let custom = "#FF00FF"
        let resolved = ActivityChartPalette.color(for: "wifi", overrides: ["wifi": custom])
        XCTAssertEqual(resolved, Color(hex: custom))
    }

    func testResolveFallsBackToDefaultWhenOverrideHexInvalid() {
        // A malformed override must NOT corrupt the chart. Treat as if absent.
        let defaultColor = Color(hex: ActivityChartPalette.defaultHex["wifi"]!)
        let resolved = ActivityChartPalette.color(for: "wifi", overrides: ["wifi": "not-a-color"])
        XCTAssertEqual(resolved, defaultColor)
    }

    func testResolveUnknownTriggerReturnsAccentColor() {
        // A future trigger ID that has no default and no override falls back
        // to system accent — never returns Color.clear (would silently hide).
        let resolved = ActivityChartPalette.color(for: "future-trigger", overrides: [:])
        XCTAssertEqual(resolved, Color.accentColor)
    }

    // MARK: - Encode / decode round-trip

    func testEncodeDecodeRoundTrip() throws {
        let original: [String: String] = [
            "wifi": "#112233",
            "calendar": "#445566",
            "focus": "#778899"
        ]
        let data = try XCTUnwrap(ActivityChartPalette.encode(overrides: original))
        let decoded = ActivityChartPalette.decode(overrides: data)
        XCTAssertEqual(decoded, original)
    }

    func testDecodeNilDataReturnsEmpty() {
        XCTAssertEqual(ActivityChartPalette.decode(overrides: nil), [:])
    }

    func testDecodeCorruptDataReturnsEmpty() {
        // Garbage payload (valid SettingsStore key, decode failure) ≠ crash.
        // Defaults take over for the session; user can re-customise.
        let garbage = Data([0x00, 0xFF, 0xAA])
        XCTAssertEqual(ActivityChartPalette.decode(overrides: garbage), [:])
    }

    func testEncodeEmptyReturnsNil() {
        // Empty map → nil so SettingsStore.setData(nil) clears the key
        // (preserves "absent = default / never customised" invariant).
        XCTAssertNil(ActivityChartPalette.encode(overrides: [:]))
    }

    // MARK: - Color hex

    func testColorHexParsesRRGGBB() {
        XCTAssertEqual(Color(hex: "#FF0000"), Color(red: 1, green: 0, blue: 0))
        XCTAssertEqual(Color(hex: "#00FF00"), Color(red: 0, green: 1, blue: 0))
        XCTAssertEqual(Color(hex: "#0000FF"), Color(red: 0, green: 0, blue: 1))
    }

    func testColorHexAcceptsHashOrNoHash() {
        XCTAssertEqual(Color(hex: "FF0000"), Color(hex: "#FF0000"))
    }

    func testColorHexRejectsBadInputReturnsNil() {
        XCTAssertNil(Color(hex: "ZZZZZZ"))
        XCTAssertNil(Color(hex: "#1234"))      // too short
        XCTAssertNil(Color(hex: "#ABCDEFG"))   // too long / invalid char
        XCTAssertNil(Color(hex: ""))
    }

    func testColorHexRoundTripsThroughHexString() {
        // Lossy at the LSBit (8-bit precision per channel) but stable
        // round-trip — the Settings UI shows the user a colour they
        // re-pick and we must not drift on save/load.
        let original = "#3F7B2A"
        let color = Color(hex: original)!
        XCTAssertEqual(color.hexString?.uppercased(), original.uppercased())
    }
}
