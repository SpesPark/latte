import XCTest
@testable import Latte

@MainActor
final class ExternalDisplayTriggerTests: XCTestCase {

    private func makeFixture(
        count: Int = 0,
        name: String? = nil,
        enabled: Bool = true
    ) -> (ExternalDisplayTrigger, MockDisplaySource, InMemorySettingsStore) {
        let settings = InMemorySettingsStore()
        settings.setBool(enabled, for: .externalDisplayEnabled)
        let source = MockDisplaySource(
            externalDisplayCount: count,
            firstExternalDisplayName: name
        )
        let trigger = ExternalDisplayTrigger(settings: settings, source: source)
        return (trigger, source, settings)
    }

    func testInitialZeroExternalCountEmitsNoVote() async throws {
        let (trigger, _, _) = makeFixture(count: 0)
        trigger.evaluate()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        let vote = await task.value
        XCTAssertNil(vote, "no displays + no prior vote → no emission (skip first OFF)")
    }

    func testAttachExternalEmitsAwakeVoteWithFriendlyReason() async throws {
        let (trigger, _, _) = makeFixture(count: 1, name: "DELL U2723QE")
        trigger.evaluate()

        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertEqual(vote?.reason, "Display: DELL U2723QE")
    }

    func testAttachThenDetachEmitsOffVote() async throws {
        let (trigger, source, _) = makeFixture(count: 1, name: "Studio Display")
        trigger.evaluate()
        var it = trigger.voteStream.makeAsyncIterator()
        let on = await it.next()
        XCTAssertEqual(on?.wantsAwake, true)

        source.externalDisplayCount = 0
        source.firstExternalDisplayName = nil
        trigger.evaluate()
        let off = await it.next()
        XCTAssertEqual(off?.wantsAwake, false)
        XCTAssertEqual(off?.reason, "Display: disconnected")
    }

    func testMultipleExternalsEmitOneAwakeVoteWithFirstName() async throws {
        let (trigger, _, _) = makeFixture(count: 3, name: "LG UltraFine")
        trigger.evaluate()

        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertEqual(vote?.reason, "Display: LG UltraFine")

        // A second evaluate with the same count should NOT re-emit.
        trigger.evaluate()
        let probe = Task { @MainActor () -> TriggerVote? in await it.next() }
        try await Task.sleep(nanoseconds: 50_000_000)
        probe.cancel()
        let next = await probe.value
        XCTAssertNil(next, "no state change → no second vote")
    }

    func testNameUnavailableFallsBackToExternalDisplay() async throws {
        let (trigger, _, _) = makeFixture(count: 1, name: nil)
        trigger.evaluate()

        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertEqual(vote?.reason, "Display: External Display")
    }

    func testStartEvaluatesImmediatelyAndStopHaltsEmissions() async throws {
        let (trigger, source, _) = makeFixture(count: 1, name: "Apple Studio Display")
        await trigger.start()

        var it = trigger.voteStream.makeAsyncIterator()
        let firstVote = await it.next()
        XCTAssertEqual(firstVote?.wantsAwake, true)

        // start() while running is a no-op.
        await trigger.start()

        trigger.stop()

        // After stop, source change events must NOT drive evaluate (the
        // observeTask gates on `isRunning`). Verify with a brief probe.
        source.emitChange()
        let probe = Task { @MainActor () -> TriggerVote? in
            var probeIt = trigger.voteStream.makeAsyncIterator()
            return await probeIt.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        probe.cancel()
        let nothing = await probe.value
        XCTAssertNil(nothing, "stop halts emissions; observeTask is gated by isRunning")
    }

    func testRestartAfterStopReEmitsForCurrentSourceState() async throws {
        let (trigger, _, _) = makeFixture(count: 1, name: "Apple Studio Display")
        await trigger.start()
        var it = trigger.voteStream.makeAsyncIterator()
        let v1 = await it.next()
        XCTAssertEqual(v1?.wantsAwake, true)

        trigger.stop()
        await trigger.start()
        let v2 = await it.next()
        XCTAssertEqual(v2?.wantsAwake, true,
                       "restart with display still attached re-emits ON vote")
        trigger.stop()
    }

    func testDisabledNoOp() async throws {
        let (trigger, _, _) = makeFixture(count: 1, name: "Mon", enabled: false)
        trigger.evaluate()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        let vote = await task.value
        XCTAssertNil(vote, "disabled trigger must not vote even with display attached")
    }

    func testIsEnabledSetterPersists() {
        let settings = InMemorySettingsStore()
        let trigger = ExternalDisplayTrigger(
            settings: settings,
            source: MockDisplaySource()
        )
        XCTAssertFalse(trigger.isEnabled, "default off")
        trigger.isEnabled = true
        XCTAssertTrue(trigger.isEnabled)
        XCTAssertTrue(settings.bool(.externalDisplayEnabled, default: false))
    }
}
