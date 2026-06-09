import XCTest
@testable import Latte

/// Pins the IOPM assertion ACQUISITION-FAILURE path (S51 audit finding):
/// `applyEffects` previously discarded `activate()`'s Bool, so when
/// `IOPMAssertionCreateWithName` failed the manager kept publishing
/// `isAwake = true` (full cup in the UI) while no assertion was held — the
/// Mac could sleep mid-"awake" session with no indication. The manager must
/// instead return to `.asleep` through the constraint-deactivate path.
@MainActor
final class AwakeAssertionFailureTests: XCTestCase {

    private func makeManager() -> (AwakeManager, MockPowerAssertion) {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        let manager = AwakeManager(assertion: assertion, settings: settings)
        return (manager, assertion)
    }

    /// The recovery is deferred one main-actor turn (it cannot re-enter
    /// `process()` mid-transition), so give the queued task a chance to run.
    private func drainMainQueue() async {
        for _ in 0..<20 { await Task.yield() }
    }

    func testManualActivateFailureReturnsToAsleep() async {
        let (manager, assertion) = makeManager()
        assertion.failNextActivate = true

        manager.activate(for: .indefinite)
        await drainMainQueue()

        XCTAssertEqual(manager.state, .asleep)
        XCTAssertFalse(manager.isAwake)
        XCTAssertFalse(assertion.isActive)
    }

    func testTriggerVoteActivateFailureReturnsToAsleep() async {
        let (manager, assertion) = makeManager()
        assertion.failNextActivate = true

        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "on", graceSecondsAfterOff: 0),
            from: "t"
        )
        await drainMainQueue()

        XCTAssertEqual(manager.state, .asleep)
        XCTAssertFalse(manager.isAwake)
        XCTAssertFalse(assertion.isActive)
    }

    func testTimedActivateFailureCancelsPendingDurationTimer() async {
        let (manager, assertion) = makeManager()
        assertion.failNextActivate = true

        manager.activate(for: .minutes(30))
        await drainMainQueue()

        XCTAssertEqual(manager.state, .asleep)
        XCTAssertNil(manager.endsAt)
    }

    func testActivateSuccessIsUnaffected() async {
        let (manager, assertion) = makeManager()

        manager.activate(for: .indefinite)
        await drainMainQueue()

        XCTAssertTrue(manager.isAwake)
        XCTAssertTrue(assertion.isActive)
    }

    /// If a later transition re-acquired the assertion before the deferred
    /// recovery runs, the recovery must not tear the new session down.
    func testRecoverySkippedWhenAssertionActiveAgain() async {
        let (manager, assertion) = makeManager()
        assertion.failNextActivate = true

        manager.activate(for: .indefinite)
        // Second activation succeeds before the deferred check runs.
        manager.deactivate()
        manager.activate(for: .indefinite)
        await drainMainQueue()

        XCTAssertTrue(manager.isAwake)
        XCTAssertTrue(assertion.isActive)
    }
}
