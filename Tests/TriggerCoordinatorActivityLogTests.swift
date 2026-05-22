import XCTest
@testable import Latte

@MainActor
final class TriggerCoordinatorActivityLogTests: XCTestCase {

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LatteCoordActivityTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeRig(activityStore: ActivityLogStore?) -> (TriggerCoordinator, AwakeManager) {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        let manager = AwakeManager(assertion: assertion, settings: settings)
        let coordinator = TriggerCoordinator(
            awakeManager: manager,
            settings: settings,
            activityStore: activityStore
        )
        return (coordinator, manager)
    }

    // MARK: - Tests

    func testHandleVoteOnAppendsVoteOnEntry() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ActivityLogStore(directory: dir)
        let (coordinator, _) = makeRig(activityStore: store)
        let trigger = MockTrigger(id: "wifi")
        coordinator.register(trigger)
        await coordinator.start(trigger)

        trigger.emit(TriggerVote(wantsAwake: true, reason: "matched SSID"))
        try await Task.sleep(nanoseconds: 100_000_000)

        let snap = await store.snapshot()
        XCTAssertEqual(snap.count, 1)
        XCTAssertEqual(snap.first?.triggerId, "wifi")
        XCTAssertEqual(snap.first?.kind, .on)
        XCTAssertEqual(snap.first?.reasonCode, .voteOn)
    }

    func testHandleVoteOffAppendsVoteOffEntry() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ActivityLogStore(directory: dir)
        let (coordinator, _) = makeRig(activityStore: store)
        let trigger = MockTrigger(id: "calendar")
        coordinator.register(trigger)
        await coordinator.start(trigger)

        trigger.emit(TriggerVote(wantsAwake: true, reason: "Standup"))
        try await Task.sleep(nanoseconds: 100_000_000)
        trigger.emit(TriggerVote(wantsAwake: false, reason: "no event"))
        try await Task.sleep(nanoseconds: 100_000_000)

        let snap = await store.snapshot()
        XCTAssertEqual(snap.count, 2)
        XCTAssertEqual(snap.last?.kind, .off)
        XCTAssertEqual(snap.last?.reasonCode, .voteOff)
    }

    func testStopAppendsUserToggleOffEntry() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ActivityLogStore(directory: dir)
        let (coordinator, _) = makeRig(activityStore: store)
        let trigger = MockTrigger(id: "focus")
        coordinator.register(trigger)
        await coordinator.start(trigger)

        trigger.emit(TriggerVote(wantsAwake: true, reason: "Work"))
        try await Task.sleep(nanoseconds: 100_000_000)

        coordinator.stop("focus")
        try await Task.sleep(nanoseconds: 100_000_000)

        let snap = await store.snapshot()
        XCTAssertEqual(snap.count, 2)
        XCTAssertEqual(snap.last?.kind, .off)
        XCTAssertEqual(snap.last?.reasonCode, .userToggleOff,
                       "user-explicit stop must distinguish from organic OFF")
    }

    func testNilStoreDoesNotCrashOnVoteOrStop() async throws {
        let (coordinator, _) = makeRig(activityStore: nil)
        let trigger = MockTrigger(id: "wifi")
        coordinator.register(trigger)
        await coordinator.start(trigger)

        // Should not crash with nil store injected.
        trigger.emit(TriggerVote(wantsAwake: true, reason: "x"))
        try await Task.sleep(nanoseconds: 50_000_000)
        coordinator.stop("wifi")
        try await Task.sleep(nanoseconds: 50_000_000)

        // No assertion on store — nil means logging is opt-out, behavior unchanged.
    }

    // MARK: - Live polling refresh (C-3 deferred — live update while Activity tab open)

    /// Notification posted on every activity-log mutation so an open
    /// Activity tab can refresh without polling on a timer. Tested at the
    /// coordinator boundary because the actor itself can't post from a
    /// non-MainActor context cheaply. Captures every site that records
    /// activity (vote ON / vote OFF / user-explicit stop).
    func testHandleVoteOnPostsActivityLogDidAppendNotification() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }
        let store = ActivityLogStore(directory: dir)
        let (coordinator, _) = makeRig(activityStore: store)
        let trigger = MockTrigger(id: "wifi")
        coordinator.register(trigger)
        await coordinator.start(trigger)

        let exp = expectation(forNotification: .activityLogDidAppend, object: nil)
        trigger.emit(TriggerVote(wantsAwake: true, reason: "matched"))
        await fulfillment(of: [exp], timeout: 1.0)
    }

    func testHandleVoteOffPostsActivityLogDidAppendNotification() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }
        let store = ActivityLogStore(directory: dir)
        let (coordinator, _) = makeRig(activityStore: store)
        let trigger = MockTrigger(id: "calendar")
        coordinator.register(trigger)
        await coordinator.start(trigger)
        trigger.emit(TriggerVote(wantsAwake: true, reason: "Standup"))
        try await Task.sleep(nanoseconds: 100_000_000)

        let exp = expectation(forNotification: .activityLogDidAppend, object: nil)
        trigger.emit(TriggerVote(wantsAwake: false, reason: "no event"))
        await fulfillment(of: [exp], timeout: 1.0)
    }

    func testStopPostsActivityLogDidAppendNotification() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }
        let store = ActivityLogStore(directory: dir)
        let (coordinator, _) = makeRig(activityStore: store)
        let trigger = MockTrigger(id: "focus")
        coordinator.register(trigger)
        await coordinator.start(trigger)
        trigger.emit(TriggerVote(wantsAwake: true, reason: "Work"))
        try await Task.sleep(nanoseconds: 100_000_000)

        let exp = expectation(forNotification: .activityLogDidAppend, object: nil)
        coordinator.stop("focus")
        await fulfillment(of: [exp], timeout: 1.0)
    }

    /// Ordering contract: the `.activityLogDidAppend` signal must fire only
    /// *after* the append has committed to the store, so a consumer that
    /// re-fetches the snapshot on the signal always sees the new row. Locks
    /// the invariant the previous "post then append" code only satisfied by
    /// accident of the consumer's debounce.
    func testNotificationImpliesCommittedAppend() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }
        let store = ActivityLogStore(directory: dir)
        let (coordinator, _) = makeRig(activityStore: store)
        let trigger = MockTrigger(id: "wifi")
        coordinator.register(trigger)
        await coordinator.start(trigger)

        let exp = expectation(description: "snapshot contains the row when the signal fires")
        let token = NotificationCenter.default.addObserver(
            forName: .activityLogDidAppend, object: nil, queue: nil
        ) { _ in
            Task {
                let snap = await store.snapshot()
                XCTAssertGreaterThanOrEqual(
                    snap.count, 1,
                    "live-refresh signal must not precede the committed append"
                )
                exp.fulfill()
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        trigger.emit(TriggerVote(wantsAwake: true, reason: "matched"))
        await fulfillment(of: [exp], timeout: 1.0)
    }

    /// `stop` on an idle trigger has nothing to log — no notification fires.
    /// Prevents a spurious refresh on a no-op user toggle.
    func testStopWithoutActiveVoteDoesNotPostNotification() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }
        let store = ActivityLogStore(directory: dir)
        let (coordinator, _) = makeRig(activityStore: store)
        let trigger = MockTrigger(id: "wifi")
        coordinator.register(trigger)
        await coordinator.start(trigger)

        var observed = 0
        let token = NotificationCenter.default.addObserver(
            forName: .activityLogDidAppend, object: nil, queue: nil
        ) { _ in observed += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        coordinator.stop("wifi")
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(observed, 0,
                       "stop() with no active vote must not emit a refresh signal")
    }

    /// Notifications must not fire when no store is wired — they describe
    /// a store-state mutation that didn't happen, and would cause spurious
    /// reloads in any consumer that subscribes regardless of store presence.
    func testNilStoreSuppressesActivityLogDidAppendNotification() async throws {
        let (coordinator, _) = makeRig(activityStore: nil)
        let trigger = MockTrigger(id: "wifi")
        coordinator.register(trigger)
        await coordinator.start(trigger)

        var observed = 0
        let token = NotificationCenter.default.addObserver(
            forName: .activityLogDidAppend, object: nil, queue: nil
        ) { _ in observed += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        trigger.emit(TriggerVote(wantsAwake: true, reason: "x"))
        try await Task.sleep(nanoseconds: 100_000_000)
        coordinator.stop("wifi")
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(observed, 0,
                       "nil store: no append happened, so no signal must fire")
    }
}
