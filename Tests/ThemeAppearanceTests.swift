import AppKit
import SwiftUI
import XCTest
@testable import Latte

/// Light-mode visibility regression for S20 / P2.
///
/// `Theme.Colors.cup` and `Theme.Colors.foam` were hard-coded as near-white
/// creamy values (cup `(0.95, 0.95, 0.97)`, foam `(0.96, 0.93, 0.85)`) — fine
/// against the dark Settings background but invisible on light mode where
/// the popover/About backgrounds are also near-white. Owner reported during
/// S19 manual smoke that both the cup outline AND the steam particles
/// vanished in light mode.
///
/// Fix: convert both to dynamic `NSColor` that resolves to the original
/// creamy values in dark mode and to deeper cappuccino-brown values in
/// light mode.
final class ThemeAppearanceTests: XCTestCase {

    /// Light-mode foam must be perceptibly darker than light-mode background
    /// (the popover / Settings glass is near-white). Use a luminance proxy
    /// (sRGB-linear average of RGB) and require ≤ 0.7 — anything above that
    /// is too close to white.
    func testFoamLightModeIsPerceptiblyDarkerThanWhite() throws {
        let nsFoam = NSColor(Theme.Colors.foam)
        let lightRGB = try XCTUnwrap(nsFoam.usingAppearance(.aqua, in: .sRGB))
        let avg = (lightRGB.redComponent + lightRGB.greenComponent + lightRGB.blueComponent) / 3.0
        XCTAssertLessThanOrEqual(
            avg, 0.7,
            "Light-mode foam too close to white (avg=\(avg)) — steam particles will be invisible"
        )
    }

    /// Light-mode cup body must be perceptibly darker than light-mode
    /// background so the cup outline reads against a near-white popover.
    func testCupLightModeIsPerceptiblyDarkerThanWhite() throws {
        let nsCup = NSColor(Theme.Colors.cup)
        let lightRGB = try XCTUnwrap(nsCup.usingAppearance(.aqua, in: .sRGB))
        let avg = (lightRGB.redComponent + lightRGB.greenComponent + lightRGB.blueComponent) / 3.0
        XCTAssertLessThanOrEqual(
            avg, 0.55,
            "Light-mode cup too close to white (avg=\(avg)) — cup body invisible against light backgrounds"
        )
    }

    /// Dark-mode values must remain unchanged from the v1.8 look so we don't
    /// regress the existing dark-mode appearance.
    func testCupDarkModeMatchesLegacyCreamy() throws {
        let nsCup = NSColor(Theme.Colors.cup)
        let darkRGB = try XCTUnwrap(nsCup.usingAppearance(.darkAqua, in: .sRGB))
        XCTAssertEqual(darkRGB.redComponent, 0.95, accuracy: 0.01)
        XCTAssertEqual(darkRGB.greenComponent, 0.95, accuracy: 0.01)
        XCTAssertEqual(darkRGB.blueComponent, 0.97, accuracy: 0.01)
    }

    func testFoamDarkModeMatchesLegacyCreamy() throws {
        let nsFoam = NSColor(Theme.Colors.foam)
        let darkRGB = try XCTUnwrap(nsFoam.usingAppearance(.darkAqua, in: .sRGB))
        XCTAssertEqual(darkRGB.redComponent, 0.96, accuracy: 0.01)
        XCTAssertEqual(darkRGB.greenComponent, 0.93, accuracy: 0.01)
        XCTAssertEqual(darkRGB.blueComponent, 0.85, accuracy: 0.01)
    }
}

private extension NSColor {
    /// Resolves a dynamic NSColor under a specific appearance, in a given
    /// color space. Returns nil if conversion fails (defensive — should not
    /// happen for sRGB-convertible colors used here).
    func usingAppearance(
        _ appearanceName: NSAppearance.Name,
        in space: NSColorSpace
    ) -> NSColor? {
        guard let appearance = NSAppearance(named: appearanceName) else { return nil }
        var resolved: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolved = self.usingColorSpace(space)
        }
        return resolved
    }
}
