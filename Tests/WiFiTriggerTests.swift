import XCTest
@testable import Latte

@MainActor
final class WiFiTriggerTests: XCTestCase {

    private func makeFixture(
        ssids: [String] = ["HomeNet"],
        currentSSID: String? = nil,
        inverse: Bool = false,
        permissionStatus: TriggerPermissionStatus = .granted
    ) -> (WiFiTrigger, MockWiFiSource, InMemorySettingsStore) {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .wifiTriggerEnabled)
        settings.wifiTriggerSSIDs = ssids
        settings.wifiTriggerInverseLogic = inverse
        let source = MockWiFiSource(permissionStatus: permissionStatus, currentSSID: currentSSID)
        let trigger = WiFiTrigger(settings: settings, source: source, pollInterval: 30)
        return (trigger, source, settings)
    }

    func testOnAllowlistedSSIDEmitsOn() async throws {
        let (trigger, _, _) = makeFixture(currentSSID: "HomeNet")
        trigger.evaluate()

        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertTrue(vote?.reason.contains("HomeNet") ?? false)
    }

    func testOffAllowlistDoesNotEmitOn() async throws {
        let (trigger, _, _) = makeFixture(currentSSID: "Cafe-WiFi")
        trigger.evaluate()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v) }
    }

    func testTransitionFromOnToOffEmitsOff() async throws {
        let (trigger, source, _) = makeFixture(currentSSID: "HomeNet")
        trigger.evaluate()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let on = await iterator.next()
        XCTAssertEqual(on?.wantsAwake, true)

        source.currentSSID = "Cafe-WiFi"
        trigger.evaluate()
        let off = await iterator.next()
        XCTAssertEqual(off?.wantsAwake, false)
    }

    func testInverseLogicEmitsOnWhenOffList() async throws {
        let (trigger, _, _) = makeFixture(
            ssids: ["HomeNet"],
            currentSSID: "Cafe-WiFi",
            inverse: true
        )
        trigger.evaluate()

        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertTrue(vote?.reason.contains("Cafe") ?? false)
    }

    func testInverseLogicNoEmitWhenOnList() async throws {
        let (trigger, _, _) = makeFixture(
            ssids: ["HomeNet"],
            currentSSID: "HomeNet",
            inverse: true
        )
        trigger.evaluate()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v) }
    }

    func testInverseLogicWithEmptyListIsNoOp() async throws {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .wifiTriggerEnabled)
        settings.wifiTriggerInverseLogic = true
        // ssids is empty
        let source = MockWiFiSource(currentSSID: "Anywhere")
        let trigger = WiFiTrigger(settings: settings, source: source)
        trigger.evaluate()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v, "empty inverse list should never vote ON") }
    }

    func testRepeatedEvaluateWithSameStateDoesNotReEmit() async throws {
        let (trigger, _, _) = makeFixture(currentSSID: "HomeNet")
        trigger.evaluate()
        var iterator = trigger.voteStream.makeAsyncIterator()
        _ = await iterator.next()

        trigger.evaluate()
        let task = Task { @MainActor () -> TriggerVote? in
            await iterator.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v, "no state change → no vote") }
    }

    func testDisabledNoOp() async throws {
        let settings = InMemorySettingsStore()
        // wifiTriggerEnabled left false
        settings.wifiTriggerSSIDs = ["HomeNet"]
        let source = MockWiFiSource(currentSSID: "HomeNet")
        let trigger = WiFiTrigger(settings: settings, source: source)
        trigger.evaluate()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v) }
    }

    func testDeniedPermissionNoOp() async throws {
        let (trigger, _, _) = makeFixture(
            currentSSID: "HomeNet",
            permissionStatus: .denied
        )
        trigger.evaluate()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v) }
    }

    func testIsEnabledSetterPersists() {
        let settings = InMemorySettingsStore()
        let trigger = WiFiTrigger(settings: settings, source: MockWiFiSource())
        XCTAssertFalse(trigger.isEnabled)
        trigger.isEnabled = true
        XCTAssertTrue(trigger.isEnabled)
        XCTAssertTrue(settings.bool(.wifiTriggerEnabled, default: false))
    }

    func testPermissionStatusReflectsSource() {
        let settings = InMemorySettingsStore()
        let denied = MockWiFiSource(permissionStatus: .denied)
        let trigger = WiFiTrigger(settings: settings, source: denied)
        XCTAssertEqual(trigger.permissionStatus, .denied)
        denied.permissionStatus = .granted
        XCTAssertEqual(trigger.permissionStatus, .granted)
    }

    func testStartEvaluatesImmediatelyAndStopCancels() async throws {
        let (trigger, _, _) = makeFixture(currentSSID: "HomeNet")
        await trigger.start()
        // start() runs evaluate() synchronously before scheduling the loop, so
        // an ON vote should already be queued.
        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.wantsAwake, true)

        // Calling start again is a no-op (pollTask already running).
        await trigger.start()

        trigger.stop()
        // After stop, the stream is finished — next() returns nil.
        let after = await it.next()
        XCTAssertNil(after)
    }

    func testRequestPermissionIfNeededDelegatesToSource() async {
        let settings = InMemorySettingsStore()

        // .granted → true, no source call
        let granted = MockWiFiSource(permissionStatus: .granted)
        let g = WiFiTrigger(settings: settings, source: granted)
        let r1 = await g.requestPermissionIfNeeded()
        XCTAssertTrue(r1)
        XCTAssertEqual(granted.requestAccessCalls, 0)

        // .denied → false, no source call
        let denied = MockWiFiSource(permissionStatus: .denied)
        let d = WiFiTrigger(settings: settings, source: denied)
        let r2 = await d.requestPermissionIfNeeded()
        XCTAssertFalse(r2)
        XCTAssertEqual(denied.requestAccessCalls, 0)

        // .notDetermined → asks; mock auto-grants
        let nd = MockWiFiSource(permissionStatus: .notDetermined)
        let n = WiFiTrigger(settings: settings, source: nd)
        let r3 = await n.requestPermissionIfNeeded()
        XCTAssertTrue(r3)
        XCTAssertEqual(nd.requestAccessCalls, 1)
    }
}
