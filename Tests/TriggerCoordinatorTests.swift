import XCTest
@testable import Latte

@MainActor
final class TriggerCoordinatorTests: XCTestCase {

    private func makeCoordinator() -> (TriggerCoordinator, AwakeManager, MockPowerAssertion, InMemorySettingsStore) {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        let manager = AwakeManager(assertion: assertion, settings: settings)
        let coordinator = TriggerCoordinator(awakeManager: manager, settings: settings)
        return (coordinator, manager, assertion, settings)
    }

    func testRegisterAddsTrigger() {
        let (coordinator, _, _, _) = makeCoordinator()
        let trigger = MockTrigger(id: "mock1")
        coordinator.register(trigger)
        XCTAssertEqual(coordinator.triggers.count, 1)
        XCTAssertEqual(coordinator.triggers.first?.id, "mock1")
    }

    func testDuplicateRegistrationIsRejected() {
        let (coordinator, _, _, _) = makeCoordinator()
        let trigger = MockTrigger(id: "dup")
        coordinator.register(trigger)
        coordinator.register(MockTrigger(id: "dup"))
        XCTAssertEqual(coordinator.triggers.count, 1)
    }

    func testStartCallsTriggerStart() async {
        let (coordinator, _, _, _) = makeCoordinator()
        let trigger = MockTrigger(id: "m")
        coordinator.register(trigger)
        await coordinator.start(trigger)
        XCTAssertEqual(trigger.startCalls, 1)
    }

    func testStartEnabledTriggersOnlyStartsEnabled() async {
        let (coordinator, _, _, _) = makeCoordinator()
        let on = MockTrigger(id: "on", isEnabled: true)
        let off = MockTrigger(id: "off", isEnabled: false)
        coordinator.register(on)
        coordinator.register(off)
        await coordinator.startEnabledTriggers()
        XCTAssertEqual(on.startCalls, 1)
        XCTAssertEqual(off.startCalls, 0)
    }

    func testVoteForwardsToManager() async throws {
        let (coordinator, manager, assertion, _) = makeCoordinator()
        let trigger = MockTrigger(id: "vote-trigger")
        coordinator.register(trigger)
        await coordinator.start(trigger)

        trigger.emit(TriggerVote(wantsAwake: true, reason: "from test"))

        // Allow consumer task to drain.
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(manager.isAwake, "vote should propagate to manager")
        XCTAssertTrue(assertion.isActive)
        XCTAssertEqual(coordinator.activeVotes["vote-trigger"]?.reason, "from test")
    }

    func testStopRemovesActiveVoteAndCancelsConsumer() async throws {
        let (coordinator, manager, _, _) = makeCoordinator()
        let trigger = MockTrigger(id: "to-stop")
        coordinator.register(trigger)
        await coordinator.start(trigger)
        trigger.emit(TriggerVote(wantsAwake: true, reason: "x"))
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNotNil(coordinator.activeVotes["to-stop"])

        coordinator.stop("to-stop")
        XCTAssertNil(coordinator.activeVotes["to-stop"])
        XCTAssertEqual(trigger.stopCalls, 1)
        // Manager should have received an off vote.
        try await Task.sleep(nanoseconds: 50_000_000)
        if case .coolingDown = manager.state {
            // ok — single vote-off goes to cooling
        } else if case .asleep = manager.state {
            // also acceptable if cool-down already fired in test environment
        } else {
            XCTFail("expected coolingDown or asleep, got \(manager.state)")
        }
    }

    // MARK: - S7.9 owner-scenario integration

    /// Reproduces the exact UI flow:
    ///   1. App launches, AppTrigger seeded with one running watched app, started by coordinator.
    ///   2. Cup activates from the initial-snapshot ON vote.
    ///   3. User toggles OFF in Settings → coordinator.stop("app").
    /// Manager state must transition out of `.awakeTriggered` (to `.coolingDown` or `.asleep`).
    /// If this test passes but real-app behavior doesn't deactivate, the bug is in the SwiftUI
    /// Toggle wiring layer (TriggersTab.swift) — not in coordinator/manager/trigger logic.
    func testOwnerScenarioToggleOffDeactivatesViaRealAppTrigger() async throws {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .appTriggerEnabled)
        settings.appTriggerBundleIDs = ["us.zoom.xos"]
        settings.setBool(true, for: .hasSeededAppDefaults)

