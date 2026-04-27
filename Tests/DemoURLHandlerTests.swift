import XCTest
@testable import Latte

final class DemoURLHandlerTests: XCTestCase {

    func testBareCupURLReturnsDefaultConfig() {
        let url = URL(string: "latte://demo/cup")!
        guard case .cup(let cfg) = DemoURLHandler.parse(url) else {
            return XCTFail("expected .cup, got nil/other")
        }
        XCTAssertEqual(cfg.fillRatio, 1.0, accuracy: 0.001)
        XCTAssertEqual(cfg.accent, .default)
        XCTAssertTrue(cfg.isAwake)
    }

    func testFillParameterParsed() {
        let url = URL(string: "latte://demo/cup?fill=0.55")!
        guard case .cup(let cfg) = DemoURLHandler.parse(url) else {
            return XCTFail("expected .cup")
        }
        XCTAssertEqual(cfg.fillRatio, 0.55, accuracy: 0.001)
    }

    func testAccentParameterParsed() {
        let url = URL(string: "latte://demo/cup?accent=caramel")!
        guard case .cup(let cfg) = DemoURLHandler.parse(url) else {
            return XCTFail("expected .cup")
        }
        XCTAssertEqual(cfg.accent, .caramel)
    }

    func testAwakeParameterFalseParsed() {
        let url = URL(string: "latte://demo/cup?awake=false")!
        guard case .cup(let cfg) = DemoURLHandler.parse(url) else {
            return XCTFail("expected .cup")
        }
        XCTAssertFalse(cfg.isAwake)
    }

    func testCombinedParameters() {
        let url = URL(string: "latte://demo/cup?fill=0.6&accent=mocha&awake=true")!
        guard case .cup(let cfg) = DemoURLHandler.parse(url) else {
            return XCTFail("expected .cup")
        }
        XCTAssertEqual(cfg.fillRatio, 0.6, accuracy: 0.001)
        XCTAssertEqual(cfg.accent, .mocha)
        XCTAssertTrue(cfg.isAwake)
    }

    func testFillIsClampedBelowZero() {
        let url = URL(string: "latte://demo/cup?fill=-1.5")!
        guard case .cup(let cfg) = DemoURLHandler.parse(url) else {
            return XCTFail("expected .cup")
        }
        XCTAssertEqual(cfg.fillRatio, 0.0)
    }

    func testFillIsClampedAboveOne() {
        let url = URL(string: "latte://demo/cup?fill=2.5")!
        guard case .cup(let cfg) = DemoURLHandler.parse(url) else {
            return XCTFail("expected .cup")
        }
        XCTAssertEqual(cfg.fillRatio, 1.0)
    }

    func testInvalidAccentFallsBackToDefault() {
        let url = URL(string: "latte://demo/cup?accent=puce")!
        guard case .cup(let cfg) = DemoURLHandler.parse(url) else {
            return XCTFail("expected .cup")
        }
        XCTAssertEqual(cfg.accent, .default)
    }

    func testWrongHostReturnsNil() {
        XCTAssertNil(DemoURLHandler.parse(URL(string: "latte://other/cup")!))
    }

    func testWrongPathReturnsNil() {
        XCTAssertNil(DemoURLHandler.parse(URL(string: "latte://demo/triggers")!))
    }

    func testWrongSchemeReturnsNil() {
        XCTAssertNil(DemoURLHandler.parse(URL(string: "https://demo/cup")!))
    }

    func testSettingsURLDoesNotMatchDemoHandler() {
        // Make sure demo and settings handlers don't fight each other.
        XCTAssertNil(DemoURLHandler.parse(URL(string: "latte://settings/general")!))
    }
}
