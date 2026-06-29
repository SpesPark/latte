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
        let probe = Task { @MainActor () -> TriggerVote? in
            var probeIt = trigger.voteStream.makeAsyncIterator()
            return await probeIt.next()
        }
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
        // observeTask gates on `isRunning`). The probe expects no vote, so a
        // fresh iterator inside the task is equivalent (nothing is buffered to
        // compete over) and keeps the @Sendable Task from capturing the outer
        // non-Sendable iterator.
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

    // MARK: - V2-06 deferred H — per-display whitelist

    func testEmptyWhitelistMatchesAnyAttachedDisplay() async throws {
        // Default behaviour preserved — no whitelist means any external
        // attaches awake the cup, exactly like v1.2.
        let (trigger, _, _) = makeFixture(count: 1, name: "DELL")
        trigger.evaluate()
        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.wantsAwake, true)
    }

    func testWhitelistMatchesByUUIDAndIgnoresOthers() async throws {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .externalDisplayEnabled)
        let dell = DisplayInfo(uuid: "DELL-UUID", name: "DELL U2723QE")
        let asus = DisplayInfo(uuid: "ASUS-UUID", name: "ASUS PA32")
        let source = MockDisplaySource(
            externalDisplayCount: 2,
            firstExternalDisplayName: "DELL U2723QE",
            attachedExternalDisplays: [dell, asus]
        )
        let trigger = ExternalDisplayTrigger(settings: settings, source: source)

        // Whitelist only the ASUS — the DELL is attached but ignored.
        trigger.setWhitelistedUUIDs(["ASUS-UUID"])
        await trigger.start()

        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertTrue(vote?.reason.contains("ASUS PA32") == true,
                      "matched display name must drive the reason, got: \(vote?.reason ?? "nil")")
    }

    func testWhitelistWithNoMatchingAttachedDisplaysVotesOff() async throws {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .externalDisplayEnabled)
        let dell = DisplayInfo(uuid: "DELL-UUID", name: "DELL")
        let source = MockDisplaySource(
            externalDisplayCount: 1,
            firstExternalDisplayName: "DELL",
            attachedExternalDisplays: [dell]
        )
        let trigger = ExternalDisplayTrigger(settings: settings, source: source)
        // Whitelist a UUID that isn't attached.
        trigger.setWhitelistedUUIDs(["UNKNOWN-UUID"])

        // Walk through ON state first so the OFF transition can fire.
        trigger.setWhitelistedUUIDs([])
        await trigger.start()
        var it = trigger.voteStream.makeAsyncIterator()
        _ = await it.next()    // ON

        trigger.setWhitelistedUUIDs(["UNKNOWN-UUID"])
        let off = await it.next()
        XCTAssertEqual(off?.wantsAwake, false)
    }

    func testSetWhitelistPersistsToSettings() {
        let (trigger, _, settings) = makeFixture(count: 0)
        trigger.setWhitelistedUUIDs(["A", "B", "C"])
        XCTAssertEqual(settings.decodeStringArray(.externalDisplayWhitelist), ["A", "B", "C"])
        XCTAssertEqual(trigger.whitelistedUUIDs, ["A", "B", "C"])
    }

    /// 9th simplify-pass HIGH-1 regression — when `attachedExternalDisplays`
    /// is populated with a name and `firstExternalDisplayName` is nil, the
    /// attached-list name wins over the "External Display" fallback.
    /// Documents the priority order so a future change can't silently flip it.
    func testAttachedListNameWinsOverFallbackWhenLegacyNameNil() async throws {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .externalDisplayEnabled)
        let source = MockDisplaySource(
            externalDisplayCount: 1,
            firstExternalDisplayName: nil,
            attachedExternalDisplays: [DisplayInfo(uuid: "X", name: "Studio Display")]
        )
        let trigger = ExternalDisplayTrigger(settings: settings, source: source)
        trigger.evaluate()

        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.reason, "Display: Studio Display",
                       "attached.first.name must drive the reason when firstExternalDisplayName is nil")
    }

    func testEmptyWhitelistEncodeRemovesKeyForFutureMigrations() {
        // 9th simplify-pass MED — encodeStringArray([], for:) must clear
        // the key, not leave a "[]" blob behind. `decodeStringArray`
        // already returns [] for absent keys, so the round-trip is preserved.
        let (trigger, _, settings) = makeFixture(count: 0)
        trigger.setWhitelistedUUIDs(["A"])
        XCTAssertNotNil(settings.data(.externalDisplayWhitelist))
        trigger.setWhitelistedUUIDs([])
        XCTAssertNil(settings.data(.externalDisplayWhitelist),
                     "empty whitelist must remove the key (absent == default)")
        XCTAssertEqual(trigger.whitelistedUUIDs, [])
    }

    // MARK: - V2-06 deferred G — clamshell-aware reason

    func testClamshellModeReasonAppendsTag() async throws {
        let (trigger, source, _) = makeFixture(count: 1, name: "Studio Display")
        source.isInClamshellMode = true
        trigger.evaluate()

        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertEqual(vote?.reason, "Display: Studio Display (clamshell)")
    }

    func testNonClamshellModeReasonOmitsTag() async throws {
        let (trigger, source, _) = makeFixture(count: 1, name: "Studio Display")
        source.isInClamshellMode = false
        trigger.evaluate()

        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.reason, "Display: Studio Display",
                       "lid-open path must keep the existing reason format unchanged")
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

    // MARK: - trap #8: started trigger / debounce source must not leak via a self-retaining observeTask

    /// See `ScheduleTriggerTests.testStartedTriggerDeallocatesWithoutExplicitStop`.
    /// `ExternalDisplayTrigger.start()` installs a long-lived `observeTask`
    /// iterating `source.changeStream`; before the trap #8 fix it bound a strong
    /// self ahead of the `for await`, so the trigger never deallocated and its
    /// `deinit` (which cancels the task) never ran.
    func testStartedTriggerDeallocatesWithoutExplicitStop() async {
        weak var weakTrigger: ExternalDisplayTrigger?
        do {
            let settings = InMemorySettingsStore()
            settings.setBool(true, for: .externalDisplayEnabled)
            let trigger = ExternalDisplayTrigger(settings: settings, source: MockDisplaySource())
            weakTrigger = trigger
            await trigger.start()
            // Let the observe task bind a strong self before dropping the ref.
            try? await Task.sleep(nanoseconds: 50_000_000)
            XCTAssertNotNil(weakTrigger, "trigger alive while referenced")
        }
        for _ in 0..<200 where weakTrigger != nil {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertNil(weakTrigger,
                     "started ExternalDisplayTrigger leaked via a self-retaining observeTask (trap #8)")
    }

    /// `DebouncingDisplaySource` installs its coalescing `observeTask` in `init`
    /// (no `start()` needed). Same trap #8 self-retain bug: the task bound a
    /// strong self ahead of `for await upstream.changeStream`, so the source
    /// never deallocated and its `deinit` never finished the stream.
    func testDebouncingDisplaySourceDeallocates() async {
        weak var weakSource: DebouncingDisplaySource?
        do {
            let source = DebouncingDisplaySource(wrapping: MockDisplaySource())
            weakSource = source
            // Let the init-installed observe task bind a strong self first.
            try? await Task.sleep(nanoseconds: 50_000_000)
            XCTAssertNotNil(weakSource, "source alive while referenced")
        }
        for _ in 0..<200 where weakSource != nil {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertNil(weakSource,
                     "DebouncingDisplaySource leaked via a self-retaining observeTask (trap #8)")
    }
}
