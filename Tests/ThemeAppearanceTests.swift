import AppKit
import SwiftUI
import XCTest
@testable import Latte

/// Light-mode visibility regression for S20 / P2 → S22 / P-issue-1.
///
/// **S20 / P2** (initial fix): `Theme.Colors.cup` and `Theme.Colors.foam` were
/// hard-coded as near-white creamy values (cup `(0.95, 0.95, 0.97)`, foam
/// `(0.96, 0.93, 0.85)`) — fine against the dark Settings background but
/// invisible on light mode where the popover/About backgrounds are also
/// near-white. Both were converted to dynamic `NSColor` resolving to deeper
/// values in light mode.
///
/// **S22 / P-issue-1** (re-fix): owner reported during the resumed Step 6
/// manual smoke that the S20 P2 light-mode cup body `(0.42, 0.32, 0.20)` was
/// *too dark* — almost identical luminance to the default Espresso liquid
/// `(0.42, 0.24, 0.08)`. Result: cup body and liquid blended into one brown
/// mass, the 1px foam line between them looked like a coffee-on-coffee
/// boundary, and the cup stroke (labelColor α=0.55) lost contrast against
/// the dark cup body so the outline + handle visually disappeared. The
/// correct mental model is "light mug holding dark coffee" — cup body must
/// be **brighter than the liquid** (so it reads as the mug, not more
/// liquid) and **darker than the popover background** (so the outline
/// reads). Re-fix moves cup light to `(0.86, 0.80, 0.72)`.
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

    /// **S22 / P-issue-1**: Light-mode cup body must be brighter than the
    /// default Espresso liquid by a clear margin. Otherwise cup body and
    /// liquid blend into one brown mass and the foam line reads as a
    /// coffee-on-coffee boundary (owner-reported visual defect).
    ///
    /// Threshold: cup_avg ≥ liquid_avg + 0.30 (≈ 30% sRGB-luminance gap).
    func testCupLightModeBrighterThanDefaultLiquidByMargin() throws {
        let nsCup = NSColor(Theme.Colors.cup)
        let nsLiquid = NSColor(CoffeeAccent.default.color)
        let cupRGB = try XCTUnwrap(nsCup.usingAppearance(.aqua, in: .sRGB))
        let liquidRGB = try XCTUnwrap(nsLiquid.usingAppearance(.aqua, in: .sRGB))
        let cupAvg = (cupRGB.redComponent + cupRGB.greenComponent + cupRGB.blueComponent) / 3.0
        let liquidAvg = (liquidRGB.redComponent + liquidRGB.greenComponent + liquidRGB.blueComponent) / 3.0
        XCTAssertGreaterThanOrEqual(
            cupAvg - liquidAvg, 0.30,
            "Light-mode cup (\(cupAvg)) too close to default liquid (\(liquidAvg)) — cup body and coffee blend together"
        )
    }

    /// **S22 / P-issue-1**: Light-mode cup body must still be perceptibly
    /// darker than the near-white popover/Settings background so the cup
    /// outline + handle stroke reads against it. Threshold: avg ≤ 0.85.
    func testCupLightModeDarkerThanPopoverBackground() throws {
        let nsCup = NSColor(Theme.Colors.cup)
        let lightRGB = try XCTUnwrap(nsCup.usingAppearance(.aqua, in: .sRGB))
        let avg = (lightRGB.redComponent + lightRGB.greenComponent + lightRGB.blueComponent) / 3.0
        XCTAssertLessThanOrEqual(
            avg, 0.85,
            "Light-mode cup too close to white (avg=\(avg)) — cup outline invisible against near-white popover"
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
