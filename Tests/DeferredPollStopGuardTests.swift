import XCTest
@testable import Latte

/// Regression coverage for the post-stop spurious ON vote.
///
/// `reevaluateWatched()` / `reemitCurrentVote()` enqueue a `Task { … }` whose
/// body runs on a LATER main-actor turn. A `stop()` can land between the
/// enqueue and the run (e.g. a pause-lift reevaluate racing a user toggle-off).
/// Both methods now route their deferred poll through `pollOnceIfRunning()`,
/// which re-checks `pollTask` at execution time so a stale poll cannot emit a
/// vote for an already-stopped trigger.
///
/// These tests drive the guard deterministically: with the trigger NOT running
/// (`pollTask == nil`), `pollOnceIfRunning()` must be a no-op even though the
/// underlying condition matches — while a direct `pollOnce()` on the very same
/// fixture DOES emit, proving the fixture is genuinely "active" and the gate is
/// the only thing suppressing the vote.
@MainActor
final class DeferredPollStopGuardTests: XCTestCase {

    // MARK: - ScheduleTrigger

    private func makeMatchingScheduleTrigger() -> ScheduleTrigger {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .scheduleTriggerEnabled)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 27 // a Monday
        comps.hour = 12; comps.minute = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        let now = cal.date(from: comps)!
        settings.scheduleTriggerEntries = [
            ScheduleEntry(
                weekdays: [.monday],
                start: TimeOfDay(hour: 9, minute: 0),
                end: TimeOfDay(hour: 18, minute: 0),
                label: "Workday"
            )
        ]
        return ScheduleTrigger(settings: settings, now: { now }, calendar: cal)
    }

    func testSchedulePollOnceIfRunningIsNoOpWhenStopped() async {
        let trigger = makeMatchingScheduleTrigger()
        // Not started → pollTask == nil. A deferred poll must NOT emit.
        await trigger.pollOnceIfRunning()

        let probe = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        probe.cancel()
        let vote = await probe.value
        XCTAssertNil(vote, "a deferred poll for a stopped ScheduleTrigger must not emit a spurious vote")
    }

    /// The race the S50 fix actually targeted, end-to-end: the deferred Task
    /// is ENQUEUED while the trigger is running (the enqueue-time check
    /// passes), then `stop()` lands before the body executes. `stop()`
    /// clears `activeEntryID`, so an unguarded stale `pollOnce()` would
    /// re-match the entry with `prev == nil` and emit a spurious ON — the
    /// execution-time `pollTask` re-check is the only suppressor. (S51
    /// audit: the test above only pins the static already-stopped path.)
    func testScheduleDeferredPollEnqueuedBeforeStopDoesNotEmit() async {
        let trigger = makeMatchingScheduleTrigger()
        await trigger.start()
        var initialIterator = trigger.voteStream.makeAsyncIterator()
        let initial = await initialIterator.next()
        XCTAssertEqual(initial?.wantsAwake, true, "fixture must be inside the window")

        trigger.reevaluateWatched() // enqueued while running — guard passes
        trigger.stop()              // lands before the deferred body runs
        for _ in 0..<20 { await Task.yield() } // let the stale poll execute

        let probe = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        probe.cancel()
        let vote = await probe.value
        XCTAssertNil(vote, "a deferred poll enqueued before stop() must not emit after stop()")
    }

    func testScheduleDirectPollEmitsForSameFixture() async {
        // Contrast: the unguarded direct seam DOES emit, proving the fixture is
        // genuinely active and the guard above is the only suppressor.
        let trigger = makeMatchingScheduleTrigger()
        await trigger.pollOnce()
        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.wantsAwake, true, "direct pollOnce should emit ON for a matching schedule window")
    }

    // MARK: - CalendarTrigger

    private func makeMatchingCalendarTrigger() -> CalendarTrigger {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .calendarTriggerEnabled)
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let event = CalendarEventSnapshot(
            id: "ev-active",
            title: "Standup",
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(600),
            isAllDay: false,
            calendarID: "cal-1"
        )
        let source = MockCalendarSource(permissionStatus: .granted, events: [event])
        return CalendarTrigger(settings: settings, source: source, pollInterval: 60, now: { now })
    }

    func testCalendarPollOnceIfRunningIsNoOpWhenStopped() async {
        let trigger = makeMatchingCalendarTrigger()
        await trigger.pollOnceIfRunning()

        let probe = Task { @MainActor () -> TriggerVote? in
            var it = trigger.voteStream.makeAsyncIterator()
            return await it.next()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        probe.cancel()
        let vote = await probe.value
        XCTAssertNil(vote, "a deferred poll for a stopped CalendarTrigger must not emit a spurious vote")
    }

    func testCalendarDirectPollEmitsForSameFixture() async {
        let trigger = makeMatchingCalendarTrigger()
        await trigger.pollOnce()
        var it = trigger.voteStream.makeAsyncIterator()
        let vote = await it.next()
        XCTAssertEqual(vote?.wantsAwake, true, "direct pollOnce should emit ON for an active calendar event")
    }
}
