import XCTest
@testable import Latte

/// Tests assert that the formatter returns the locale-resolved version
/// of the expected catalog key — NOT a hardcoded English string. This
/// keeps the tests stable across CI/owner machines with different
/// system languages (S33 fix: ko-locale Macs were failing because the
/// previous assertions hardcoded "Awake" etc.; the formatter correctly
/// returned "깨어 있음" on those hosts).
///
/// Pattern: `XCTAssertEqual(formatter.x(), String(localized: "Key"))`
/// — the right-hand side resolves the same key through the same
/// mechanism the formatter uses, so both sides shift together when
/// the host changes locale.
final class AssertionStatusFormatterTests: XCTestCase {

    // MARK: - stateLabel

    func testStateLabelAwake() {
        XCTAssertEqual(AssertionStatusFormatter.stateLabel(isAwake: true), String(localized: "Awake"))
    }

    func testStateLabelAsleep() {
        XCTAssertEqual(AssertionStatusFormatter.stateLabel(isAwake: false), String(localized: "Asleep"))
    }

    // MARK: - modeLabel

    func testModeLabelNilWhenAsleep() {
        XCTAssertNil(AssertionStatusFormatter.modeLabel(isAwake: false, allowDisplaySleep: false))
        XCTAssertNil(AssertionStatusFormatter.modeLabel(isAwake: false, allowDisplaySleep: true))
    }

    func testModeLabelDisplayPlusSystemWhenAwakeAndAllowDisplayOff() {
        XCTAssertEqual(
            AssertionStatusFormatter.modeLabel(isAwake: true, allowDisplaySleep: false),
            String(localized: "System + display awake")
        )
    }

    func testModeLabelSystemOnlyWhenAwakeAndAllowDisplayOn() {
        XCTAssertEqual(
            AssertionStatusFormatter.modeLabel(isAwake: true, allowDisplaySleep: true),
            String(localized: "System awake (display may sleep)")
        )
    }

    // MARK: - reasonLabel

    func testReasonLabelUser() {
        XCTAssertEqual(
            AssertionStatusFormatter.reasonLabel(.user),
            String(localized: "Manually activated")
        )
    }

    func testReasonLabelTriggerWithVoteReason() {
        // triggerReason is a runtime-supplied string (e.g. event title)
        // and is intentionally NOT localized — it's passed through verbatim.
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
            String(localized: "Trigger active")
        )
    }

    func testReasonLabelTriggerWithEmptyVoteReasonFallsBackToGeneric() {
        XCTAssertEqual(
            AssertionStatusFormatter.reasonLabel(.trigger(id: "calendar"), triggerReason: ""),
            String(localized: "Trigger active")
        )
    }

    func testReasonLabelLaunch() {
        XCTAssertEqual(AssertionStatusFormatter.reasonLabel(.launch), String(localized: "Activated at launch"))
    }

    func testReasonLabelNone() {
        XCTAssertEqual(AssertionStatusFormatter.reasonLabel(.none), String(localized: "Idle"))
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
            String(localized: "On AC power")
        )
    }

    func testPowerLabelOnBattery() {
        XCTAssertEqual(
            AssertionStatusFormatter.powerLabel(isOnAC: false, requireACForAwake: true),
            String(localized: "On battery — Latte is suspended")
        )
    }
}
