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
}
