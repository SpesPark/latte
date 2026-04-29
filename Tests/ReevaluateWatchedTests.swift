import XCTest
@testable import Latte

/// V2-02 — surface-parity tests for `reevaluateWatched()` across
/// CalendarTrigger / WiFiTrigger / ScheduleTrigger. The contract:
/// - When the trigger is running, the method re-runs the trigger's
///   internal evaluation immediately (no 30-60 s poll wait).
/// - When the trigger is stopped, the method is a no-op (the next
///   `start()` will read fresh settings on its initial poll/evaluate).
@MainActor
final class ReevaluateWatchedTests: XCTestCase {

    // MARK: - CalendarTrigger

    func testCalendarReevaluateWatchedNoOpWhenStopped() async {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .calendarTriggerEnabled)
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let event = CalendarEventSnapshot(
            id: "ev",
            title: "Meeting",
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(600),
            isAllDay: false,
            calendarID: "cal-1"
        )
        let source = MockCalendarSource(events: [event])
        let trigger = CalendarTrigger(
            settings: settings,
            source: source,
            pollInterval: 60,
            now: { now }
        )
        // Note: not started.
        trigger.reevaluateWatched()
        // Wait briefly to ensure no Task has yielded a vote.
        let probe = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        probe.cancel()
        let vote = await probe.value
        XCTAssertNil(vote, "stopped trigger should not emit votes from reevaluate")
    }

    func testCalendarReevaluateWatchedEmitsWhenRunningAndConditionTrue() async throws {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .calendarTriggerEnabled)
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let event = CalendarEventSnapshot(
            id: "ev",
            title: "Standup",
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(600),
            isAllDay: false,
            calendarID: "cal-1"
        )
        let source = MockCalendarSource(events: [event])
        let trigger = CalendarTrigger(
            settings: settings,
            source: source,
            pollInterval: 60,
            now: { now }
        )
        await trigger.start()
        // Drain the initial poll vote.
        var it = trigger.voteStream.makeAsyncIterator()
        let initial = await it.next()
        XCTAssertEqual(initial?.wantsAwake, true)

        // Reevaluate while same condition holds — no state change, so the
        // trigger's internal newlyActive set is empty → no new vote.
        trigger.reevaluateWatched()
        let probe = Task { @MainActor () -> TriggerVote? in
            await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        probe.cancel()
        let no = await probe.value
        XCTAssertNil(no, "no transition → no new vote")

        trigger.stop()
    }

    // MARK: - WiFiTrigger

    func testWiFiReevaluateWatchedNoOpWhenStopped() async {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .wifiTriggerEnabled)
        settings.wifiTriggerSSIDs = ["HomeWifi"]
        let source = MockWiFiSource(currentSSID: "HomeWifi")
        let trigger = WiFiTrigger(settings: settings, source: source)
        // Note: not started.
        trigger.reevaluateWatched()
        let probe = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        probe.cancel()
        let vote = await probe.value
        XCTAssertNil(vote, "stopped trigger should not emit votes from reevaluate")
    }

    func testWiFiReevaluateWatchedEmitsTransitionWhenRunningAndConditionFlips() async throws {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .wifiTriggerEnabled)
        settings.wifiTriggerSSIDs = ["HomeWifi"]
        let source = MockWiFiSource(currentSSID: "HomeWifi")
        let trigger = WiFiTrigger(settings: settings, source: source)
        await trigger.start()
        var it = trigger.voteStream.makeAsyncIterator()
        let on = await it.next()
        XCTAssertEqual(on?.wantsAwake, true)

        // User removes the SSID from the watched list — reevaluate should
        // emit OFF immediately rather than waiting 30 s for the next poll.
        settings.wifiTriggerSSIDs = []
        trigger.reevaluateWatched()
        let off = await it.next()
        XCTAssertEqual(off?.wantsAwake, false)

        trigger.stop()
    }

    // MARK: - ScheduleTrigger

    func testScheduleReevaluateWatchedNoOpWhenStopped() async {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .scheduleTriggerEnabled)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 27
        comps.hour = 12; comps.minute = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        let now = cal.date(from: comps)!
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0),
            label: "Workday"
        )
        settings.scheduleTriggerEntries = [entry]
        let trigger = ScheduleTrigger(
            settings: settings,
            now: { now },
            calendar: cal
        )
        // Note: not started.
        trigger.reevaluateWatched()
        let probe = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        probe.cancel()
        let vote = await probe.value
        XCTAssertNil(vote, "stopped trigger should not emit votes from reevaluate")
    }

    func testScheduleReevaluateWatchedEmitsTransitionWhenRunningAndEntryListChanges() async throws {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .scheduleTriggerEnabled)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 27
        comps.hour = 12; comps.minute = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        let now = cal.date(from: comps)!
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0),
            label: "Workday"
        )
        settings.scheduleTriggerEntries = [entry]
        let trigger = ScheduleTrigger(
            settings: settings,
            now: { now },
            calendar: cal
        )
        await trigger.start()
        var it = trigger.voteStream.makeAsyncIterator()
        let on = await it.next()
        XCTAssertEqual(on?.wantsAwake, true)

        // User clears the list — reevaluate should emit OFF immediately.
        settings.scheduleTriggerEntries = []
        trigger.reevaluateWatched()
        let off = await it.next()
        XCTAssertEqual(off?.wantsAwake, false)

        trigger.stop()
    }
}
