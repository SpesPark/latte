import XCTest
@testable import Latte

@MainActor
final class MockPowerSourceTests: XCTestCase {

    func testInitialIsOnACReflectsConstructorArg() {
        XCTAssertTrue(MockPowerSource(isOnAC: true).isOnAC)
        XCTAssertFalse(MockPowerSource(isOnAC: false).isOnAC)
    }

    func testObserveFiresOnTransition() {
        let source = MockPowerSource(isOnAC: true)
        var snapshots: [Bool] = []
        let obs = source.observe { snapshots.append($0) }
        source.isOnAC = false
        source.isOnAC = true
        source.isOnAC = true // no-op (no change)
        XCTAssertEqual(snapshots, [false, true])
        obs.cancel()
    }

    func testObserveCancelStopsCallbacks() {
        let source = MockPowerSource(isOnAC: true)
        var hits = 0
        let obs = source.observe { _ in hits += 1 }
        source.isOnAC = false
        XCTAssertEqual(hits, 1)
        obs.cancel()
        source.isOnAC = true
        XCTAssertEqual(hits, 1, "post-cancel events should not fire")
    }

    func testObserveSupportsMultipleListeners() {
        let source = MockPowerSource(isOnAC: true)
        var a = 0, b = 0
        let oa = source.observe { _ in a += 1 }
        let ob = source.observe { _ in b += 1 }
        source.isOnAC = false
        XCTAssertEqual(a, 1)
        XCTAssertEqual(b, 1)
        oa.cancel(); ob.cancel()
    }

    /// A callback that cancels its own (or a sibling's) observation during
    /// fan-out must not mutate the observers collection mid-enumeration.
    /// The fan-out copies the values before iterating; without that copy
    /// this removal would be a mutate-during-iterate crash.
    func testCancelFromWithinCallbackDoesNotCrashFanOut() {
        let source = MockPowerSource(isOnAC: true)
        var firstHits = 0
        var secondHits = 0
        var firstObs: PowerSourceObservation?
        firstObs = source.observe { _ in
            firstHits += 1
            firstObs?.cancel() // remove self from `observers` mid-fan-out
        }
        let secondObs = source.observe { _ in secondHits += 1 }
        defer { firstObs?.cancel(); secondObs.cancel() }

        source.isOnAC = false // triggers fan-out over both observers

        XCTAssertEqual(firstHits, 1)
        XCTAssertEqual(secondHits, 1, "sibling observer must still fire despite self-cancel")
        source.isOnAC = true
        XCTAssertEqual(firstHits, 1, "cancelled observer must not fire again")
        XCTAssertEqual(secondHits, 2)
    }
}

@MainActor
final class AwakeManagerConstraintsTests: XCTestCase {

    private func makeManager(
        isOnAC: Bool = true,
        requireAC: Bool = false,
        paused: Bool = false
    ) -> (AwakeManager, MockPowerAssertion, MockPowerSource, InMemorySettingsStore) {
        let assertion = MockPowerAssertion()
        let powerSource = MockPowerSource(isOnAC: isOnAC)
        let settings = InMemorySettingsStore()
        settings.setBool(requireAC, for: .requireACForAwake)
        settings.setBool(paused, for: .triggersPaused)
        let manager = AwakeManager(
            assertion: assertion,
            settings: settings,
            powerSource: powerSource
        )
        return (manager, assertion, powerSource, settings)
    }

    // MARK: - Hydration

    func testHydratesFromSettings() {
        let (manager, _, _, _) = makeManager(requireAC: true, paused: true)
        XCTAssertTrue(manager.requireACForAwake)
        XCTAssertTrue(manager.triggersPaused)
    }

    func testIsOnACReflectsPowerSource() {
        let (m1, _, _, _) = makeManager(isOnAC: true)
        XCTAssertTrue(m1.isOnAC)
        let (m2, _, _, _) = makeManager(isOnAC: false)
        XCTAssertFalse(m2.isOnAC)
    }

    func testFlagWritesPersistToSettings() {
        let (manager, _, _, settings) = makeManager()
        manager.requireACForAwake = true
        XCTAssertTrue(settings.bool(.requireACForAwake, default: false))
        manager.triggersPaused = true
        XCTAssertTrue(settings.bool(.triggersPaused, default: false))
    }

    // MARK: - C-1 battery-aware

