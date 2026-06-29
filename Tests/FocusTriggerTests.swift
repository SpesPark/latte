import XCTest
@testable import Latte

@MainActor
final class FocusTriggerTests: XCTestCase {

    private func makeFixture(
        focusIDs: [String] = ["work"],
        isFocusActive: Bool = false,
        permissionStatus: TriggerPermissionStatus = .granted
    ) -> (FocusTrigger, MockFocusSource, InMemorySettingsStore) {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .focusTriggerEnabled)
        settings.focusTriggerFocusIDs = focusIDs
        let source = MockFocusSource(
            permissionStatus: permissionStatus,
            isFocusActive: isFocusActive
        )
        let trigger = FocusTrigger(settings: settings, source: source)
        return (trigger, source, settings)
    }

    func testActiveFocusEmitsOnWhenStarted() async throws {
        let (trigger, _, _) = makeFixture(isFocusActive: true)
        await trigger.start()

        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertEqual(vote?.reason, "Focus: active")
    }

    func testInactiveFocusNoEmitOnStart() async throws {
        let (trigger, _, _) = makeFixture(isFocusActive: false)
        await trigger.start()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v) }
    }

    func testFocusActivationFlipsToOn() async throws {
        let (trigger, source, _) = makeFixture(isFocusActive: false)
        await trigger.start()
        source.isFocusActive = true

        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
    }

    func testFocusDeactivationFlipsToOff() async throws {
        let (trigger, source, _) = makeFixture(isFocusActive: true)
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let on = await iterator.next()
        XCTAssertEqual(on?.wantsAwake, true)

        source.isFocusActive = false
        let off = await iterator.next()
        XCTAssertEqual(off?.wantsAwake, false)
    }

    func testFocusIDsAccessorFallsBackToWorkWhenEmpty() {
        let settings = InMemorySettingsStore()
        // Empty raw → accessor returns ["work"] per 04 §4.5 default.
        XCTAssertEqual(settings.focusTriggerFocusIDs, ["work"])
    }

    func testDeniedPermissionNoOp() async throws {
        let (trigger, _, _) = makeFixture(
            isFocusActive: true,
            permissionStatus: .denied
        )
        await trigger.start()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v) }
    }

    func testRequestPermissionIfNeededHonorsStatus() async {
        let settings = InMemorySettingsStore()

        let granted = MockFocusSource(permissionStatus: .granted)
        let g = FocusTrigger(settings: settings, source: granted)
        let r1 = await g.requestPermissionIfNeeded()
        XCTAssertTrue(r1)
        XCTAssertEqual(granted.requestAccessCalls, 0)

        let denied = MockFocusSource(permissionStatus: .denied)
        let d = FocusTrigger(settings: settings, source: denied)
        let r2 = await d.requestPermissionIfNeeded()
        XCTAssertFalse(r2)
        XCTAssertEqual(denied.requestAccessCalls, 0)

        let nd = MockFocusSource(permissionStatus: .notDetermined)
        let n = FocusTrigger(settings: settings, source: nd)
        let r3 = await n.requestPermissionIfNeeded()
        XCTAssertTrue(r3)
        XCTAssertEqual(nd.requestAccessCalls, 1)
    }

    func testStopPreventsFurtherEmission() async throws {
        let (trigger, source, _) = makeFixture(isFocusActive: true)
        await trigger.start()
        var iterator = trigger.voteStream.makeAsyncIterator()
        _ = await iterator.next()

        trigger.stop()
        // After stop, observation handle is gone — flipping source must not vote.
        source.isFocusActive = false
        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        // S7.11: stream stays open after stop (no continuation.finish), so the
        // iterator just blocks until the cancel. value is nil because the task
        // was cancelled before any yield could arrive.
        do { let _v = await task.value; XCTAssertNil(_v) }
    }
}
