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
        XCTAssertTrue(vote?.reason.contains("us.zoom.xos") ?? false)
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
        // After stop, simulate doesn't dispatch anywhere observable to caller because
        // trigger.continuation is finished. Sanity check: simulateLaunch should be a no-op.
        source.simulateLaunch("com.microsoft.teams2")
    }

    func testDisabledTriggerNoOpOnStart() async throws {
        let settings = InMemorySettingsStore()
        // .appTriggerEnabled left false (not used by start; but bootTriggers checks it)
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])
        let trigger = AppTrigger(settings: settings, source: source)
        // start() itself doesn't gate on isEnabled — that's coordinator's job.
        // But snapshot uses settings.appTriggerBundleIDs which falls back to defaults.
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true) // defaults include zoom
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
}
