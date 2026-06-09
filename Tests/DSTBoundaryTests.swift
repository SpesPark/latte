import XCTest
@testable import Latte

/// DST / timezone-transition coverage (S51 audit: every time fixture in the
/// suite used a fixed-offset UTC calendar, so daylight-saving transitions —
/// the riskiest boundary for a wall-clock-driven app — were never exercised).
///
/// Uses America/New_York. In 2026: spring-forward Sunday 2026-03-08
/// (02:00 EST → 03:00 EDT, the 02:xx hour does not exist) and fall-back
/// Sunday 2026-11-01 (02:00 EDT → 01:00 EST, the 01:xx hour repeats).
final class DSTBoundaryTests: XCTestCase {

    private let nyCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }()

    /// Builds an absolute instant from UTC wall-clock components, so the
    /// fixtures stay unambiguous across both transition directions.
    private func utcInstant(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int
    ) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }

    // MARK: - RecurringQuickPreset across transitions

    /// "Until 9 AM" clicked at 01:00 EST on spring-forward night: the 02:xx
    /// hour vanishes, so 9 AM is only 7 real hours away. A wall-clock-naive
    /// implementation would compute 480 minutes and keep the Mac awake an
    /// hour past the target.
    func testPresetMinutesAcrossSpringForwardIsRealDuration() {
        let preset = RecurringQuickPreset(
            label: "Until 9 AM", targetHour: 9, targetMinute: 0,
            weekdays: [1, 2, 3, 4, 5, 6, 7]
        )
        let now = utcInstant(2026, 3, 8, 6, 0) // 01:00 EST
        XCTAssertEqual(preset.minutes(from: now, calendar: nyCalendar), 7 * 60)
    }

    /// Same preset at 00:30 EDT on fall-back night: the 01:xx hour repeats,
    /// so 9 AM is 9.5 real hours away (naive wall-clock math says 8.5).
    func testPresetMinutesAcrossFallBackIsRealDuration() {
        let preset = RecurringQuickPreset(
            label: "Until 9 AM", targetHour: 9, targetMinute: 0,
            weekdays: [1, 2, 3, 4, 5, 6, 7]
        )
        let now = utcInstant(2026, 11, 1, 4, 30) // 00:30 EDT
        XCTAssertEqual(preset.minutes(from: now, calendar: nyCalendar), 9 * 60 + 30)
    }

    /// A preset targeting 02:30 on the spring-forward day aims at a time
    /// that does not exist. Foundation resolves the components forward to
    /// 03:30 EDT — pin that the occurrence stays defined, in the future,
    /// and shifted by exactly the skipped hour.
    func testPresetNonexistentTargetResolvesForward() {
        let preset = RecurringQuickPreset(
            label: "Gap", targetHour: 2, targetMinute: 30,
            weekdays: [1, 2, 3, 4, 5, 6, 7]
        )
        let now = utcInstant(2026, 3, 8, 6, 0) // 01:00 EST
        let next = preset.nextOccurrence(after: now, calendar: nyCalendar)
        XCTAssertEqual(next, utcInstant(2026, 3, 8, 7, 30)) // 03:30 EDT
        XCTAssertEqual(preset.minutes(from: now, calendar: nyCalendar), 90)
    }

    // MARK: - ScheduleEntry across transitions

    /// Fall-back: a Sunday 01:00–03:00 window sees the 01:xx hour twice.
    /// `contains` is wall-clock — both passes through 01:30 are inside the
    /// window (the entry effectively covers an extra real hour). Pins the
    /// semantics so a future "fix" can't silently flip it.
    func testScheduleEntryContainsBothPassesOfRepeatedHour() {
        let entry = ScheduleEntry(
            weekdays: [.sunday],
            start: TimeOfDay(hour: 1, minute: 0),
            end: TimeOfDay(hour: 3, minute: 0)
        )
        let firstPass = utcInstant(2026, 11, 1, 5, 30)  // 01:30 EDT
        let secondPass = utcInstant(2026, 11, 1, 6, 30) // 01:30 EST
        XCTAssertTrue(entry.contains(firstPass, in: nyCalendar))
        XCTAssertTrue(entry.contains(secondPass, in: nyCalendar))
    }

    /// Spring-forward: a Sunday 01:00–02:30 window loses its tail — the
    /// clock jumps from 01:59 EST to 03:00 EDT, which is already past the
    /// 02:30 end. Wall-clock semantics: the window simply ends early.
    func testScheduleEntryWindowTailVanishesInSpringForwardGap() {
        let entry = ScheduleEntry(
            weekdays: [.sunday],
            start: TimeOfDay(hour: 1, minute: 0),
            end: TimeOfDay(hour: 2, minute: 30)
        )
        let inside = utcInstant(2026, 3, 8, 6, 30)      // 01:30 EST → inside
        let afterGap = utcInstant(2026, 3, 8, 7, 0)     // 03:00 EDT → outside
        XCTAssertTrue(entry.contains(inside, in: nyCalendar))
        XCTAssertFalse(entry.contains(afterGap, in: nyCalendar))
    }
}
