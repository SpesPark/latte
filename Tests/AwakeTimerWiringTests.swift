import XCTest
@testable import Latte

/// S52 B1 — end-to-end tests for the timer-expiry WIRING in
/// `AwakeManager.schedule(kind:fireAt:)`.
///
/// Every prior timer test fed expiry inputs (`.timerExpired` etc.) to the
/// pure FSM directly, so the TimerKind → AwakeInput mapping inside
/// `schedule()` — the line that decides whether a timed session ever ends —
/// had zero coverage: a wiring bug there shipped with all tests green.
/// These tests inject an instant `sleeper` (S52 seam) and await the actual
/// scheduled task, so the full path
///   public API → FSM effect → schedule() → sleeper → process(expiry)
/// is exercised.
///
/// `.snooze` wiring is NOT covered end-to-end: since S22/P-issue-6c every
/// public deactivation routes through `.constraintDeactivate`, so no public
/// API can reach `.snoozed` — the pure-FSM tests own that surface.
@MainActor
final class AwakeTimerWiringTests: XCTestCase {

    private func makeManager() -> AwakeManager {
        AwakeManager(
            assertion: MockPowerAssertion(),
            settings: InMemorySettingsStore(),
            powerSource: MockPowerSource(isOnAC: true),
            sleeper: { _ in } // instant — expiry fires as soon as the task runs
        )
    }

    func testDurationTimerExpiryEndsTimedSession() async {
        let manager = makeManager()
        manager.activate(for: .minutes(5))
        guard case .awakeUserTimed = manager.state else {
            return XCTFail("expected awakeUserTimed, got \(manager.state)")
        }
        guard let task = manager.timerTask(for: .duration) else {
            return XCTFail("activate(for:) must schedule a duration timer")
        }

        await task.value

        XCTAssertEqual(
            manager.state, .asleep,
            "duration expiry must end the timed session — kind .duration must wire to .timerExpired"
        )
        XCTAssertNil(manager.timerTask(for: .duration), "fired timer must not linger")
    }

    func testCoolDownTimerExpiryEndsCoolingDown() async {
        let manager = makeManager()
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "meeting"), from: "t1")
        guard case .awakeTriggered = manager.state else {
            return XCTFail("expected awakeTriggered, got \(manager.state)")
        }
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: false, reason: "meeting", graceSecondsAfterOff: 30),
            from: "t1")
        guard case .coolingDown = manager.state else {
            return XCTFail("expected coolingDown, got \(manager.state)")
        }
        guard let task = manager.timerTask(for: .coolDown) else {
            return XCTFail("entering coolingDown must schedule a coolDown timer")
        }

        await task.value

        // (.coolingDown, .timerExpired) is an FSM invariant violation, so a
        // mis-wired kind would NOT land in .asleep — this assert pins the
        // .coolDown → .coolDownExpired mapping specifically.
        XCTAssertEqual(
            manager.state, .asleep,
            "coolDown expiry must end the grace period — kind .coolDown must wire to .coolDownExpired"
        )
    }

    func testDeactivateCancelsPendingDurationTimer() async {
        let manager = makeManager()
        manager.activate(for: .minutes(5))
        guard let task = manager.timerTask(for: .duration) else {
            return XCTFail("activate(for:) must schedule a duration timer")
        }

        manager.deactivate()
        XCTAssertEqual(manager.state, .asleep)
        XCTAssertNil(manager.timerTask(for: .duration), "deactivate must cancel the pending timer")

        // Drain the cancelled task: its body must observe cancellation and
        // bail without feeding a late expiry into the FSM.
        await task.value
        XCTAssertEqual(
            manager.state, .asleep,
            "a cancelled duration timer must not fire a late transition"
        )
    }

    func testReactivationReplacesPendingDurationTimer() async {
        let manager = makeManager()
        manager.activate(for: .minutes(5))
        guard let first = manager.timerTask(for: .duration) else {
            return XCTFail("first activate must schedule a duration timer")
        }

        manager.activate(for: .hours(1))
        guard let second = manager.timerTask(for: .duration) else {
            return XCTFail("re-activate must schedule a replacement duration timer")
        }

        // The superseded task drains without ending the NEW session.
        await first.value
        guard case .awakeUserTimed = manager.state else {
            return XCTFail("superseded timer fired into the new session — got \(manager.state)")
        }

        await second.value
        XCTAssertEqual(manager.state, .asleep, "replacement timer must end the session")
    }
}