        let manager = AwakeManager(assertion: assertion, settings: settings)
        let coordinator = TriggerCoordinator(awakeManager: manager, settings: settings)
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])
        let trigger = AppTrigger(settings: settings, source: source)
        coordinator.register(trigger)

        await coordinator.start(trigger)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(manager.isAwake, "trigger ON vote must activate manager")
        XCTAssertTrue(assertion.isActive, "power assertion must be held")
        if case .awakeTriggered = manager.state { } else {
            XCTFail("expected .awakeTriggered, got \(manager.state)")
        }

        // User flips Toggle OFF — UI calls trigger.isEnabled=false then coordinator.stop.
        // S7.10: coordinator.stop now sends a grace=0 vote-off, so the state machine
        // skips cool-down and releases the assertion immediately.
        trigger.isEnabled = false
        coordinator.stop(trigger.id)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(manager.state, .asleep,
                       "S7.10: Toggle OFF must release assertion immediately (grace=0)")
        XCTAssertFalse(manager.isAwake)
        XCTAssertFalse(assertion.isActive)
    }

    /// Same scenario but owner removes the only watched app instead of toggling OFF.
    /// Verifies AppTrigger.reevaluateWatched() pushes a vote-OFF through the coordinator.
    func testOwnerScenarioRemovingLastWatchedAppDeactivates() async throws {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .appTriggerEnabled)
        settings.appTriggerBundleIDs = ["us.zoom.xos"]
        settings.setBool(true, for: .hasSeededAppDefaults)

        let manager = AwakeManager(assertion: assertion, settings: settings)
        let coordinator = TriggerCoordinator(awakeManager: manager, settings: settings)
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])
        let trigger = AppTrigger(settings: settings, source: source)
        coordinator.register(trigger)

        await coordinator.start(trigger)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(manager.isAwake)
        if case .awakeTriggered = manager.state { } else {
            XCTFail("expected .awakeTriggered, got \(manager.state)")
        }

        // User removes Zoom from watched list via Settings UI:
        // S7.10: reevaluateWatched yields a grace=0 vote-off (user-explicit edit),
        // so the state machine skips cool-down.
        settings.appTriggerBundleIDs = []
        trigger.reevaluateWatched()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(manager.state, .asleep,
                       "S7.10: removing the last matching watched app must release immediately")
        XCTAssertFalse(manager.isAwake)
        XCTAssertFalse(assertion.isActive)
    }

    /// Toggle ON path: starts as OFF, user enables in Settings → coordinator.start
    /// fires → trigger.start does initial snapshot → emits ON vote if a watched
    /// app is currently running → manager activates immediately.
    func testOwnerScenarioToggleOnActivatesImmediatelyWhenWatchedAppRunning() async throws {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        // Trigger starts disabled. Watched list pre-configured.
        settings.setBool(false, for: .appTriggerEnabled)
        settings.appTriggerBundleIDs = ["us.zoom.xos"]
        settings.setBool(true, for: .hasSeededAppDefaults)

        let manager = AwakeManager(assertion: assertion, settings: settings)
        let coordinator = TriggerCoordinator(awakeManager: manager, settings: settings)
        let source = MockWorkspaceSource(runningBundleIDs: ["us.zoom.xos"])
        let trigger = AppTrigger(settings: settings, source: source)
        coordinator.register(trigger)

        // Pre-condition: nothing started, manager asleep.
        XCTAssertEqual(manager.state, .asleep)
        XCTAssertFalse(manager.isAwake)

        // Simulate Toggle ON: TriggerSection.onChange writes isEnabled, then
        // spawns a Task that calls coordinator.start.
        trigger.isEnabled = true
        await coordinator.start(trigger)
        try await Task.sleep(nanoseconds: 100_000_000)

        if case .awakeTriggered(let votes) = manager.state {
            XCTAssertEqual(votes["app"]?.reason, "App: us.zoom.xos")
        } else {
            XCTFail("Toggle ON must transition to .awakeTriggered, got \(manager.state)")
        }
        XCTAssertTrue(manager.isAwake, "cup should activate immediately on Toggle ON")
        XCTAssertTrue(assertion.isActive)
    }

    /// Toggle ON when no watched app is running → no immediate vote → cup stays
    /// inactive until a watched app launches (handled by observeLifecycle).
    func testOwnerScenarioToggleOnNoMatchStaysInactive() async throws {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        settings.setBool(false, for: .appTriggerEnabled)
        settings.appTriggerBundleIDs = ["us.zoom.xos"]
        settings.setBool(true, for: .hasSeededAppDefaults)

        let manager = AwakeManager(assertion: assertion, settings: settings)
        let coordinator = TriggerCoordinator(awakeManager: manager, settings: settings)
        let source = MockWorkspaceSource(runningBundleIDs: ["com.apple.Safari"])
        let trigger = AppTrigger(settings: settings, source: source)
        coordinator.register(trigger)

        trigger.isEnabled = true
        await coordinator.start(trigger)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(manager.state, .asleep, "no matching watched app → no activation")
        XCTAssertFalse(manager.isAwake)
        XCTAssertFalse(assertion.isActive)

        // Then user launches Zoom → observeLifecycle fires → cup activates.
        source.simulateLaunch("us.zoom.xos")
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(manager.isAwake, "cup must activate when watched app launches")
        if case .awakeTriggered = manager.state { } else {
            XCTFail("expected .awakeTriggered after launch, got \(manager.state)")
        }
    }

    func testMultipleTriggersAllVotedOnAggregateAwake() async throws {
        let (coordinator, manager, _, _) = makeCoordinator()
        let calTrigger = MockTrigger(id: "cal")
        let appTrigger = MockTrigger(id: "app")
        coordinator.register(calTrigger)
        coordinator.register(appTrigger)
        await coordinator.start(calTrigger)
        await coordinator.start(appTrigger)

        calTrigger.emit(TriggerVote(wantsAwake: true, reason: "Meet"))
        appTrigger.emit(TriggerVote(wantsAwake: true, reason: "Zoom"))
        try await Task.sleep(nanoseconds: 50_000_000)

        if case .awakeTriggered(let votes) = manager.state {
            XCTAssertEqual(votes.count, 2)
        } else { XCTFail("expected awakeTriggered, got \(manager.state)") }
    }
}
