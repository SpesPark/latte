import XCTest
@testable import Latte

@MainActor
final class CalendarTriggerTests: XCTestCase {

    // MARK: - Setup helpers

    private func makeFixture(
        events: [CalendarEventSnapshot] = [],
        permissionStatus: TriggerPermissionStatus = .granted,
        nowOverride: Date? = nil
    ) -> (CalendarTrigger, MockCalendarSource, InMemorySettingsStore, Date) {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .calendarTriggerEnabled)
        let source = MockCalendarSource(permissionStatus: permissionStatus, events: events)
        let now = nowOverride ?? Date(timeIntervalSince1970: 1_750_000_000) // fixed
        let trigger = CalendarTrigger(
            settings: settings,
            source: source,
            pollInterval: 60,
            now: { now }
        )
        return (trigger, source, settings, now)
    }

    // MARK: - Tests

    func testActiveEventEmitsOnVote() async {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let event = CalendarEventSnapshot(
            id: "ev-active",
            title: "Standup",
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(600),
            isAllDay: false,
            calendarID: "cal-1"
        )
        let (trigger, _, _, _) = makeFixture(events: [event], nowOverride: now)
        await trigger.pollOnce()

        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertNotNil(vote)
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertEqual(vote?.reason, "Calendar: Standup")
    }

    func testEventBeforeStartDoesNotEmit() async {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let event = CalendarEventSnapshot(
            id: "ev-future",
            title: "Future",
            startDate: now.addingTimeInterval(3600),
            endDate: now.addingTimeInterval(3600 + 600),
            isAllDay: false,
            calendarID: "cal-1"
        )
        let (trigger, _, _, _) = makeFixture(events: [event], nowOverride: now)
        await trigger.pollOnce()

        // Allow a brief window; expect no vote.
        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        let vote = await task.value
        XCTAssertNil(vote)
    }

    func testLeadTimeBringsVoteOnEarly() async {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        // Event starts 5 min in future, leadTime=5 → should be active now
        let event = CalendarEventSnapshot(
            id: "ev-lead",
            title: "Lead",
            startDate: now.addingTimeInterval(5 * 60),
            endDate: now.addingTimeInterval(15 * 60),
            isAllDay: false,
            calendarID: "cal-1"
        )
        let (trigger, _, settings, _) = makeFixture(events: [event], nowOverride: now)
        settings.setInteger(5, for: .calendarTriggerLeadTimeMinutes)
        await trigger.pollOnce()

        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
    }

    func testTrailingTimeKeepsVoteOnAfterEnd() async {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        // Event ended 3 min ago; trailing=5 → still active
        let event = CalendarEventSnapshot(
            id: "ev-tail",
            title: "Wrap",
            startDate: now.addingTimeInterval(-30 * 60),
            endDate: now.addingTimeInterval(-3 * 60),
            isAllDay: false,
            calendarID: "cal-1"
        )
        let (trigger, _, settings, _) = makeFixture(events: [event], nowOverride: now)
        settings.setInteger(5, for: .calendarTriggerTrailingMinutes)
        await trigger.pollOnce()

        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
    }

    func testAllDayEventExcludedByDefault() async {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let event = CalendarEventSnapshot(
            id: "ev-allday",
            title: "OOO",
            startDate: now.addingTimeInterval(-3600),
            endDate: now.addingTimeInterval(3600 * 23),
            isAllDay: true,
            calendarID: "cal-1"
        )
        let (trigger, _, _, _) = makeFixture(events: [event], nowOverride: now)
        await trigger.pollOnce()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        let vote = await task.value
        XCTAssertNil(vote, "all-day event should be excluded by default")
    }

    func testCalendarIDFilterPassesOnlyMatching() async {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let work = CalendarEventSnapshot(
            id: "ev-work",
            title: "Work meet",
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(600),
            isAllDay: false,
            calendarID: "work"
        )
        let personal = CalendarEventSnapshot(
            id: "ev-personal",
            title: "Personal",
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(600),
            isAllDay: false,
            calendarID: "personal"
        )
        let (trigger, source, settings, _) = makeFixture(
            events: [work, personal],
            nowOverride: now
        )
        settings.calendarTriggerCalendarIDs = ["work"]

        await trigger.pollOnce()

        XCTAssertEqual(source.lastQueryCalendarIDs, ["work"])
        // Only the work event should produce an ON vote.
        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.reason, "Calendar: Work meet")
    }

    func testEventEndingTransitionsToOff() async {
        var now = Date(timeIntervalSince1970: 1_750_000_000)
        let event = CalendarEventSnapshot(
            id: "ev-trans",
            title: "Brief",
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(60),
            isAllDay: false,
            calendarID: "cal-1"
        )
        var nowRef = now
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .calendarTriggerEnabled)
        let source = MockCalendarSource(events: [event])
        let trigger = CalendarTrigger(
            settings: settings,
            source: source,
            pollInterval: 60,
            now: { nowRef }
        )
        await trigger.pollOnce()
        // Move time past event + trailing
        now = now.addingTimeInterval(120)
        nowRef = now
        await trigger.pollOnce()

        var votes: [TriggerVote] = []
        var iterator = trigger.voteStream.makeAsyncIterator()
        if let v1 = await iterator.next() { votes.append(v1) }
        if let v2 = await iterator.next() { votes.append(v2) }

        XCTAssertEqual(votes.count, 2)
        XCTAssertEqual(votes[0].wantsAwake, true)
        XCTAssertEqual(votes[1].wantsAwake, false)
    }

    func testDoesNothingWhenDisabled() async {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let event = CalendarEventSnapshot(
            id: "ev",
            title: "x",
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(600),
            isAllDay: false,
            calendarID: "cal-1"
        )
        let settings = InMemorySettingsStore()
        // .calendarTriggerEnabled left false
        let source = MockCalendarSource(events: [event])
        let trigger = CalendarTrigger(
            settings: settings,
            source: source,
            pollInterval: 60,
            now: { now }
        )
        await trigger.pollOnce()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { let _v = await task.value; XCTAssertNil(_v) }
    }

    func testRequestPermissionIfNeededHonorsStatus() async {
        let settings = InMemorySettingsStore()

        // .granted → true without asking
        let granted = MockCalendarSource(permissionStatus: .granted)
        let g = CalendarTrigger(settings: settings, source: granted)
        let r1 = await g.requestPermissionIfNeeded()
        XCTAssertTrue(r1)
        XCTAssertEqual(granted.requestAccessCalls, 0)

        // .denied → false without asking
        let denied = MockCalendarSource(permissionStatus: .denied)
        let d = CalendarTrigger(settings: settings, source: denied)
        let r2 = await d.requestPermissionIfNeeded()
        XCTAssertFalse(r2)
        XCTAssertEqual(denied.requestAccessCalls, 0)

        // .notDetermined → asks
        let nd = MockCalendarSource(permissionStatus: .notDetermined)
        let n = CalendarTrigger(settings: settings, source: nd)
        let r3 = await n.requestPermissionIfNeeded()
        XCTAssertTrue(r3)
        XCTAssertEqual(nd.requestAccessCalls, 1)
    }

    func testIsEnabledSetterPersists() {
        let settings = InMemorySettingsStore()
        let trigger = CalendarTrigger(settings: settings, source: MockCalendarSource())
        XCTAssertFalse(trigger.isEnabled)
        trigger.isEnabled = true
        XCTAssertTrue(trigger.isEnabled)
        XCTAssertTrue(settings.bool(.calendarTriggerEnabled, default: false))
    }

    func testPermissionStatusReflectsSource() {
        let settings = InMemorySettingsStore()
        let source = MockCalendarSource(permissionStatus: .denied)
        let trigger = CalendarTrigger(settings: settings, source: source)
        XCTAssertEqual(trigger.permissionStatus, .denied)
        source.permissionStatus = .granted
        XCTAssertEqual(trigger.permissionStatus, .granted)
    }

    func testStartPollsAndStopCancels() async throws {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let event = CalendarEventSnapshot(
            id: "ev-start",
            title: "Standup",
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(600),
            isAllDay: false,
            calendarID: "cal-1"
        )
        let (trigger, _, _, _) = makeFixture(events: [event], nowOverride: now)
        await trigger.start()

        // start() schedules an immediate pollOnce; wait briefly for it to run.
        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertEqual(vote?.reason, "Calendar: Standup")

        // Second start() is a no-op while the poll task is running.
        await trigger.start()

        trigger.stop()
        // S7.11: stop() no longer finishes the AsyncStream (the coordinator
        // cancels its consumer task on stop and recreates it on start; the
        // stream lives for the trigger's lifetime so Toggle OFF→ON cycles
        // work). To verify nothing else is yielded after stop, drain with a
        // bounded timeout.
        let nextProbe = Task { @MainActor () -> TriggerVote? in
            await it.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        nextProbe.cancel()
        let after = await nextProbe.value
        XCTAssertNil(after, "no further votes should be yielded after stop()")
    }

    // MARK: - V2-04 EKCalendar picker

    func testAvailableCalendarsEmptyWhenPermissionNotGranted() {
        let (trigger, source, _, _) = makeFixture(permissionStatus: .denied)
        source.calendars = [
            CalendarSummary(id: "a", title: "Work", red: 1, green: 0, blue: 0, alpha: 1, sourceTitle: "iCloud")
        ]
        XCTAssertEqual(trigger.availableCalendars(), [])
    }

    func testAvailableCalendarsReturnsSourceCalendarsWhenGranted() {
        let work = CalendarSummary(id: "a", title: "Work", red: 1, green: 0, blue: 0, alpha: 1, sourceTitle: "iCloud")
        let personal = CalendarSummary(id: "b", title: "Personal", red: 0, green: 1, blue: 0, alpha: 1, sourceTitle: "iCloud")
        let (trigger, source, _, _) = makeFixture()
        source.calendars = [work, personal]
        XCTAssertEqual(trigger.availableCalendars(), [work, personal])
    }

    func testCalendarSummaryIsIdentifiableByID() {
        let summary = CalendarSummary(id: "x", title: "Hello", red: 0.5, green: 0.5, blue: 0.5, alpha: 1, sourceTitle: "Local")
        XCTAssertEqual(summary.id, "x")
    }

    func testCalendarSummariesEquatableForChangeDetection() {
        let a = CalendarSummary(id: "x", title: "Hello", red: 0.5, green: 0.5, blue: 0.5, alpha: 1, sourceTitle: "Local")
        let b = CalendarSummary(id: "x", title: "Hello", red: 0.5, green: 0.5, blue: 0.5, alpha: 1, sourceTitle: "Local")
        XCTAssertEqual(a, b)
        let c = CalendarSummary(id: "x", title: "Hello", red: 0.5, green: 0.5, blue: 0.5, alpha: 1, sourceTitle: "iCloud")
        XCTAssertNotEqual(a, c)
    }

    func testEmptyCalendarIDListMeansAllCalendarsPolled() async {
        // Sanity check that the existing data path treats `[]` as
        // "all granted calendars" — V2-04 picker UI relies on this.
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let event = CalendarEventSnapshot(
            id: "e",
            title: "Standup",
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(600),
            isAllDay: false,
            calendarID: "any-calendar"
        )
        let (trigger, source, settings, _) = makeFixture(events: [event], nowOverride: now)
        settings.calendarTriggerCalendarIDs = [] // empty = all
        await trigger.pollOnce()
        // The mock records the calendarIDs used in the last query —
        // empty array means "all granted calendars" was the request.
        XCTAssertEqual(source.lastQueryCalendarIDs, [])
        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
    }

    func testCalendarSettingsTypedSetters() {
        let settings = InMemorySettingsStore()
        settings.calendarTriggerCalendarIDs = ["work", "personal"]
        XCTAssertEqual(settings.calendarTriggerCalendarIDs, ["work", "personal"])

        settings.calendarTriggerExcludeAllDay = false
        XCTAssertFalse(settings.calendarTriggerExcludeAllDay)
        settings.calendarTriggerExcludeAllDay = true
        XCTAssertTrue(settings.calendarTriggerExcludeAllDay)

        settings.calendarTriggerLeadTimeMinutes = 7
        XCTAssertEqual(settings.calendarTriggerLeadTimeMinutes, 7)
        // Out-of-range values are clamped on write.
        settings.calendarTriggerLeadTimeMinutes = 99
        XCTAssertEqual(settings.calendarTriggerLeadTimeMinutes, 15)
        settings.calendarTriggerLeadTimeMinutes = -3
        XCTAssertEqual(settings.calendarTriggerLeadTimeMinutes, 0)

        settings.calendarTriggerTrailingMinutes = 4
        XCTAssertEqual(settings.calendarTriggerTrailingMinutes, 4)
        settings.calendarTriggerTrailingMinutes = 200
        XCTAssertEqual(settings.calendarTriggerTrailingMinutes, 15)
    }
}
