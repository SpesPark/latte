import XCTest
@testable import Latte

// MARK: - State machine: cell-by-cell tests for 03 §7 transition table.

final class AwakeStateMachineTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func step(
        state: AwakeState,
        pending: [String: TriggerVote] = [:],
        input: AwakeInput,
        at when: Date? = nil
    ) -> AwakeStepResult {
        AwakeStateMachine.step(state: state, pendingVotes: pending, input: input, now: when ?? now)
    }

    private var voteOn: TriggerVote {
        TriggerVote(wantsAwake: true, reason: "Test")
    }
    private var voteOff: TriggerVote {
        TriggerVote(wantsAwake: false, reason: "Test off")
    }

    // MARK: Asleep row

    func testAsleep_userActivateFinite_goesToAwakeUserTimed() {
        let result = step(state: .asleep, input: .userActivate(.minutes(30)))
        if case .awakeUserTimed(let endsAt) = result.state {
            XCTAssertEqual(endsAt.timeIntervalSinceReferenceDate, now.addingTimeInterval(1800).timeIntervalSinceReferenceDate, accuracy: 0.001)
        } else {
            XCTFail("expected awakeUserTimed, got \(result.state)")
        }
        XCTAssertTrue(result.effects.contains(.acquireAssertion))
        XCTAssertTrue(result.effects.contains(where: {
            if case .scheduleTimer(.duration, _) = $0 { return true } else { return false }
        }))
    }

    func testAsleep_userActivateIndefinite_goesToAwakeUserIndefinite() {
        let result = step(state: .asleep, input: .userActivate(.indefinite))
        XCTAssertEqual(result.state, .awakeUserIndefinite)
        XCTAssertTrue(result.effects.contains(.acquireAssertion))
    }

    func testAsleep_userDeactivate_isNoop() {
        let result = step(state: .asleep, input: .userDeactivate)
        XCTAssertEqual(result.state, .asleep)
        XCTAssertTrue(result.effects.isEmpty)
    }

    func testAsleep_userToggle_goesToAwakeUserIndefinite() {
        let result = step(state: .asleep, input: .userToggle)
        XCTAssertEqual(result.state, .awakeUserIndefinite)
        XCTAssertTrue(result.effects.contains(.acquireAssertion))
    }

    func testAsleep_triggerVoteOn_goesToAwakeTriggered() {
        let result = step(state: .asleep, input: .triggerVoteOn(id: "cal", vote: voteOn))
        if case .awakeTriggered(let votes) = result.state {
            XCTAssertEqual(votes.count, 1)
            XCTAssertEqual(votes["cal"], voteOn)
        } else {
            XCTFail("expected awakeTriggered, got \(result.state)")
        }
        XCTAssertTrue(result.effects.contains(.acquireAssertion))
    }

    func testAsleep_triggerVoteOff_isNoop() {
        let result = step(state: .asleep, input: .triggerVoteOff(id: "cal", graceSeconds: 0))
        XCTAssertEqual(result.state, .asleep)
        XCTAssertTrue(result.effects.isEmpty)
    }

    // MARK: AwakeUserIndefinite row

    func testAwakeUserIndefinite_userActivateFinite_replacesWithTimed() {
        let result = step(state: .awakeUserIndefinite, input: .userActivate(.minutes(15)))
        if case .awakeUserTimed = result.state {
            // ok
        } else {
            XCTFail()
        }
        // Already held; no acquire effect.
        XCTAssertFalse(result.effects.contains(.acquireAssertion))
    }

    func testAwakeUserIndefinite_userDeactivate_noVotes_goesToAsleep() {
        let result = step(state: .awakeUserIndefinite, input: .userDeactivate)
        XCTAssertEqual(result.state, .asleep)
        XCTAssertTrue(result.effects.contains(.releaseAssertion))
    }

    func testAwakeUserIndefinite_userDeactivate_withShadowVotes_goesToSnoozed() {
        let result = step(
            state: .awakeUserIndefinite,
            pending: ["cal": voteOn],
            input: .userDeactivate
        )
        if case .snoozed(let until) = result.state {
            XCTAssertEqual(until.timeIntervalSinceReferenceDate, now.addingTimeInterval(300).timeIntervalSinceReferenceDate, accuracy: 0.001)
        } else {
            XCTFail()
        }
        XCTAssertTrue(result.effects.contains(.releaseAssertion))
        XCTAssertTrue(result.effects.contains(where: {
            if case .scheduleTimer(.snooze, _) = $0 { return true } else { return false }
        }))
    }

    func testAwakeUserIndefinite_userToggle_desugarsToDeactivate() {
        let result = step(state: .awakeUserIndefinite, input: .userToggle)
        XCTAssertEqual(result.state, .asleep)
    }

    func testAwakeUserIndefinite_triggerVoteOn_recordsShadow() {
        let result = step(state: .awakeUserIndefinite, input: .triggerVoteOn(id: "cal", vote: voteOn))
        XCTAssertEqual(result.state, .awakeUserIndefinite)
        XCTAssertEqual(result.pendingVotes["cal"], voteOn)
        XCTAssertTrue(result.effects.isEmpty)
    }

    func testAwakeUserIndefinite_triggerVoteOff_dropsShadow() {
        let result = step(
            state: .awakeUserIndefinite,
            pending: ["cal": voteOn],
            input: .triggerVoteOff(id: "cal", graceSeconds: 0)
        )
        XCTAssertEqual(result.state, .awakeUserIndefinite)
        XCTAssertNil(result.pendingVotes["cal"])
    }

    // MARK: AwakeUserTimed row

    func testAwakeUserTimed_userActivate_replacesTimer() {
        let oldEnd = now.addingTimeInterval(900)
        let result = step(state: .awakeUserTimed(endsAt: oldEnd), input: .userActivate(.hours(2)))
        if case .awakeUserTimed(let endsAt) = result.state {
            XCTAssertEqual(endsAt.timeIntervalSinceReferenceDate, now.addingTimeInterval(7200).timeIntervalSinceReferenceDate, accuracy: 0.001)
        } else { XCTFail() }
        XCTAssertTrue(result.effects.contains(.cancelTimer(kind: .duration)))
    }

    func testAwakeUserTimed_userDeactivate_noVotes_goesToAsleep() {
        let result = step(state: .awakeUserTimed(endsAt: now.addingTimeInterval(60)), input: .userDeactivate)
        XCTAssertEqual(result.state, .asleep)
        XCTAssertTrue(result.effects.contains(.releaseAssertion))
        XCTAssertTrue(result.effects.contains(.cancelTimer(kind: .duration)))
    }

    func testAwakeUserTimed_userDeactivate_withShadowVotes_goesToSnoozed() {
        let result = step(
            state: .awakeUserTimed(endsAt: now.addingTimeInterval(60)),
            pending: ["cal": voteOn],
            input: .userDeactivate
        )
        if case .snoozed = result.state {} else { XCTFail() }
        XCTAssertTrue(result.effects.contains(.cancelTimer(kind: .duration)))
    }

    func testAwakeUserTimed_userToggle_desugarsToDeactivate() {
        let result = step(state: .awakeUserTimed(endsAt: now.addingTimeInterval(60)), input: .userToggle)
        XCTAssertEqual(result.state, .asleep)
    }

    func testAwakeUserTimed_triggerVoteOn_recordsShadow() {
        let result = step(
            state: .awakeUserTimed(endsAt: now.addingTimeInterval(60)),
            input: .triggerVoteOn(id: "cal", vote: voteOn)
        )
        XCTAssertEqual(result.pendingVotes["cal"], voteOn)
    }

    func testAwakeUserTimed_triggerVoteOff_dropsShadow() {
        let result = step(
            state: .awakeUserTimed(endsAt: now.addingTimeInterval(60)),
            pending: ["cal": voteOn],
            input: .triggerVoteOff(id: "cal", graceSeconds: 0)
        )
        XCTAssertNil(result.pendingVotes["cal"])
    }

    func testAwakeUserTimed_timerExpired_withShadowVotes_promotesToTriggered() {
        let result = step(
            state: .awakeUserTimed(endsAt: now),
            pending: ["cal": voteOn],
            input: .timerExpired
        )
        if case .awakeTriggered(let votes) = result.state {
            XCTAssertEqual(votes["cal"], voteOn)
        } else { XCTFail() }
        XCTAssertTrue(result.pendingVotes.isEmpty)
        XCTAssertFalse(result.effects.contains(.releaseAssertion))
    }

    func testAwakeUserTimed_timerExpired_noVotes_goesToAsleep() {
        let result = step(
            state: .awakeUserTimed(endsAt: now),
            input: .timerExpired
        )
        XCTAssertEqual(result.state, .asleep)
        XCTAssertTrue(result.effects.contains(.releaseAssertion))
    }

    // MARK: AwakeTriggered row

    func testAwakeTriggered_userActivate_promotesToTimedWithShadow() {
        let result = step(
            state: .awakeTriggered(votes: ["cal": voteOn]),
            input: .userActivate(.minutes(30))
        )
        if case .awakeUserTimed = result.state {} else { XCTFail() }
        XCTAssertEqual(result.pendingVotes["cal"], voteOn,
                       "votes should preserve in shadow set per §7")
    }

    func testAwakeTriggered_userDeactivate_goesToSnoozed() {
        let result = step(
            state: .awakeTriggered(votes: ["cal": voteOn]),
            input: .userDeactivate
        )
        if case .snoozed(let until) = result.state {
            XCTAssertEqual(until.timeIntervalSinceReferenceDate, now.addingTimeInterval(300).timeIntervalSinceReferenceDate, accuracy: 0.001)
        } else { XCTFail() }
        XCTAssertTrue(result.effects.contains(.releaseAssertion))
        XCTAssertEqual(result.pendingVotes["cal"], voteOn,
                       "trigger votes preserved in shadow during snooze")
    }

    func testAwakeTriggered_userToggle_desugarsToDeactivate() {
        let result = step(
            state: .awakeTriggered(votes: ["cal": voteOn]),
            input: .userToggle
        )
        if case .snoozed = result.state {} else { XCTFail() }
    }

    func testAwakeTriggered_triggerVoteOn_mergesVotes() {
        let result = step(
            state: .awakeTriggered(votes: ["cal": voteOn]),
            input: .triggerVoteOn(id: "app", vote: voteOn)
        )
        if case .awakeTriggered(let votes) = result.state {
            XCTAssertEqual(votes.count, 2)
            XCTAssertEqual(votes["cal"], voteOn)
            XCTAssertEqual(votes["app"], voteOn)
        } else { XCTFail() }
        XCTAssertTrue(result.effects.isEmpty, "no acquire/release; assertion already held")
    }

    func testAwakeTriggered_triggerVoteOff_lastVote_grace0_goesToAsleepImmediately() {
        // S7.10: per-trigger grace. v1 default grace=0 → release assertion immediately.
        let result = step(
            state: .awakeTriggered(votes: ["cal": voteOn]),
            input: .triggerVoteOff(id: "cal", graceSeconds: 0)
        )
        XCTAssertEqual(result.state, .asleep)
        XCTAssertTrue(result.effects.contains(.releaseAssertion))
        XCTAssertTrue(result.pendingVotes.isEmpty)
    }

    func testAwakeTriggered_triggerVoteOff_lastVote_gracePositive_goesToCoolingDown() {
        // S7.10: triggers may declare a non-zero grace (e.g., a future WiFi
        // trigger with 30s grace to absorb network blips). State machine
        // honors that by entering cool-down for the requested duration.
        let result = step(
            state: .awakeTriggered(votes: ["cal": voteOn]),
            input: .triggerVoteOff(id: "cal", graceSeconds: 30)
        )
        if case .coolingDown(let until, let lastVotes) = result.state {
            XCTAssertEqual(until.timeIntervalSinceReferenceDate,
                           now.addingTimeInterval(30).timeIntervalSinceReferenceDate,
                           accuracy: 0.001,
                           "cool-down `until` should reflect the trigger's declared grace")
            XCTAssertEqual(lastVotes["cal"], voteOn,
                           "lastVotes captures pre-removal snapshot per §8.1 example")
        } else { XCTFail("expected coolingDown(30s), got \(result.state)") }
        XCTAssertFalse(result.effects.contains(.releaseAssertion),
                       "assertion stays held during cool-down")
        XCTAssertTrue(result.effects.contains(where: {
            if case .scheduleTimer(.coolDown, _) = $0 { return true } else { return false }
        }))
    }

    func testAwakeTriggered_triggerVoteOff_remainingVote_staysAwakeTriggered() {
        let result = step(
            state: .awakeTriggered(votes: ["cal": voteOn, "app": voteOn]),
            input: .triggerVoteOff(id: "cal", graceSeconds: 0)
        )
        if case .awakeTriggered(let votes) = result.state {
            XCTAssertEqual(votes.count, 1)
            XCTAssertEqual(votes["app"], voteOn)
            XCTAssertNil(votes["cal"])
        } else { XCTFail() }
    }

    // MARK: CoolingDown row

    func testCoolingDown_userActivate_goesToAwakeUserTimed() {
        let until = now.addingTimeInterval(30)
        let result = step(
            state: .coolingDown(until: until, lastVotes: ["cal": voteOn]),
            input: .userActivate(.minutes(15))
        )
        if case .awakeUserTimed = result.state {} else { XCTFail() }
        XCTAssertTrue(result.effects.contains(.cancelTimer(kind: .coolDown)))
    }

    func testCoolingDown_userDeactivate_goesToSnoozed() {
        let result = step(
            state: .coolingDown(until: now.addingTimeInterval(30), lastVotes: ["cal": voteOn]),
            input: .userDeactivate
        )
        if case .snoozed = result.state {} else { XCTFail() }
        XCTAssertTrue(result.effects.contains(.cancelTimer(kind: .coolDown)))
        XCTAssertTrue(result.effects.contains(.releaseAssertion))
    }

    func testCoolingDown_userToggle_desugarsToDeactivate() {
        let result = step(
            state: .coolingDown(until: now.addingTimeInterval(30), lastVotes: ["cal": voteOn]),
            input: .userToggle
        )
        if case .snoozed = result.state {} else { XCTFail("toggle on cooling = off (assertion held)") }
    }

    func testCoolingDown_triggerVoteOn_returnsToAwakeTriggered() {
        let result = step(
            state: .coolingDown(until: now.addingTimeInterval(30), lastVotes: ["cal": voteOn]),
            input: .triggerVoteOn(id: "cal", vote: voteOn)
        )
        if case .awakeTriggered(let votes) = result.state {
            XCTAssertEqual(votes["cal"], voteOn)
            XCTAssertEqual(votes.count, 1)
        } else { XCTFail() }
        XCTAssertTrue(result.effects.contains(.cancelTimer(kind: .coolDown)))
        XCTAssertFalse(result.effects.contains(.releaseAssertion),
                       "assertion never released during cool-down")
    }

    func testCoolingDown_triggerVoteOff_isNoop() {
        let result = step(
            state: .coolingDown(until: now.addingTimeInterval(30), lastVotes: ["cal": voteOn]),
            input: .triggerVoteOff(id: "cal", graceSeconds: 0)
        )
        if case .coolingDown = result.state {} else { XCTFail() }
        XCTAssertTrue(result.effects.isEmpty)
    }

    func testCoolingDown_coolDownExpired_goesToAsleep() {
        let result = step(
            state: .coolingDown(until: now, lastVotes: ["cal": voteOn]),
            input: .coolDownExpired
        )
        XCTAssertEqual(result.state, .asleep)
        XCTAssertTrue(result.effects.contains(.releaseAssertion))
    }

    // MARK: Snoozed row

    func testSnoozed_userActivate_goesToAwakeUserTimed() {
        let result = step(
            state: .snoozed(until: now.addingTimeInterval(60)),
            input: .userActivate(.minutes(30))
        )
        if case .awakeUserTimed = result.state {} else { XCTFail() }
        XCTAssertTrue(result.effects.contains(.cancelTimer(kind: .snooze)))
        XCTAssertTrue(result.effects.contains(.acquireAssertion))
    }

    func testSnoozed_userDeactivate_isNoop() {
        let result = step(
            state: .snoozed(until: now.addingTimeInterval(60)),
            input: .userDeactivate
        )
        if case .snoozed = result.state {} else { XCTFail() }
        XCTAssertTrue(result.effects.isEmpty)
    }

    func testSnoozed_userToggle_endsSnoozeAndGoesAwakeUserIndefinite() {
        // Snoozed has assertion released → toggle desugars to userActivate(.indefinite)
        let result = step(
            state: .snoozed(until: now.addingTimeInterval(60)),
            input: .userToggle
        )
        XCTAssertEqual(result.state, .awakeUserIndefinite)
        XCTAssertTrue(result.effects.contains(.cancelTimer(kind: .snooze)))
        XCTAssertTrue(result.effects.contains(.acquireAssertion))
    }

    func testSnoozed_triggerVoteOn_recordsShadowOnly() {
        let result = step(
            state: .snoozed(until: now.addingTimeInterval(60)),
            input: .triggerVoteOn(id: "cal", vote: voteOn)
        )
        if case .snoozed = result.state {} else { XCTFail() }
        XCTAssertEqual(result.pendingVotes["cal"], voteOn)
        XCTAssertTrue(result.effects.isEmpty, "snooze suppresses; no acquire")
    }

    func testSnoozed_triggerVoteOff_dropsShadow() {
        let result = step(
            state: .snoozed(until: now.addingTimeInterval(60)),
            pending: ["cal": voteOn],
            input: .triggerVoteOff(id: "cal", graceSeconds: 0)
        )
        XCTAssertNil(result.pendingVotes["cal"])
    }

    func testSnoozed_snoozeExpired_withShadowVotes_promotesToTriggered() {
        let result = step(
            state: .snoozed(until: now),
            pending: ["cal": voteOn],
            input: .snoozeExpired
        )
        if case .awakeTriggered(let votes) = result.state {
            XCTAssertEqual(votes["cal"], voteOn)
        } else { XCTFail() }
        XCTAssertTrue(result.effects.contains(.acquireAssertion))
    }

    func testSnoozed_snoozeExpired_noVotes_goesToAsleep() {
        let result = step(
            state: .snoozed(until: now),
            input: .snoozeExpired
        )
        XCTAssertEqual(result.state, .asleep)
        XCTAssertFalse(result.effects.contains(.acquireAssertion))
    }

    func testSnoozed_snoozeExpired_voteOffShadow_filteredOut() {
        // pendingVotes can contain wantsAwake=false; those must not promote.
        let result = step(
            state: .snoozed(until: now),
            pending: ["cal": voteOff],
            input: .snoozeExpired
        )
        XCTAssertEqual(result.state, .asleep)
    }

    // MARK: Invariant violations

    func testAsleep_timerExpired_isInvariantViolation() {
        let result = step(state: .asleep, input: .timerExpired)
        XCTAssertEqual(result.state, .asleep)
        XCTAssertTrue(result.effects.contains(where: {
            if case .logFault = $0 { return true } else { return false }
        }))
    }

    func testAwakeUserIndefinite_coolDownExpired_isInvariantViolation() {
        let result = step(state: .awakeUserIndefinite, input: .coolDownExpired)
        XCTAssertTrue(result.effects.contains(where: {
            if case .logFault = $0 { return true } else { return false }
        }))
    }

    // MARK: - S7.10: receiveTriggerVote dispatch by grace

    /// Live AwakeManager test (not pure step). Verifies the grace from the
    /// incoming TriggerVote flows into the state machine input. grace=0 vote
    /// → straight to .asleep; grace>0 vote → .coolingDown for that duration.
    @MainActor
    func testManager_voteOff_grace0_goesAsleepImmediately() async {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        let manager = AwakeManager(assertion: assertion, settings: settings)

        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "on", graceSecondsAfterOff: 0),
            from: "t"
        )
        XCTAssertTrue(manager.isAwake)

        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: false, reason: "off", graceSecondsAfterOff: 0),
            from: "t"
        )
        XCTAssertEqual(manager.state, .asleep)
        XCTAssertFalse(manager.isAwake)
        XCTAssertFalse(assertion.isActive)
    }

    @MainActor
    func testManager_voteOff_gracePositive_goesCoolingDown() async {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        let manager = AwakeManager(assertion: assertion, settings: settings)

        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "on", graceSecondsAfterOff: 30),
            from: "t"
        )
        XCTAssertTrue(manager.isAwake)

        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: false, reason: "off", graceSecondsAfterOff: 30),
            from: "t"
        )
        if case .coolingDown = manager.state {
            // expected
        } else {
            XCTFail("expected coolingDown after grace>0 vote-off, got \(manager.state)")
        }
        XCTAssertTrue(manager.isAwake, "still awake during cool-down (assertion held)")
        XCTAssertTrue(assertion.isActive)
    }
}

