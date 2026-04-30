import XCTest
@testable import Latte

final class SettingsURLHandlerTests: XCTestCase {

    func testBareSettingsURLReturnsGeneral() {
        let url = URL(string: "latte://settings")!
        XCTAssertEqual(SettingsURLHandler.parse(url), .general)
    }

    func testSettingsTrailingSlashReturnsGeneral() {
        let url = URL(string: "latte://settings/")!
        XCTAssertEqual(SettingsURLHandler.parse(url), .general)
    }

    func testGeneralPathReturnsGeneral() {
        let url = URL(string: "latte://settings/general")!
        XCTAssertEqual(SettingsURLHandler.parse(url), .general)
    }

    func testTriggersPathReturnsTriggers() {
        let url = URL(string: "latte://settings/triggers")!
        XCTAssertEqual(SettingsURLHandler.parse(url), .triggers)
    }

    func testAboutPathReturnsAbout() {
        let url = URL(string: "latte://settings/about")!
        XCTAssertEqual(SettingsURLHandler.parse(url), .about)
    }

    func testActivityPathReturnsActivity() {
        let url = URL(string: "latte://settings/activity")!
        XCTAssertEqual(SettingsURLHandler.parse(url), .activity)
    }

    func testUnknownTabPathFallsBackToGeneral() {
        let url = URL(string: "latte://settings/unknown")!
        XCTAssertEqual(SettingsURLHandler.parse(url), .general)
    }

    func testWrongHostReturnsNil() {
        let url = URL(string: "latte://other/general")!
        XCTAssertNil(SettingsURLHandler.parse(url))
    }

    func testWrongSchemeReturnsNil() {
        let url = URL(string: "https://settings/general")!
        XCTAssertNil(SettingsURLHandler.parse(url))
    }

    func testAllSettingsTabsAreCovered() {
        // Ensures CaseIterable + URL parsing coverage stay in sync if a tab
        // is ever added.
        for tab in SettingsTab.allCases {
            let url = URL(string: "latte://settings/\(tab.rawValue)")!
            XCTAssertEqual(SettingsURLHandler.parse(url), tab,
                           "tab \(tab.rawValue) did not round-trip through URL parser")
        }
    }

    // MARK: - D: focus query parameter for "click row → jump to trigger config"

    func testParseRouteOnTriggersTabExtractsFocusQueryParam() {
        let url = URL(string: "latte://settings/triggers?focus=wifi")!
        let route = SettingsURLHandler.parseRoute(url)
        XCTAssertEqual(route?.tab, .triggers)
        XCTAssertEqual(route?.focusedTriggerId, "wifi")
    }

    func testParseRouteWithoutFocusReturnsNilFocus() {
        let url = URL(string: "latte://settings/triggers")!
        let route = SettingsURLHandler.parseRoute(url)
        XCTAssertEqual(route?.tab, .triggers)
        XCTAssertNil(route?.focusedTriggerId)
    }

    func testParseRouteIgnoresFocusOnNonTriggersTab() {
        // Focus is only meaningful on the Triggers tab. A bare ?focus=wifi
        // on /general should not silently land on Triggers — drop the param.
        let url = URL(string: "latte://settings/general?focus=wifi")!
        let route = SettingsURLHandler.parseRoute(url)
        XCTAssertEqual(route?.tab, .general)
        XCTAssertNil(route?.focusedTriggerId)
    }

    func testParseRouteWrongSchemeReturnsNil() {
        let url = URL(string: "https://settings/triggers?focus=wifi")!
        XCTAssertNil(SettingsURLHandler.parseRoute(url))
    }

    func testLegacyParseStillReturnsTabOnly() {
        // The pre-D `parse(_:) -> SettingsTab?` signature is preserved
        // (LatteApp calls it; we don't want to churn that call site).
        let url = URL(string: "latte://settings/triggers?focus=wifi")!
        XCTAssertEqual(SettingsURLHandler.parse(url), .triggers)
    }
}
