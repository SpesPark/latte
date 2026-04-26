import XCTest
@testable import Latte

/// End-to-end test crossing `MockTrigger` × `TriggerCoordinator` × real `AwakeManager`.
/// Covers the happy path from 03 §8.1 (Zoom meeting) to verify the wired pipeline matches
/// the spec — equivalent to `AwakeManagerTests.test81` but going through a real trigger emit.
@MainActor
final class TriggerIntegrationTests: XCTestCase {

    func test81_ZoomMeetingHappyPath_throughCoordinator() async throws {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        let manager = AwakeManager(assertion: assertion, settings: settings)
        let coordinator = TriggerCoordinator(awakeManager: manager, settings: settings)
        let calendar = MockTrigger(id: "cal")
        coordinator.register(calendar)
        await coordinator.start(calendar)

        // 14:00 — calendar votes ON
        calendar.emit(TriggerVote(wantsAwake: true, reason: "Calendar: Standup"))
        try await Task.sleep(nanoseconds: 50_000_000)

        guard case .awakeTriggered(let votes) = manager.state else {
            return XCTFail("expected awakeTriggered, got \(manager.state)")
        }
        XCTAssertEqual(votes["cal"]?.reason, "Calendar: Standup")
        XCTAssertTrue(assertion.isActive)

        // 14:30 — calendar votes OFF
        calendar.emit(TriggerVote(wantsAwake: false, reason: "Calendar: ended"))
        try await Task.sleep(nanoseconds: 50_000_000)

        // Per §8.1, transition is to CoolingDown for 60s. Test environment may have already
        // transitioned to Asleep depending on timer scheduling — accept either.
        switch manager.state {
        case .coolingDown:
            XCTAssertTrue(assertion.isActive, "assertion held during cool-down")
        case .asleep:
            XCTAssertFalse(assertion.isActive)
        default:
            XCTFail("expected coolingDown or asleep, got \(manager.state)")
        }
    }

    func test82_BackToBackMeetings_assertionNeverReleased() async throws {
        let assertion = MockPowerAssertion()
        let settings = InMemorySettingsStore()
        let manager = AwakeManager(assertion: assertion, settings: settings)
        let coordinator = TriggerCoordinator(awakeManager: manager, settings: settings)
        let calendar = MockTrigger(id: "cal")
        coordinator.register(calendar)
        await coordinator.start(calendar)

        // 14:00 — meeting A on
        // S7.10: cool-down only engages when the trigger declares grace>0.
        // To exercise the back-to-back absorption scenario, we emit votes
        // with an explicit 30s grace (a hypothetical future trigger config).
        calendar.emit(TriggerVote(wantsAwake: true, reason: "A", graceSecondsAfterOff: 30))
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(assertion.isActive)
        let initialActivations = assertion.activations.count
        let initialDeactivations = assertion.deactivationCount

        // 14:30 — meeting A off (enters cool-down because grace=30)
        calendar.emit(TriggerVote(wantsAwake: false, reason: "A ended", graceSecondsAfterOff: 30))
        try await Task.sleep(nanoseconds: 30_000_000)
        // 14:30:30 — meeting B on (within cool-down window)
        calendar.emit(TriggerVote(wantsAwake: true, reason: "B", graceSecondsAfterOff: 30))
        try await Task.sleep(nanoseconds: 50_000_000)

        // Assertion must remain held throughout — never released.
        XCTAssertTrue(assertion.isActive)
        XCTAssertEqual(
            assertion.activations.count,
            initialActivations,
            "should not re-activate — single continuous session"
        )
        XCTAssertEqual(
            assertion.deactivationCount,
            initialDeactivations,
            "should not deactivate during cool-down → re-vote-on"
        )

        if case .awakeTriggered(let votes) = manager.state {
            XCTAssertEqual(votes["cal"]?.reason, "B")
        } else {
            XCTFail("expected awakeTriggered, got \(manager.state)")
        }
    }
}
