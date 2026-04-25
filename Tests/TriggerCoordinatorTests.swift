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
