import XCTest
@testable import Latte

/// Layout regression for the App Store rejection (Submission dc78a591,
/// 2026-06-23, Guideline 4 - Design): "the app menubar extra pop-up window is
/// truncated at the bottom so that users can not click some options."
///
/// `MenuBarRoot` was a fixed-width / unbounded-height stack; on a notched 14"
/// display the seven duration presets + expanded Custom row + recurring presets
/// pushed Settings / Quit off-screen, and `MenuBarExtra(.window)` does not
/// clamp or scroll on its own. The fix caps the scrollable middle section at
/// `MenuBarLayout.maxScrollHeight(forVisibleScreenHeight:)` and pins the footer
/// outside the scroll. These tests pin that math so the cap can never silently
/// regress to "unbounded".
final class MenuBarLayoutTests: XCTestCase {

    /// On a roomy display the cap is the usable height minus the chrome the
    /// pinned header + footer + margin reserve — never the full screen.
    func testCapLeavesRoomForChromeOnLargeDisplay() {
        let cap = MenuBarLayout.maxScrollHeight(forVisibleScreenHeight: 1440)
        XCTAssertEqual(cap, 1440 - MenuBarLayout.reservedChrome)
        XCTAssertLessThan(cap, 1440, "scroll area must never claim the whole screen")
    }

    /// A stock small laptop (visibleFrame ~800) still leaves the footer
    /// on-screen: cap = 800 - 220 = 580, comfortably above the floor.
    func testCapOnSmallLaptopStaysAboveFloor() {
        let cap = MenuBarLayout.maxScrollHeight(forVisibleScreenHeight: 800)
        XCTAssertEqual(cap, 580)
        XCTAssertGreaterThanOrEqual(cap, MenuBarLayout.minScrollHeight)
    }

    /// Pathologically short / bogus `visibleFrame` readings clamp to the floor
    /// so the scroll area never collapses to an unusable sliver.
    func testCapClampsToFloorOnTinyHeight() {
        XCTAssertEqual(
            MenuBarLayout.maxScrollHeight(forVisibleScreenHeight: 300),
            MenuBarLayout.minScrollHeight
        )
        XCTAssertEqual(
            MenuBarLayout.maxScrollHeight(forVisibleScreenHeight: 0),
            MenuBarLayout.minScrollHeight
        )
    }

    /// The floor↔computed boundary: at `floor + chrome` the two are equal;
    /// one point taller switches to the computed value. Pins the `max()` seam.
    func testCapBoundaryBetweenFloorAndComputed() {
        let boundary = MenuBarLayout.minScrollHeight + MenuBarLayout.reservedChrome
        XCTAssertEqual(
            MenuBarLayout.maxScrollHeight(forVisibleScreenHeight: boundary),
            MenuBarLayout.minScrollHeight
        )
        XCTAssertEqual(
            MenuBarLayout.maxScrollHeight(forVisibleScreenHeight: boundary + 1),
            MenuBarLayout.minScrollHeight + 1
        )
    }

    // MARK: - needsScroll (render natural size vs. fall back to a ScrollView)

    /// Content that fits the screen renders natural-size (no scroll) so the
    /// window hugs it — no fixed window, no scrollbar (owner-reported on build).
    func testDoesNotScrollWhenContentFits() {
        // 450 content on a roomy 1440 screen (cap 1220) → fits.
        XCTAssertFalse(
            MenuBarLayout.needsScroll(measuredContentHeight: 450, visibleScreenHeight: 1440)
        )
        // Even right up to the cap it still fits (boundary is strict >).
        let cap = MenuBarLayout.maxScrollHeight(forVisibleScreenHeight: 1440)
        XCTAssertFalse(
            MenuBarLayout.needsScroll(measuredContentHeight: cap, visibleScreenHeight: 1440)
        )
    }

    /// Content taller than the screen scrolls so the footer stays reachable
    /// (the original rejection).
    func testScrollsWhenContentExceedsScreen() {
        // Short screen: 650 usable → cap 430; tall content must scroll.
        XCTAssertTrue(
            MenuBarLayout.needsScroll(measuredContentHeight: 900, visibleScreenHeight: 650)
        )
        let cap = MenuBarLayout.maxScrollHeight(forVisibleScreenHeight: 650)
        XCTAssertTrue(
            MenuBarLayout.needsScroll(measuredContentHeight: cap + 1, visibleScreenHeight: 650)
        )
    }

    /// A stray 0 / tiny measurement never triggers the scroll fallback (it
    /// "fits"), so the middle renders natural-size and can't collapse.
    func testZeroMeasurementRendersNaturalNotScrolled() {
        XCTAssertFalse(
            MenuBarLayout.needsScroll(measuredContentHeight: 0, visibleScreenHeight: 1440)
        )
    }
}