    func testManualActivationBlockedOnBatteryWhenRequireACOn() {
        let (manager, assertion, _, _) = makeManager(isOnAC: false, requireAC: true)
        manager.activate(for: .indefinite)
        XCTAssertFalse(manager.isAwake)
        XCTAssertTrue(assertion.activations.isEmpty)
    }

    func testManualActivationAllowedOnBatteryWhenRequireACOff() {
        let (manager, assertion, _, _) = makeManager(isOnAC: false, requireAC: false)
        manager.activate(for: .indefinite)
        XCTAssertTrue(manager.isAwake)
        XCTAssertEqual(assertion.activations.count, 1)
    }

    func testManualActivationAllowedOnACWhenRequireACOn() {
        let (manager, assertion, _, _) = makeManager(isOnAC: true, requireAC: true)
        manager.activate(for: .indefinite)
        XCTAssertTrue(manager.isAwake)
        XCTAssertEqual(assertion.activations.count, 1)
    }

    func testTriggerVoteBlockedOnBatteryWhenRequireACOn() {
        let (manager, assertion, _, _) = makeManager(isOnAC: false, requireAC: true)
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "Calendar: Standup"),
            from: "calendar"
        )
        XCTAssertFalse(manager.isAwake)
        XCTAssertTrue(assertion.activations.isEmpty)
    }

    func testFlippingRequireACOnWhileAwakeReleasesIfOnBattery() {
        let (manager, assertion, _, _) = makeManager(isOnAC: false, requireAC: false)
        manager.activate(for: .indefinite)
        XCTAssertTrue(manager.isAwake)
        manager.requireACForAwake = true
        XCTAssertFalse(manager.isAwake)
        XCTAssertGreaterThanOrEqual(assertion.deactivationCount, 1)
    }

    func testFlippingRequireACOnWhileAwakeDoesNotReleaseIfOnAC() {
        let (manager, assertion, _, _) = makeManager(isOnAC: true, requireAC: false)
        manager.activate(for: .indefinite)
        XCTAssertTrue(manager.isAwake)
        manager.requireACForAwake = true
        XCTAssertTrue(manager.isAwake, "still on AC — constraint not violated")
        XCTAssertEqual(assertion.deactivationCount, 0)
    }

    func testUnpluggingACWhileAwakeReleasesWhenRequireACOn() {
        let (manager, assertion, powerSource, _) = makeManager(isOnAC: true, requireAC: true)
        manager.activate(for: .indefinite)
        XCTAssertTrue(manager.isAwake)
        powerSource.isOnAC = false
        XCTAssertFalse(manager.isOnAC == true)
        XCTAssertFalse(manager.isAwake)
        XCTAssertGreaterThanOrEqual(assertion.deactivationCount, 1)
    }

    func testUnpluggingACWhileAwakeDoesNotReleaseWhenRequireACOff() {
        let (manager, _, powerSource, _) = makeManager(isOnAC: true, requireAC: false)
        manager.activate(for: .indefinite)
        powerSource.isOnAC = false
        XCTAssertTrue(manager.isAwake, "feature off — battery should not affect awake state")
    }

    func testReplugACAfterBlockDoesNotAutoReactivate() {
        // C-1 explicitly does NOT auto-reactivate when AC returns. The user
        // (or trigger) must re-engage explicitly. Otherwise unattended
        // battery cycles would silently re-acquire the assertion.
        let (manager, _, powerSource, _) = makeManager(isOnAC: true, requireAC: true)
        manager.activate(for: .indefinite)
        powerSource.isOnAC = false
        XCTAssertFalse(manager.isAwake)
        powerSource.isOnAC = true
        XCTAssertFalse(manager.isAwake, "no auto-reactivate after AC returns")
    }

    // MARK: - C-9 pause-all

    func testTriggerVoteIgnoredWhenPaused() {
        let (manager, assertion, _, _) = makeManager(paused: true)
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "Calendar: Standup"),
            from: "calendar"
        )
        XCTAssertFalse(manager.isAwake)
        XCTAssertTrue(assertion.activations.isEmpty)
    }

    func testManualActivationStillWorksWhenPaused() {
        let (manager, assertion, _, _) = makeManager(paused: true)
        manager.activate(for: .indefinite)
        XCTAssertTrue(manager.isAwake, "pause is for triggers, not user intent")
        XCTAssertEqual(assertion.activations.count, 1)
    }

    func testFlippingPausedOnWhileTriggeredAwakeReleases() {
        let (manager, assertion, _, _) = makeManager()
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "Calendar: Standup"),
            from: "calendar"
        )
        XCTAssertTrue(manager.isAwake)
        manager.triggersPaused = true
        XCTAssertFalse(manager.isAwake)
        XCTAssertGreaterThanOrEqual(assertion.deactivationCount, 1)
    }

    /// **S22 / P-issue-5**: pause-all from `.awakeTriggered` previously routed
    /// through `.userDeactivate` → `enterSnoozed` which set `endsAt = now + 5min`
    /// and `activeReason = .user`. The header rendered "Until 12:27 AM"
    /// caption — a misleading user-timed-session signal even though the user
    /// only paused triggers. Owner-reported during the resumed Step 6
    /// manual smoke. After fix: constraint-driven deactivate goes
    /// directly to `.asleep`, clears pendingVotes, sets `activeReason = .none`,
    /// no countdown caption.
    func testPauseAllFromTriggeredClearsCaptionAndReason() {
        let (manager, _, _, _) = makeManager()
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "App: Notion"),
            from: "AppTrigger"
        )
        XCTAssertTrue(manager.isAwake)
        XCTAssertEqual(manager.activeReason, .trigger(id: "AppTrigger"))

        manager.triggersPaused = true

        XCTAssertFalse(manager.isAwake, "cup empties on pause")
        XCTAssertNil(manager.endsAt, "no countdown caption from constraint-driven deactivation")
        XCTAssertEqual(manager.activeReason, .none, "reason cleared when constraint forces sleep — not .user")
    }

    /// **S22 / P-issue-5**: when triggersPaused flips OFF, AwakeManager posts
    /// `.latteTriggerPauseDidLift` so the TriggerCoordinator can re-evaluate
    /// every enabled trigger and re-emit current votes (otherwise the cup
    /// stays asleep until the underlying trigger naturally re-fires, which
    /// owner observed as "doesn't auto-recover after pause OFF").
    func testUnpausingPostsTriggerPauseDidLiftNotification() {
        let (manager, _, _, _) = makeManager(paused: true)
        let exp = XCTNSNotificationExpectation(name: .latteTriggerPauseDidLift)
        manager.triggersPaused = false
        wait(for: [exp], timeout: 1.0)
    }

    /// Pausing ON must NOT post the lift notification — only the OFF
    /// transition does.
    func testPausingOnDoesNotPostLiftNotification() {
        let (manager, _, _, _) = makeManager()
        let exp = XCTNSNotificationExpectation(name: .latteTriggerPauseDidLift)
        exp.isInverted = true
        manager.triggersPaused = true
        wait(for: [exp], timeout: 0.3)
    }

    func testFlippingPausedOnWhileManualAwakeDoesNotRelease() {
        let (manager, _, _, _) = makeManager()
        manager.activate(for: .indefinite)
        XCTAssertTrue(manager.isAwake)
        manager.triggersPaused = true
        XCTAssertTrue(manager.isAwake, "manual awake outlives pause-all")
    }

    func testUnpausingDoesNotAutoReactivate() {
        let (manager, _, _, _) = makeManager(paused: true)
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "Calendar: Standup"),
            from: "calendar"
        )
        XCTAssertFalse(manager.isAwake)
        manager.triggersPaused = false
        XCTAssertFalse(manager.isAwake, "no replay; trigger must re-vote")
    }

    func testTriggerOFFVoteFlowsEvenWhilePaused() {
        // OFF votes always flow — they update pendingVotes so post-unpause
        // state isn't stuck on a stale ON.
        let (manager, _, _, _) = makeManager()
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "Calendar: Standup"),
            from: "calendar"
        )
        XCTAssertTrue(manager.isAwake)
        manager.triggersPaused = true
        XCTAssertFalse(manager.isAwake)
        // Trigger says OFF while paused; should not error / should clear pending.
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: false, reason: "Calendar: no active events"),
            from: "calendar"
        )
        manager.triggersPaused = false
        // After unpause, no replay even with empty pending → still asleep.
        XCTAssertFalse(manager.isAwake)
    }

    // MARK: - Combined

    func testBothFlagsOnBlocksEverything() {
        let (manager, _, _, _) = makeManager(isOnAC: false, requireAC: true, paused: true)
        manager.activate(for: .indefinite)
        XCTAssertFalse(manager.isAwake)
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "x"),
            from: "calendar"
        )
        XCTAssertFalse(manager.isAwake)
    }
}
