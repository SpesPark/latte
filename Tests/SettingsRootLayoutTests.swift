import XCTest
@testable import Latte

/// Layout regression for S20 / P1 (Settings tab bar disappearing on About).
///
/// AboutTab's intrinsic content height (hero card ~196pt + statusCard ~112pt
/// + spacers + footer + padding) exceeds the prior `minHeight: 360` constraint
/// on a stock 460×360 Settings window. With a greedy `Spacer()` in the middle,
/// SwiftUI compressed the available vertical space to negative and rendered
/// content over the TabView's tab bar, making other tabs unreachable.
///
/// Fix: pin `SettingsRoot.minWindowHeight` to 420 so AboutTab fits without
/// overflow on first launch. The window remains user-resizable above this
/// floor.
final class SettingsRootLayoutTests: XCTestCase {

    func testMinWindowHeightAccommodatesAboutTab() {
        // 420 is empirically the smallest height where AboutTab's hero card +
        // statusCard + footer fit without the greedy Spacer compressing to
        // negative. Any further tightening would re-introduce the tab-bar-
        // overflow regression observed in S19 owner manual smoke.
        XCTAssertGreaterThanOrEqual(
            SettingsRoot.minWindowHeight, 420,
            "About tab overflows tab bar when minWindowHeight < 420"
        )
    }

    func testMinWindowWidthUnchanged() {
        // Width was never the source of overflow — pin to 460 so the picker
        // labels in GeneralTab still fit on one line.
        XCTAssertEqual(SettingsRoot.minWindowWidth, 460)
    }
}
