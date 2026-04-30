import XCTest
@testable import Latte

final class QuickPresetTests: XCTestCase {

    /// UTC-anchored calendar so `Date(timeIntervalSince1970: ...)` math
    /// is reproducible regardless of CI timezone.
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    /// 2027-01-15T09:00:00Z (Friday morning) — built via UTC calendar so
    /// the epoch arithmetic doesn't drift on different system timezones.
    private var nineAM: Date {
        var components = DateComponents()
        components.year = 2027; components.month = 1; components.day = 15
        components.hour = 9; components.minute = 0; components.second = 0
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func testUntil5PMFromMorningReturnsHoursLeftToday() {
        let mins = QuickPreset.until5PM.minutes(from: nineAM, calendar: utcCalendar)
        XCTAssertEqual(mins, 8 * 60, "9 AM → 5 PM is 8 hours = 480 min")
    }

    func testUntil5PMAfter5PMRollsToTomorrow() {
        // 6 PM today (UTC) → next 5 PM is 23 hours away.
        let sixPM = nineAM.addingTimeInterval(9 * 3600)
        let mins = QuickPreset.until5PM.minutes(from: sixPM, calendar: utcCalendar)
        XCTAssertEqual(mins, 23 * 60, "6 PM → next 5 PM = 23h tomorrow")
    }

    func testUntil11PMFromAfternoon() {
        let twoPM = nineAM.addingTimeInterval(5 * 3600)
        let mins = QuickPreset.until11PM.minutes(from: twoPM, calendar: utcCalendar)
        XCTAssertEqual(mins, 9 * 60, "2 PM → 11 PM = 9h = 540 min")
    }

    func testUntilMidnightFromBeforeMidnight() {
        // 11:55 PM → midnight = 5 minutes.
        let elevenFiftyFive = nineAM.addingTimeInterval(14 * 3600 + 55 * 60)
        let mins = QuickPreset.untilMidnight.minutes(from: elevenFiftyFive, calendar: utcCalendar)
        XCTAssertEqual(mins, 5)
    }

    func testUntilMidnightFromMidday() {
        let noon = nineAM.addingTimeInterval(3 * 3600)
        let mins = QuickPreset.untilMidnight.minutes(from: noon, calendar: utcCalendar)
        XCTAssertEqual(mins, 12 * 60, "noon → midnight = 12h = 720 min")
    }

    func testUntil11PMAt11PMSharpRollsToTomorrow() {
        // Exactly at the target — nextOccurrence must NOT return now (would
        // give 0 min and a misleading "instant turn-off"). The min(1) clamp
        // also covers this, but the spec is "next occurrence" which means
        // tomorrow when the target has already arrived.
        let elevenPM = nineAM.addingTimeInterval(14 * 3600)
        let mins = QuickPreset.until11PM.minutes(from: elevenPM, calendar: utcCalendar)
        XCTAssertEqual(mins, 24 * 60, "11 PM sharp → next 11 PM is 24h away")
    }

    func testMinutesNeverReturnsZeroOrNegative() {
        // 4:59:59 PM → until 5 PM: 1 second away rounds to 0 min; the
        // clamp must bump it to 1 so a 0-min "instant deactivation"
        // never reaches the FSM.
        let almostFivePM = nineAM.addingTimeInterval(8 * 3600 - 1)
        let mins = QuickPreset.until5PM.minutes(from: almostFivePM, calendar: utcCalendar)
        XCTAssertGreaterThanOrEqual(mins, 1)
    }

    func testAllCasesHaveNonEmptyLabels() {
        for preset in QuickPreset.allCases {
            XCTAssertFalse(preset.label.isEmpty, "preset \(preset) label must be non-empty")
        }
    }

    func testRawValueRoundTrip() {
        for preset in QuickPreset.allCases {
            XCTAssertEqual(QuickPreset(rawValue: preset.rawValue), preset)
        }
    }
}
