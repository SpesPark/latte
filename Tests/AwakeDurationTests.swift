import XCTest
@testable import Latte

final class AwakeDurationTests: XCTestCase {

    func testSecondsForMinutes() {
        XCTAssertEqual(AwakeDuration.minutes(5).seconds, 300)
        XCTAssertEqual(AwakeDuration.minutes(30).seconds, 1800)
    }

    func testSecondsForHours() {
        XCTAssertEqual(AwakeDuration.hours(1).seconds, 3600)
        XCTAssertEqual(AwakeDuration.hours(2).seconds, 7200)
    }

    func testSecondsForIndefiniteIsNil() {
        XCTAssertNil(AwakeDuration.indefinite.seconds)
    }

    func testIsFinite() {
        XCTAssertTrue(AwakeDuration.minutes(5).isFinite)
        XCTAssertTrue(AwakeDuration.hours(1).isFinite)
        XCTAssertFalse(AwakeDuration.indefinite.isFinite)
    }

    func testLabels() {
        XCTAssertEqual(AwakeDuration.minutes(5).label, "5 minutes")
        XCTAssertEqual(AwakeDuration.hours(1).label, "1 hour")
        XCTAssertEqual(AwakeDuration.hours(2).label, "2 hours")
        XCTAssertEqual(AwakeDuration.indefinite.label, "Indefinitely")
    }

    func testPresetsMatchPRD() {
        let presets = AwakeDuration.presets
        XCTAssertEqual(presets.count, 7)
        XCTAssertEqual(presets[0], .minutes(5))
        XCTAssertEqual(presets[1], .minutes(15))
        XCTAssertEqual(presets[2], .minutes(30))
        XCTAssertEqual(presets[3], .hours(1))
        XCTAssertEqual(presets[4], .hours(2))
        XCTAssertEqual(presets[5], .hours(5))
        XCTAssertEqual(presets[6], .indefinite)
    }
}
