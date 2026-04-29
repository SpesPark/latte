import XCTest
@testable import Latte

final class AssertionStatusFormatterTests: XCTestCase {

    // MARK: - stateLabel

    func testStateLabelAwake() {
        XCTAssertEqual(AssertionStatusFormatter.stateLabel(isAwake: true), "Awake")
    }

    func testStateLabelAsleep() {
        XCTAssertEqual(AssertionStatusFormatter.stateLabel(isAwake: false), "Asleep")
    }

    // MARK: - modeLabel

    func testModeLabelNilWhenAsleep() {
        XCTAssertNil(AssertionStatusFormatter.modeLabel(isAwake: false, allowDisplaySleep: false))
        XCTAssertNil(AssertionStatusFormatter.modeLabel(isAwake: false, allowDisplaySleep: true))
    }

    func testModeLabelDisplayPlusSystemWhenAwakeAndAllowDisplayOff() {
        XCTAssertEqual(
            AssertionStatusFormatter.modeLabel(isAwake: true, allowDisplaySleep: false),
            "System + display awake"
        )
    }

    func testModeLabelSystemOnlyWhenAwakeAndAllowDisplayOn() {
        XCTAssertEqual(
            AssertionStatusFormatter.modeLabel(isAwake: true, allowDisplaySleep: true),
            "System awake (display may sleep)"
        )
    }

    // MARK: - reasonLabel

    func testReasonLabelUser() {
        XCTAssertEqual(
            AssertionStatusFormatter.reasonLabel(.user),
            "Manually activated"
        )
    }

    func testReasonLabelTriggerWithVoteReason() {
        XCTAssertEqual(
            AssertionStatusFormatter.reasonLabel(
                .trigger(id: "calendar"),
                triggerReason: "Calendar: Standup"
            ),
            "Calendar: Standup"
        )
    }

    func testReasonLabelTriggerWithoutVoteReasonFallsBackToGeneric() {
        XCTAssertEqual(
            AssertionStatusFormatter.reasonLabel(.trigger(id: "calendar")),
            "Trigger active"
        )
    }

    func testReasonLabelTriggerWithEmptyVoteReasonFallsBackToGeneric() {
        XCTAssertEqual(
            AssertionStatusFormatter.reasonLabel(.trigger(id: "calendar"), triggerReason: ""),
            "Trigger active"
        )
    }

    func testReasonLabelLaunch() {
        XCTAssertEqual(AssertionStatusFormatter.reasonLabel(.launch), "Activated at launch")
    }

    func testReasonLabelNone() {
        XCTAssertEqual(AssertionStatusFormatter.reasonLabel(.none), "Idle")
    }

    // MARK: - powerLabel

    func testPowerLabelNilWhenRequireACOff() {
        // Don't clutter the About tab unless the user opted in.
        XCTAssertNil(AssertionStatusFormatter.powerLabel(isOnAC: true, requireACForAwake: false))
        XCTAssertNil(AssertionStatusFormatter.powerLabel(isOnAC: false, requireACForAwake: false))
    }

    func testPowerLabelOnAC() {
        XCTAssertEqual(
            AssertionStatusFormatter.powerLabel(isOnAC: true, requireACForAwake: true),
            "On AC power"
        )
    }

    func testPowerLabelOnBattery() {
        XCTAssertEqual(
            AssertionStatusFormatter.powerLabel(isOnAC: false, requireACForAwake: true),
            "On battery — Latte is suspended"
        )
    }
}
