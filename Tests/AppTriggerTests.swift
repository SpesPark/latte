import XCTest
@testable import Latte

@MainActor
final class AppTriggerTests: XCTestCase {

    private func makeFixture(
        running: [String] = [],
        watched: [String] = ["us.zoom.xos", "com.microsoft.teams2"]
    ) -> (AppTrigger, MockWorkspaceSource, InMemorySettingsStore) {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .appTriggerEnabled)
        settings.appTriggerBundleIDs = watched
        let source = MockWorkspaceSource(runningBundleIDs: running)
        let trigger = AppTrigger(settings: settings, source: source)
        return (trigger, source, settings)
    }

    func testInitialSnapshotEmitsOnVoteWhenWatchedAppRunning() async throws {
        let (trigger, _, _) = makeFixture(running: ["us.zoom.xos"])
        await trigger.start()

        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        // Friendly name resolved via WorkspaceSource.displayInfo curated table
        // (us.zoom.xos → "Zoom"); raw bundle id is the fallback only when
        // displayInfo returns nil.
        XCTAssertTrue(vote?.reason.contains("Zoom") ?? false)
    }

    func testInitialSnapshotNoEmitWhenNoWatchedAppRunning() async throws {
        let (trigger, _, _) = makeFixture(running: ["com.apple.Safari"])
        await trigger.start()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v) }
    }

    func testLaunchOfWatchedAppEmitsOn() async throws {
        let (trigger, source, _) = makeFixture(running: [])
        await trigger.start()
        source.simulateLaunch("us.zoom.xos")

        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
    }

    func testEmitOnReasonUsesFriendlyNameFromCuratedDisplayInfo() async throws {
        let (trigger, _, _) = makeFixture(running: ["us.zoom.xos"])
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.reason, "App: Zoom",
                       "curated displayInfo should map us.zoom.xos → Zoom in the vote reason")
    }

    func testEmitOnReasonFallsBackToBundleIDForUnknownApps() async throws {
        let settings = InMemorySettingsStore()
        settings.appTriggerBundleIDs = ["com.example.unknown"]
        let source = MockWorkspaceSource(runningBundleIDs: ["com.example.unknown"])
        let trigger = AppTrigger(settings: settings, source: source)
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.reason, "App: com.example.unknown",
                       "unmapped bundle id should fall back to raw id in vote reason")
    }

    func testEmitOnReasonHonoursExplicitDisplayInfoOverride() async throws {
        let settings = InMemorySettingsStore()
        settings.appTriggerBundleIDs = ["com.example.foo"]
        let source = MockWorkspaceSource(runningBundleIDs: ["com.example.foo"])
        source.displayInfoLookup["com.example.foo"] = AppDisplayInfo(
            bundleID: "com.example.foo",
            displayName: "Foo App"
        )
        let trigger = AppTrigger(settings: settings, source: source)
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.reason, "App: Foo App",
                       "explicit displayInfo override should win over the raw bundle id")
    }

    func testLaunchOfUnwatchedAppDoesNotEmit() async throws {
        let (trigger, source, _) = makeFixture(running: [])
        await trigger.start()
        source.simulateLaunch("com.apple.Safari")

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v) }
    }

    /// **S22 / P-issue-5b**: after pause-all is lifted, AppTrigger must
    /// re-emit its current ON vote so the cup auto-recovers when the
    /// constraint clears (e.g. Notion is still running). The previous
    /// `reevaluateWatched()` short-circuits when the watched-set hasn't
    /// changed (its design is for Settings UI list edits) — so a new
    /// `reemitCurrentVote()` method is needed for the pause-lift hook.
    /// Owner-reported during the resumed Step 6 manual smoke that pause
    /// OFF didn't auto-recover even after the P-issue-5 hook landed —
    /// because `reevaluateWatched()` returned early.
    func testReemitCurrentVoteEmitsOnWhenWatchedAppStillRunning() async throws {
        let (trigger, _, _) = makeFixture(running: ["us.zoom.xos"])
        await trigger.start()

        var iterator = trigger.voteStream.makeAsyncIterator()
        let initial = await iterator.next()
        XCTAssertEqual(initial?.wantsAwake, true)

        // Simulate the AwakeManager-side pause-all cycle: the trigger's own
        // watched-set + matchingRunning are unchanged, but AwakeManager has
        // cleared its pendingVotes via .constraintDeactivate. Calling
        // reemitCurrentVote() should yield the current ON vote regardless
        // of any internal dedup that reevaluateWatched() applies.
        trigger.reemitCurrentVote()
        let resync = await iterator.next()
        XCTAssertEqual(resync?.wantsAwake, true, "reemitCurrentVote must re-emit ON when matching app is still running")
        XCTAssertTrue(resync?.reason.contains("Zoom") ?? false)
    }

    /// `reemitCurrentVote()` must be a no-op when no watched app is running —
    /// no spurious OFF votes. The AwakeManager is already asleep; emitting
    /// OFF would be redundant and could hit the "OFF in asleep" no-change
    /// branch noisily.
    func testReemitCurrentVoteNoEmitWhenNoMatchingApp() async throws {
        let (trigger, _, _) = makeFixture(running: ["com.apple.Safari"])
        await trigger.start()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v) }

        trigger.reemitCurrentVote()
        let task2 = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task2.cancel()
        do { let _v = await task2.value; XCTAssertNil(_v, "no emission when no matching watched app is running") }
    }

    func testSecondWatchedLaunchDoesNotReEmit() async throws {
        let (trigger, source, _) = makeFixture(running: ["us.zoom.xos"])
        await trigger.start()
        // first vote from initial snapshot
        var iterator = trigger.voteStream.makeAsyncIterator()
        _ = await iterator.next()

        source.simulateLaunch("com.microsoft.teams2")
        let task = Task { @MainActor () -> TriggerVote? in
            await iterator.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        // No additional ON vote (we already had one, set was non-empty before this launch).
        do { let _v = await task.value; XCTAssertNil(_v) }
    }

    func testTerminateLastWatchedAppEmitsOff() async throws {
        let (trigger, source, _) = makeFixture(running: ["us.zoom.xos"])
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let onVote = await iterator.next()
        XCTAssertEqual(onVote?.wantsAwake, true)

        source.simulateTerminate("us.zoom.xos")
        let offVote = await iterator.next()
        XCTAssertEqual(offVote?.wantsAwake, false)
    }

    func testTerminateOneOfTwoWatchedAppsKeepsVoteOn() async throws {
        let (trigger, source, _) = makeFixture(running: ["us.zoom.xos", "com.microsoft.teams2"])
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        _ = await iterator.next() // initial ON

        source.simulateTerminate("us.zoom.xos")
        let task = Task { @MainActor () -> TriggerVote? in
            await iterator.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        // No off vote; teams2 still running.
        do { let _v = await task.value; XCTAssertNil(_v) }
    }

    func testStopCancelsObservation() async throws {
        let (trigger, source, _) = makeFixture(running: ["us.zoom.xos"])
        await trigger.start()
        XCTAssertEqual(source.observationCount, 1)
        trigger.stop()
        // After stop, simulateLaunch is a no-op because the observation's
        // onLaunch handler was nil'd during cancel. (S7.9: the AsyncStream's
        // continuation is intentionally NOT finished on stop, so a future
        // start() can deliver votes again.)
        source.simulateLaunch("com.microsoft.teams2")
    }

    func testDisabledTriggerNoOpOnStart() async throws {
        let settings = InMemorySettingsStore()
        // .appTriggerEnabled left false (not used by start; coordinator's job).
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])
        let trigger = AppTrigger(settings: settings, source: source)
        // First-launch seeding (S7.8) populates watched with installed curated
        // defaults — Mock treats `runningBundleIDs` as the installed set, so
        // Zoom gets seeded and start() votes ON for the running snapshot.
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
    }

    func testAppTriggerRequiresNoPermission() async {
        let (trigger, _, _) = makeFixture()
        let granted = await trigger.requestPermissionIfNeeded()
        XCTAssertTrue(granted)
        XCTAssertEqual(trigger.permissionStatus, .notRequired)
    }

    func testRunningBundleIDsPassThrough() {
        let (trigger, source, _) = makeFixture(running: [
            "us.zoom.xos",
            "com.apple.Safari",
            "com.microsoft.teams2"
        ])
        XCTAssertEqual(Set(trigger.runningBundleIDs), Set(source.runningBundleIDs))

        // Lifecycle changes propagate.
        source.runningBundleIDs.append("com.tinyspeck.slackmacgap")
        XCTAssertTrue(trigger.runningBundleIDs.contains("com.tinyspeck.slackmacgap"))
    }

    // MARK: - DisplayInfo (S7.7)

    func testCuratedDefaultsDisplayNameMapping() {
        XCTAssertEqual(AppTriggerDefaults.displayName(for: "us.zoom.xos"), "Zoom")
        XCTAssertEqual(AppTriggerDefaults.displayName(for: "com.microsoft.teams2"), "Microsoft Teams")
        XCTAssertEqual(AppTriggerDefaults.displayName(for: "com.cisco.webex.meetings"), "Webex")
        XCTAssertEqual(AppTriggerDefaults.displayName(for: "com.hnc.Discord"), "Discord")
        XCTAssertEqual(AppTriggerDefaults.displayName(for: "com.tinyspeck.slackmacgap"), "Slack")
        XCTAssertEqual(AppTriggerDefaults.displayName(for: "com.google.Chrome.helper.meet"), "Google Meet")
    }

    func testCuratedDefaultsDisplayNameUnknownReturnsNil() {
        XCTAssertNil(AppTriggerDefaults.displayName(for: "com.unknown.app"))
        XCTAssertNil(AppTriggerDefaults.displayName(for: ""))
    }

    func testMockDisplayInfoFallsBackToCuratedTable() {
        let source = MockWorkspaceSource()
        let info = source.displayInfo(for: "us.zoom.xos")
        XCTAssertEqual(info?.displayName, "Zoom")
        XCTAssertEqual(info?.bundleID, "us.zoom.xos")
        XCTAssertNil(info?.iconImageData)
    }

    func testMockDisplayInfoExplicitOverrideTakesPrecedence() {
        let source = MockWorkspaceSource()
        source.displayInfoLookup["us.zoom.xos"] = AppDisplayInfo(
            bundleID: "us.zoom.xos",
            displayName: "Zoom Workplace"
        )
        XCTAssertEqual(source.displayInfo(for: "us.zoom.xos")?.displayName, "Zoom Workplace")
    }

    func testMockDisplayInfoNilForUnmappedID() {
        let source = MockWorkspaceSource()
        XCTAssertNil(source.displayInfo(for: "com.unknown.app"))
    }

    func testAppTriggerDisplayInfoPassThroughToSource() {
        let (trigger, source, _) = makeFixture()
        source.displayInfoLookup["com.example.foo"] = AppDisplayInfo(
            bundleID: "com.example.foo",
            displayName: "Foo"
        )
        XCTAssertEqual(trigger.displayInfo(for: "com.example.foo")?.displayName, "Foo")
        XCTAssertEqual(trigger.displayInfo(for: "us.zoom.xos")?.displayName, "Zoom") // curated fallback
        XCTAssertNil(trigger.displayInfo(for: "com.unknown.app"))
    }

    // MARK: - SymbolHint (S7.8)

    func testSymbolHintForCuratedIDs() {
        XCTAssertEqual(AppTriggerDefaults.symbolHint(for: "us.zoom.xos"), "video.fill")
        XCTAssertEqual(AppTriggerDefaults.symbolHint(for: "com.microsoft.teams2"), "video.fill")
        XCTAssertEqual(AppTriggerDefaults.symbolHint(for: "com.cisco.webex.meetings"), "video.fill")
        XCTAssertEqual(AppTriggerDefaults.symbolHint(for: "com.google.Chrome.helper.meet"), "video.fill")
        XCTAssertEqual(AppTriggerDefaults.symbolHint(for: "com.hnc.Discord"), "bubble.left.and.bubble.right.fill")
        XCTAssertEqual(AppTriggerDefaults.symbolHint(for: "com.tinyspeck.slackmacgap"), "bubble.left.and.bubble.right.fill")
    }

    func testSymbolHintForUnknownReturnsNil() {
        XCTAssertNil(AppTriggerDefaults.symbolHint(for: "com.unknown.app"))
        XCTAssertNil(AppTriggerDefaults.symbolHint(for: ""))
    }

    // MARK: - isInstalled (S7.8)

    func testIsInstalledMockDefaultsToRunningBundleIDs() {
        let source = MockWorkspaceSource(runningBundleIDs: [
            "us.zoom.xos",
            "com.apple.Safari"
        ])
        XCTAssertTrue(source.isInstalled("us.zoom.xos"))
        XCTAssertTrue(source.isInstalled("com.apple.Safari"))
        XCTAssertFalse(source.isInstalled("com.microsoft.teams2"))
    }

    func testIsInstalledIncludesDisplayInfoLookupKeys() {
        let source = MockWorkspaceSource(runningBundleIDs: [])
        source.displayInfoLookup["com.installed.notrunning"] = AppDisplayInfo(
            bundleID: "com.installed.notrunning",
            displayName: "Installed (Not Running)"
        )
        XCTAssertTrue(source.isInstalled("com.installed.notrunning"))
    }

    func testIsInstalledOverrideTakesPrecedence() {
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])
        source.installedOverride = ["com.microsoft.teams2"]
        XCTAssertFalse(source.isInstalled("us.zoom.xos")) // running but override says not installed
        XCTAssertTrue(source.isInstalled("com.microsoft.teams2"))
    }

    // MARK: - installedDefaults helper (S7.8)

    func testInstalledDefaultsFiltersToInstalledOnly() {
        let source = MockWorkspaceSource(runningBundleIDs: [
            "us.zoom.xos",
            "com.tinyspeck.slackmacgap",
            "com.unrelated.app"
        ])
        let installed = AppTriggerDefaults.installedDefaults(in: source)
        XCTAssertEqual(Set(installed), Set(["us.zoom.xos", "com.tinyspeck.slackmacgap"]))
    }

    func testInstalledDefaultsEmptyWhenNoneInstalled() {
        let source = MockWorkspaceSource(runningBundleIDs: ["com.apple.Safari"])
        let installed = AppTriggerDefaults.installedDefaults(in: source)
        XCTAssertTrue(installed.isEmpty)
    }

    // MARK: - First-launch seeding (S7.8)

    func testFirstLaunchSeedsInstalledOnly() async {
        let settings = InMemorySettingsStore()
        let source = MockWorkspaceSource(runningBundleIDs: [
            "us.zoom.xos",        // curated + installed
            "com.unrelated.app"   // not curated
        ])
        // Pre-condition: never seeded, no watched.
        XCTAssertFalse(settings.bool(.hasSeededAppDefaults, default: false))
        XCTAssertTrue(settings.decodeStringArray(.appTriggerBundleIDs).isEmpty)

        _ = AppTrigger(settings: settings, source: source)

        XCTAssertTrue(settings.bool(.hasSeededAppDefaults, default: false))
        XCTAssertEqual(settings.appTriggerBundleIDs, ["us.zoom.xos"])
    }

    func testFirstLaunchWithNoCuratedInstalledLeavesEmptyButSetsFlag() async {
        let settings = InMemorySettingsStore()
        let source = MockWorkspaceSource(runningBundleIDs: ["com.apple.Safari"])

        _ = AppTrigger(settings: settings, source: source)

        XCTAssertTrue(settings.bool(.hasSeededAppDefaults, default: false))
        XCTAssertTrue(settings.appTriggerBundleIDs.isEmpty)
    }

    func testSecondLaunchDoesNotReSeedAfterFlagSet() async {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .hasSeededAppDefaults)
        // Stays empty because user explicitly cleared.
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])

        _ = AppTrigger(settings: settings, source: source)

        // Flag still set; watched stayed empty.
        XCTAssertTrue(settings.appTriggerBundleIDs.isEmpty)
    }

    func testInitWithExistingNonEmptyConfigSkipsSeed() async {
        let settings = InMemorySettingsStore()
        settings.appTriggerBundleIDs = ["com.tinyspeck.slackmacgap"]
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])

        _ = AppTrigger(settings: settings, source: source)

        XCTAssertTrue(settings.bool(.hasSeededAppDefaults, default: false))
        XCTAssertEqual(settings.appTriggerBundleIDs, ["com.tinyspeck.slackmacgap"])
    }

    // MARK: - pickableRunningBundleIDs (S7.8)

    func testPickableRunningBundleIDsDefaultsToRunningInMock() {
        let source = MockWorkspaceSource(runningBundleIDs: [
            "us.zoom.xos",
            "com.apple.Safari"
        ])
        XCTAssertEqual(Set(source.pickableRunningBundleIDs), Set(source.runningBundleIDs))
    }

    func testPickableRunningBundleIDsOverrideTakesPrecedence() {
        let source = MockWorkspaceSource(runningBundleIDs: [
            "us.zoom.xos",
            "com.example.daemon",
            "com.example.menubar.helper"
        ])
        source.pickableOverride = ["us.zoom.xos"] // simulating .regular filter
        XCTAssertEqual(source.pickableRunningBundleIDs, ["us.zoom.xos"])
        // Real running list is unfiltered:
        XCTAssertEqual(source.runningBundleIDs.count, 3)
    }

    func testAppTriggerPickableRunningBundleIDsPassThrough() {
        let (trigger, source, _) = makeFixture(running: [
            "us.zoom.xos",
            "com.apple.Safari"
        ])
        source.pickableOverride = ["us.zoom.xos"]
        XCTAssertEqual(trigger.pickableRunningBundleIDs, ["us.zoom.xos"])
    }

    // MARK: - reevaluateWatched (S7.9)

    func testReevaluateWatchedAfterAddingNewMatchEmitsOn() async throws {
        let settings = InMemorySettingsStore()
        settings.appTriggerBundleIDs = []
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])
        let trigger = AppTrigger(settings: settings, source: source)
        await trigger.start()

        // No initial vote (watched was empty).
        var iterator = trigger.voteStream.makeAsyncIterator()

        settings.appTriggerBundleIDs = ["us.zoom.xos"]
        trigger.reevaluateWatched()

        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertTrue(vote?.reason.contains("Zoom") ?? false)
    }

    func testReevaluateWatchedAfterRemovingLastMatchEmitsOff() async throws {
        let settings = InMemorySettingsStore()
        settings.appTriggerBundleIDs = ["us.zoom.xos"]
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])
        let trigger = AppTrigger(settings: settings, source: source)
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let onVote = await iterator.next()
        XCTAssertEqual(onVote?.wantsAwake, true)

        settings.appTriggerBundleIDs = []
        trigger.reevaluateWatched()

        let offVote = await iterator.next()
        XCTAssertEqual(offVote?.wantsAwake, false)
    }

    func testReevaluateWatchedNoChangeIsNoOp() async throws {
        let settings = InMemorySettingsStore()
        settings.appTriggerBundleIDs = ["us.zoom.xos"]
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])
        let trigger = AppTrigger(settings: settings, source: source)
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        _ = await iterator.next() // initial ON

        // Settings unchanged; reevaluate must be a no-op.
        trigger.reevaluateWatched()

        let task = Task { @MainActor () -> TriggerVote? in
            await iterator.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        let v = await task.value
        XCTAssertNil(v, "reevaluate with unchanged settings must not re-emit")
    }

    func testReevaluateWatchedSetChangedButStillNonEmptyReEmitsForUpdatedReason() async throws {
        let settings = InMemorySettingsStore()
        settings.appTriggerBundleIDs = ["us.zoom.xos"]
        let source = MockWorkspaceSource(runningBundleIDs: [
            "us.zoom.xos",
            "com.microsoft.teams2"
        ])
        let trigger = AppTrigger(settings: settings, source: source)
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let firstOn = await iterator.next()
        XCTAssertEqual(firstOn?.reason, "App: Zoom")

        // Add Teams to watched — now both Zoom + Teams match.
        settings.appTriggerBundleIDs = ["us.zoom.xos", "com.microsoft.teams2"]
        trigger.reevaluateWatched()

        let secondOn = await iterator.next()
        XCTAssertEqual(secondOn?.wantsAwake, true)
        // Sorted bundle ids: ["com.microsoft.teams2", "us.zoom.xos"] →
        // friendly: ["Microsoft Teams", "Zoom"] → "App: Microsoft Teams, Zoom".
        XCTAssertTrue(secondOn?.reason.contains("Microsoft Teams") ?? false,
                      "expected reason to mention the newly-watched matching app")
    }

    func testReevaluateWatchedWhileStoppedIsNoOp() async throws {
        let settings = InMemorySettingsStore()
        settings.appTriggerBundleIDs = ["us.zoom.xos"]
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])
        let trigger = AppTrigger(settings: settings, source: source)
        // Don't call start() — observation is nil.

        settings.appTriggerBundleIDs = ["com.microsoft.teams2"]
        trigger.reevaluateWatched()

        var iterator = trigger.voteStream.makeAsyncIterator()
        let task = Task { @MainActor () -> TriggerVote? in
            await iterator.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        let v = await task.value
        XCTAssertNil(v, "reevaluate while stopped must not emit (start() will read fresh data)")
    }

    // MARK: - Lifecycle: stop + restart (S7.9 stream stays open)

    func testRestartAfterStopReEmitsInitialSnapshot() async throws {
        let settings = InMemorySettingsStore()
        settings.appTriggerBundleIDs = ["us.zoom.xos"]
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])
        let trigger = AppTrigger(settings: settings, source: source)

        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let firstOn = await iterator.next()
        XCTAssertEqual(firstOn?.wantsAwake, true)

        trigger.stop()
        // Stop must NOT finish the continuation — the stream stays open so a
        // future `start()` can deliver votes again. Regression guard for the
        // pre-S7.9 bug where the consumer task was permanently silent after
        // a Toggle OFF → ON cycle.

        await trigger.start()
        let secondOn = await iterator.next()
        XCTAssertEqual(secondOn?.wantsAwake, true,
                       "restart should re-emit the initial-snapshot ON vote")
    }
}
