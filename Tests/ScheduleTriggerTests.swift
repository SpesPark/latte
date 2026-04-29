import XCTest
@testable import Latte

@MainActor
final class ScheduleTriggerTests: XCTestCase {

    // MARK: - GMT calendar — fixes weekday/hour/minute interpretation across CI envs.

    private var gmt: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    /// Fixed reference: 2026-04-27 (Monday) 10:00:00 UTC.
    /// `dateComponents(.weekday) → 2 (Monday)`.
    private func mondayAt(hour: Int, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 27
        comps.hour = hour; comps.minute = minute
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        return gmt.date(from: comps)!
    }

    // MARK: - TimeOfDay

    func testTimeOfDayClampsOutOfRange() {
        XCTAssertEqual(TimeOfDay(hour: 99, minute: 99).hour, 23)
        XCTAssertEqual(TimeOfDay(hour: 99, minute: 99).minute, 59)
        XCTAssertEqual(TimeOfDay(hour: -5, minute: -1).hour, 0)
        XCTAssertEqual(TimeOfDay(hour: -5, minute: -1).minute, 0)
    }

    func testTimeOfDayComparable() {
        XCTAssertLessThan(TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 9, minute: 30))
        XCTAssertLessThan(TimeOfDay(hour: 9, minute: 30), TimeOfDay(hour: 10, minute: 0))
    }

    func testTimeOfDayTotalMinutes() {
        XCTAssertEqual(TimeOfDay(hour: 0, minute: 0).totalMinutes, 0)
        XCTAssertEqual(TimeOfDay(hour: 9, minute: 30).totalMinutes, 570)
        XCTAssertEqual(TimeOfDay(hour: 23, minute: 59).totalMinutes, 1439)
    }

    // MARK: - ScheduleEntry.contains — same-day windows

    func testSameDayWindowMatchesInsideRange() {
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)
        )
        XCTAssertTrue(entry.contains(mondayAt(hour: 9, minute: 0), in: gmt))
        XCTAssertTrue(entry.contains(mondayAt(hour: 12, minute: 30), in: gmt))
        XCTAssertTrue(entry.contains(mondayAt(hour: 17, minute: 59), in: gmt))
    }

    func testSameDayWindowExcludesEnd() {
        // Half-open [start, end) — end is excluded.
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)
        )
        XCTAssertFalse(entry.contains(mondayAt(hour: 18, minute: 0), in: gmt))
        XCTAssertFalse(entry.contains(mondayAt(hour: 18, minute: 30), in: gmt))
        XCTAssertFalse(entry.contains(mondayAt(hour: 8, minute: 59), in: gmt))
    }

    func testSameDayWindowRejectsOtherWeekday() {
        // Tuesday 2026-04-28
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)
        )
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 28
        comps.hour = 12; comps.minute = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        let tuesday = gmt.date(from: comps)!
        XCTAssertFalse(entry.contains(tuesday, in: gmt))
    }

    // MARK: - ScheduleEntry.contains — midnight crossing

    func testMidnightCrossingLateHalfMatchesStartingDay() {
        // Mon 22:00 → Tue 02:00 entry.
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 2, minute: 0)
        )
        // Monday 23:30 — late half (within [22:00, 24:00) on Mon).
        XCTAssertTrue(entry.contains(mondayAt(hour: 23, minute: 30), in: gmt))
    }

    func testMidnightCrossingEarlyHalfMatchesNextDay() {
        // Mon 22:00 → Tue 02:00 entry.
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 2, minute: 0)
        )
        // Tuesday 01:30 — early half (yesterday=Mon, which is in weekdays).
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 28
        comps.hour = 1; comps.minute = 30
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        let tueEarly = gmt.date(from: comps)!
        XCTAssertTrue(entry.contains(tueEarly, in: gmt))
    }

    func testMidnightCrossingExcludesNextDayLateHalf() {
        // Mon 22:00 → Tue 02:00 entry.
        // Tuesday 22:30 should NOT match (Tue not in weekdays, late half belongs to Tue's window only).
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 2, minute: 0)
        )
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 28
        comps.hour = 22; comps.minute = 30
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        let tueLate = gmt.date(from: comps)!
        XCTAssertFalse(entry.contains(tueLate, in: gmt))
    }

    func testMidnightCrossingSundayEarlyHalfWrapsBackToSaturday() {
        // Sat 22:00 → Sun 02:00 entry.
        let entry = ScheduleEntry(
            weekdays: [.saturday],
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 2, minute: 0)
        )
        // Sunday 2026-04-26 01:30 — should match (yesterday=Sat).
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 26
        comps.hour = 1; comps.minute = 30
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        let sunEarly = gmt.date(from: comps)!
        XCTAssertTrue(entry.contains(sunEarly, in: gmt))
    }

    // MARK: - ScheduleEntry.contains — edge cases

    func testZeroLengthWindowNeverMatches() {
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 9, minute: 0)
        )
        XCTAssertFalse(entry.contains(mondayAt(hour: 9, minute: 0), in: gmt))
    }

    func testEmptyWeekdaySetNeverMatches() {
        let entry = ScheduleEntry(
            weekdays: [],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)
        )
        XCTAssertFalse(entry.contains(mondayAt(hour: 12, minute: 0), in: gmt))
    }

    func testDisabledEntryNeverMatches() {
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0),
            isEnabled: false
        )
        XCTAssertFalse(entry.contains(mondayAt(hour: 12, minute: 0), in: gmt))
    }

    func testFullDayCoverage() {
        let entry = ScheduleEntry(
            weekdays: Set(Weekday.allCases),
            start: TimeOfDay(hour: 0, minute: 0),
            end: TimeOfDay(hour: 23, minute: 59)
        )
        XCTAssertTrue(entry.contains(mondayAt(hour: 0, minute: 0), in: gmt))
        XCTAssertTrue(entry.contains(mondayAt(hour: 23, minute: 58), in: gmt))
        // Excluded only the very last minute of the day.
        XCTAssertFalse(entry.contains(mondayAt(hour: 23, minute: 59), in: gmt))
    }

    // MARK: - Codable round-trip

    func testScheduleEntryCodableRoundTrip() throws {
        let original = ScheduleEntry(
            weekdays: [.monday, .wednesday, .friday],
            start: TimeOfDay(hour: 9, minute: 30),
            end: TimeOfDay(hour: 17, minute: 45),
            label: "Work hours",
            isEnabled: true
        )
        let encoded = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([ScheduleEntry].self, from: encoded)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].id, original.id)
        XCTAssertEqual(decoded[0].weekdays, original.weekdays)
        XCTAssertEqual(decoded[0].start, original.start)
        XCTAssertEqual(decoded[0].end, original.end)
        XCTAssertEqual(decoded[0].label, original.label)
        XCTAssertEqual(decoded[0].isEnabled, original.isEnabled)
    }

    // MARK: - SettingsStore extension

    func testSettingsStoreScheduleEntriesRoundTrip() {
        let settings = InMemorySettingsStore()
        XCTAssertEqual(settings.scheduleTriggerEntries, [])

        let entries = [
            ScheduleEntry(
                weekdays: [.monday, .tuesday],
                start: TimeOfDay(hour: 9, minute: 0),
                end: TimeOfDay(hour: 18, minute: 0),
                label: "Workday"
            )
        ]
        settings.scheduleTriggerEntries = entries
        XCTAssertEqual(settings.scheduleTriggerEntries.count, 1)
        XCTAssertEqual(settings.scheduleTriggerEntries[0].label, "Workday")
        XCTAssertEqual(settings.scheduleTriggerEntries[0].weekdays, [.monday, .tuesday])
    }

    func testSettingsStoreScheduleEntriesEmptyOnCorruption() {
        let settings = InMemorySettingsStore()
        settings.setData("not valid json".data(using: .utf8), for: .scheduleTriggerEntries)
        XCTAssertEqual(settings.scheduleTriggerEntries, [])
    }

    // MARK: - ScheduleTrigger

    private func makeTrigger(
        entries: [ScheduleEntry] = [],
        enabled: Bool = true,
        nowOverride: Date? = nil
    ) -> (ScheduleTrigger, InMemorySettingsStore, Date) {
        let settings = InMemorySettingsStore()
        settings.setBool(enabled, for: .scheduleTriggerEnabled)
        settings.scheduleTriggerEntries = entries
        let now = nowOverride ?? mondayAt(hour: 12)
        let trigger = ScheduleTrigger(
            settings: settings,
            pollInterval: 30,
            now: { now },
            calendar: gmt
        )
        return (trigger, settings, now)
    }

    func testTriggerEmitsOnVoteWhenInsideWindow() async {
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0),
            label: "Workday"
        )
        let (trigger, _, _) = makeTrigger(entries: [entry])
        await trigger.pollOnce()

        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)
        XCTAssertEqual(vote?.reason, "Schedule: Workday")
    }

    func testTriggerEmitsReasonWithTimeWhenLabelEmpty() async {
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)
        )
        let (trigger, _, _) = makeTrigger(entries: [entry])
        await trigger.pollOnce()
        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.reason, "Schedule: 09:00–18:00")
    }

    func testTriggerEmitsNothingOutsideWindow() async {
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)
        )
        let (trigger, _, _) = makeTrigger(
            entries: [entry],
            nowOverride: mondayAt(hour: 20)
        )
        await trigger.pollOnce()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        let vote = await task.value
        XCTAssertNil(vote)
    }

    func testTriggerTransitionsOnToOff() async {
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)
        )
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .scheduleTriggerEnabled)
        settings.scheduleTriggerEntries = [entry]

        // Mutable-now via a class box so the @Sendable closure stays Sendable
        // while letting us advance time between polls without recreating the
        // trigger (which would discard `activeEntryID` state).
        final class Clock: @unchecked Sendable {
            var current: Date
            init(_ d: Date) { current = d }
        }
        let clock = Clock(mondayAt(hour: 12))
        let trigger = ScheduleTrigger(
            settings: settings,
            pollInterval: 30,
            now: { clock.current },
            calendar: gmt
        )
        await trigger.pollOnce()
        // Move past window
        clock.current = mondayAt(hour: 19)
        await trigger.pollOnce()

        var votes: [TriggerVote] = []
        var iterator = trigger.voteStream.makeAsyncIterator()
        if let v1 = await iterator.next() { votes.append(v1) }
        if let v2 = await iterator.next() { votes.append(v2) }

        XCTAssertEqual(votes.count, 2)
        XCTAssertEqual(votes[0].wantsAwake, true)
        XCTAssertEqual(votes[1].wantsAwake, false)
        XCTAssertEqual(votes[1].reason, "Schedule: outside all windows")
    }

    func testTriggerDoesNotReEmitOnRepeatedPolls() async {
        // Already-active entry — second pollOnce while still in window should not emit.
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)
        )
        let (trigger, _, _) = makeTrigger(entries: [entry])
        await trigger.pollOnce()
        await trigger.pollOnce()
        await trigger.pollOnce()

        // Drain — there should be exactly one ON vote and nothing more.
        var iterator = trigger.voteStream.makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first?.wantsAwake, true)

        let task = Task { @MainActor () -> TriggerVote? in
            await iterator.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        let extra = await task.value
        XCTAssertNil(extra)
    }

    func testTriggerSwitchesBetweenOverlappingEntries() async {
        // Two entries — first matches Mon, second matches Mon (same window),
        // first wins by stable iteration order. After we delete the first
        // and the second is the only match, we expect a transition vote with
        // the new reason.
        let first = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0),
            label: "Primary"
        )
        let second = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0),
            label: "Secondary"
        )
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .scheduleTriggerEnabled)
        settings.scheduleTriggerEntries = [first, second]
        let fixedNow = mondayAt(hour: 12)
        let trigger = ScheduleTrigger(
            settings: settings,
            now: { fixedNow },
            calendar: gmt
        )
        await trigger.pollOnce()
        // Remove the first (primary) entry; secondary becomes the match.
        settings.scheduleTriggerEntries = [second]
        await trigger.pollOnce()

        var votes: [TriggerVote] = []
        var iterator = trigger.voteStream.makeAsyncIterator()
        if let v1 = await iterator.next() { votes.append(v1) }
        if let v2 = await iterator.next() { votes.append(v2) }

        XCTAssertEqual(votes.count, 2)
        XCTAssertEqual(votes[0].reason, "Schedule: Primary")
        XCTAssertEqual(votes[1].reason, "Schedule: Secondary")
    }

    func testTriggerDoesNothingWhenDisabled() async {
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)
        )
        let (trigger, _, _) = makeTrigger(entries: [entry], enabled: false)
        await trigger.pollOnce()

        let task = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        let vote = await task.value
        XCTAssertNil(vote)
    }

    func testTriggerStartPollsAndStopCancels() async throws {
        let entry = ScheduleEntry(
            weekdays: [.monday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)
        )
        let (trigger, _, _) = makeTrigger(entries: [entry])
        await trigger.start()

        var iterator = trigger.voteStream.makeAsyncIterator()
        let vote = await iterator.next()
        XCTAssertEqual(vote?.wantsAwake, true)

        // Second start — no-op.
        await trigger.start()

        trigger.stop()
        // Stop must not finish the AsyncStream (S7.11 invariant).
        let probe = Task { @MainActor () -> TriggerVote? in
            await iterator.next()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        probe.cancel()
        let after = await probe.value
        XCTAssertNil(after)
    }

    func testTriggerIsEnabledSetterPersists() {
        let settings = InMemorySettingsStore()
        let trigger = ScheduleTrigger(settings: settings)
        XCTAssertFalse(trigger.isEnabled)
        trigger.isEnabled = true
        XCTAssertTrue(trigger.isEnabled)
        XCTAssertTrue(settings.bool(.scheduleTriggerEnabled, default: false))
    }

    func testTriggerPermissionStatusIsNotRequired() {
        let trigger = ScheduleTrigger(settings: InMemorySettingsStore())
        XCTAssertEqual(trigger.permissionStatus, .notRequired)
        XCTAssertFalse(trigger.requiresPermission)
    }

    func testTriggerDescribesItself() {
        let trigger = ScheduleTrigger(settings: InMemorySettingsStore())
        XCTAssertEqual(trigger.id, "schedule")
        XCTAssertEqual(trigger.displayName, "Schedule")
        XCTAssertEqual(trigger.symbol, "clock")
    }
}