// MARK: - Worked examples from 03 §8 — integration on AwakeManager.

@MainActor
final class AwakeManagerWorkedExampleTests: XCTestCase {

    private func makeManager() -> (AwakeManager, MockPowerAssertion, InMemorySettingsStore) {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        let manager = AwakeManager(assertion: assertion, settings: settings)
        return (manager, assertion, settings)
    }

    /// §8.1 happy path Zoom meeting (initial state + voteOn → awakeTriggered).
    func test81_happyPath_voteOnGoesAwakeTriggered() {
        let (manager, assertion, _) = makeManager()
        XCTAssertFalse(manager.isAwake)
        XCTAssertFalse(assertion.isActive)

        manager.receiveTriggerVote(TriggerVote(wantsAwake: true, reason: "Zoom"), from: "cal")
        XCTAssertTrue(manager.isAwake)
        XCTAssertTrue(assertion.isActive)
        if case .awakeTriggered(let votes) = manager.state {
            XCTAssertEqual(votes["cal"]?.reason, "Zoom")
        } else { XCTFail() }
    }

    /// §8.1 cont — voteOff with non-zero grace → coolingDown (not asleep yet).
    /// S7.10: cool-down only triggers when the trigger declares grace>0;
    /// v1 default is 0 (immediate sleep). This test exercises the legacy path
    /// for triggers that may opt into grace in the future.
    func test81_lastVoteOffWithGraceEntersCooling() {
        let (manager, assertion, _) = makeManager()
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "Zoom", graceSecondsAfterOff: 30),
            from: "cal"
        )
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: false, reason: "Zoom ended", graceSecondsAfterOff: 30),
            from: "cal"
        )
        if case .coolingDown = manager.state {} else { XCTFail("expected coolingDown, got \(manager.state)") }
        XCTAssertTrue(assertion.isActive, "assertion must remain held during cool-down")
    }

    /// §8.2 back-to-back: vote on B during cooling cancels cool-down, no flapping.
    /// S7.10: only relevant when triggers opt into grace>0; v1 default skips this.
    func test82_backToBackMeetingsAbsorbedByCooling() {
        let (manager, assertion, _) = makeManager()
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "A", graceSecondsAfterOff: 30),
            from: "cal"
        )
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: false, reason: "A end", graceSecondsAfterOff: 30),
            from: "cal"
        )
        XCTAssertTrue(assertion.isActive)
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "B", graceSecondsAfterOff: 30),
            from: "cal"
        )
        if case .awakeTriggered(let votes) = manager.state {
            XCTAssertEqual(votes["cal"]?.reason, "B")
        } else { XCTFail() }
        // Critical: assertion was never released during the gap.
        XCTAssertEqual(assertion.deactivationCount, 0, "no release during back-to-back")
    }

    /// §8.1 v1-default — grace=0 (current production default for all triggers).
    /// Vote-off transitions directly to .asleep; assertion released immediately.
    func test81_v1Default_lastVoteOff_grace0_releasesImmediately() {
        let (manager, assertion, _) = makeManager()
        manager.receiveTriggerVote(TriggerVote(wantsAwake: true, reason: "Zoom"), from: "cal")
        manager.receiveTriggerVote(TriggerVote(wantsAwake: false, reason: "Zoom ended"), from: "cal")
        XCTAssertEqual(manager.state, .asleep)
        XCTAssertFalse(assertion.isActive, "v1 default releases the assertion immediately")
    }

    /// **S22 / P-issue-6c**: user-explicit deactivate (popover Turn off /
    /// ⌘⇧L toggle / AppIntent) routes through `.constraintDeactivate`,
    /// which lands directly in `.asleep` and clears `pendingVotes`. Snooze
    /// is intentionally bypassed because P-issue-6's `disableAll()`
    /// already disables every enabled trigger on this transition — the
    /// snooze was originally a re-fire suppressor, but with no triggers
    /// enabled there's nothing to re-fire. Owner-requested redesign:
    /// pause-all = temporary suspend (auto-recover when conditions hold);
    /// Turn off = explicit termination (re-enable in Settings to resume).
    /// Replaces the previous test83 which encoded the v1 snooze contract.
    func test83_userDeactivateDuringCall_goesAsleepImmediately() {
        let (manager, assertion, _) = makeManager()
        manager.receiveTriggerVote(TriggerVote(wantsAwake: true, reason: "A"), from: "cal")
        manager.deactivate()
        XCTAssertEqual(manager.state, .asleep, "user-explicit deactivate skips snooze (P-issue-6c)")
        XCTAssertFalse(assertion.isActive, "deactivate releases assertion")

        // Subsequent ON vote arrives (e.g. in a real run, this would mean
        // the user re-enabled the trigger and the trigger re-emitted) —
        // since state is .asleep, the vote freshly transitions to
        // .awakeTriggered. No snooze suppression.
        manager.receiveTriggerVote(TriggerVote(wantsAwake: true, reason: "B"), from: "app")
        if case .awakeTriggered = manager.state {} else {
            XCTFail("post-deactivate vote ON must wake fresh — no snooze lockout (P-issue-6c)")
        }
    }

    /// §8.4 user activates manually, trigger fires later, timer expires → triggered.
    func test84_userActivateThenTriggerInShadow_promotesOnExpiry() {
        let (manager, _, _) = makeManager()
        manager.activate(for: .minutes(30))
        if case .awakeUserTimed = manager.state {} else { XCTFail() }

        manager.receiveTriggerVote(TriggerVote(wantsAwake: true, reason: "A"), from: "cal")
        if case .awakeUserTimed = manager.state {} else {
            XCTFail("vote during user-timed should stay user-timed")
        }
    }

    /// **S22 / P-issue-6c**: user force-off during cool-down lands in
    /// `.asleep` (not `.snoozed`), symmetric with all other user-explicit
    /// deactivate paths under the post-P6 redesign. Replaces the previous
    /// test85 which encoded the v1 snooze contract.
    func test85_userForceOffDuringCooling_goesAsleep() {
        let (manager, _, _) = makeManager()
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: true, reason: "A", graceSecondsAfterOff: 30),
            from: "cal"
        )
        manager.receiveTriggerVote(
            TriggerVote(wantsAwake: false, reason: "A end", graceSecondsAfterOff: 30),
            from: "cal"
        )
        if case .coolingDown = manager.state {} else { XCTFail("expected coolingDown, got \(manager.state)") }

        manager.deactivate()
        XCTAssertEqual(manager.state, .asleep, "user-explicit deactivate during cool-down lands directly in .asleep (P-issue-6c)")
    }

    /// §8.6 cold launch always = asleep.
    func test86_coldLaunchIsAsleep() {
        let (manager, _, _) = makeManager()
        XCTAssertEqual(manager.state, .asleep)
        XCTAssertFalse(manager.isAwake)
    }

    // MARK: Public-API smoke tests

    func testToggleFromAsleepGoesAwakeUserIndefinite() {
        let (manager, assertion, _) = makeManager()
        manager.toggle()
        XCTAssertEqual(manager.state, .awakeUserIndefinite)
        XCTAssertTrue(assertion.isActive)
    }

    func testToggleFromAwakeUserIndefiniteGoesAsleep() {
        let (manager, assertion, _) = makeManager()
        manager.toggle()
        manager.toggle()
        XCTAssertEqual(manager.state, .asleep)
        XCTAssertFalse(assertion.isActive)
    }

    func testActivateForMinutesSetsEndsAt() {
        let (manager, _, _) = makeManager()
        let before = Date()
        manager.activate(for: .minutes(5))
        XCTAssertTrue(manager.isAwake)
        XCTAssertEqual(manager.activeDuration, .minutes(5))
        XCTAssertNotNil(manager.endsAt)
        if let endsAt = manager.endsAt {
            XCTAssertEqual(
                endsAt.timeIntervalSinceReferenceDate,
                before.addingTimeInterval(300).timeIntervalSinceReferenceDate,
                accuracy: 1.0
            )
        }
    }

    func testReactivatingReplacesPrevious() {
        let (manager, _, _) = makeManager()
        manager.activate(for: .minutes(15))
        XCTAssertEqual(manager.activeDuration, .minutes(15))
        manager.activate(for: .hours(2))
        XCTAssertEqual(manager.activeDuration, .hours(2))
        XCTAssertTrue(manager.isAwake)
    }

    func testAllowDisplaySleepRefreshesAssertion() {
        let assertion = MockPowerAssertion()
        let manager = AwakeManager(assertion: assertion, settings: InMemorySettingsStore())
        manager.activate(for: .indefinite)
        XCTAssertEqual(assertion.activations.last?.mode, .displayAndSystem)

        manager.allowDisplaySleep = true
        XCTAssertEqual(assertion.activations.last?.mode, .systemOnly)
    }

    func testAggregateAnyOR_singleVoteWins() {
        let (manager, _, _) = makeManager()
        manager.receiveTriggerVote(TriggerVote(wantsAwake: true, reason: "Cal"), from: "cal")
        manager.receiveTriggerVote(TriggerVote(wantsAwake: true, reason: "App"), from: "app")
        // any-OR aggregation per §5.1: if any vote on, awake.
        if case .awakeTriggered(let votes) = manager.state {
            XCTAssertEqual(votes.count, 2)
        } else { XCTFail() }

        // Drop one — still awake.
        manager.receiveTriggerVote(TriggerVote(wantsAwake: false, reason: ""), from: "cal")
        if case .awakeTriggered(let votes) = manager.state {
            XCTAssertEqual(votes.count, 1)
            XCTAssertNil(votes["cal"])
        } else { XCTFail() }
    }
}
