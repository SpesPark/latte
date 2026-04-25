import XCTest
@testable import Caffeinated

@MainActor
final class AwakeManagerTests: XCTestCase {

    func testInitialState() {
        let manager = AwakeManager()
        XCTAssertFalse(manager.isAwake)
        XCTAssertNil(manager.endsAt)
        XCTAssertNil(manager.activeDuration)
    }

    func testToggleActivatesAndDeactivates() {
        let manager = AwakeManager()

        manager.toggle()
        XCTAssertTrue(manager.isAwake)
        XCTAssertEqual(manager.activeDuration, .indefinite)
        XCTAssertNil(manager.endsAt, "Indefinite duration should not set an end date")

        manager.toggle()
        XCTAssertFalse(manager.isAwake)
        XCTAssertNil(manager.activeDuration)
    }

    func testActivateForFiniteDurationSetsEndsAt() {
        let manager = AwakeManager()
        let before = Date()

        manager.activate(for: .minutes(5))

        XCTAssertTrue(manager.isAwake)
        XCTAssertEqual(manager.activeDuration, .minutes(5))
        XCTAssertNotNil(manager.endsAt)
        if let endsAt = manager.endsAt {
            let expectedSeconds = before.addingTimeInterval(300).timeIntervalSinceReferenceDate
            XCTAssertEqual(endsAt.timeIntervalSinceReferenceDate, expectedSeconds, accuracy: 1.0)
        }

        manager.deactivate()
    }

    func testReactivatingReplacesPreviousState() {
        let manager = AwakeManager()
        manager.activate(for: .minutes(15))
        XCTAssertEqual(manager.activeDuration, .minutes(15))

        manager.activate(for: .hours(2))
        XCTAssertEqual(manager.activeDuration, .hours(2))
        XCTAssertTrue(manager.isAwake)

        manager.deactivate()
    }
}

final class AwakeDurationTests: XCTestCase {

    func testLabels() {
        XCTAssertEqual(AwakeDuration.minutes(5).label, "5 minutes")
        XCTAssertEqual(AwakeDuration.minutes(30).label, "30 minutes")
        XCTAssertEqual(AwakeDuration.hours(1).label, "1 hour")
        XCTAssertEqual(AwakeDuration.hours(2).label, "2 hours")
        XCTAssertEqual(AwakeDuration.indefinite.label, "Indefinitely")
    }

    func testSeconds() {
        XCTAssertEqual(AwakeDuration.minutes(5).seconds, 300)
        XCTAssertEqual(AwakeDuration.minutes(30).seconds, 1800)
        XCTAssertEqual(AwakeDuration.hours(1).seconds, 3600)
        XCTAssertEqual(AwakeDuration.hours(2).seconds, 7200)
        XCTAssertNil(AwakeDuration.indefinite.seconds)
    }

    func testPresetsContainExpectedDurations() {
        let presets = AwakeDuration.presets
        XCTAssertTrue(presets.contains(.minutes(5)))
        XCTAssertTrue(presets.contains(.hours(1)))
        XCTAssertTrue(presets.contains(.indefinite))
    }
}
