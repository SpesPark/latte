import XCTest
@testable import Latte

/// Pure-helper tests for the multi-day comparison chart (C-3 deferred E).
final class DailyTotalTests: XCTestCase {

    /// Anchor `now` at noon UTC of a known day so per-day calendar math is
    /// reproducible regardless of CI timezone.
    private let now: Date = Date(timeIntervalSince1970: 1_800_043_200)   // 2027-01-15T12:00:00Z

    private func entry(_ triggerId: String, _ kind: ActivityLogEntry.Kind, at offsetSeconds: TimeInterval) -> ActivityLogEntry {
        ActivityLogEntry(
            timestamp: now.addingTimeInterval(offsetSeconds),
            triggerId: triggerId,
            kind: kind,
            reasonCode: kind == .on ? .voteOn : .voteOff
        )
    }

    func testEmptyEntriesProducesAllZeroDays() {
        let totals = DailyTotal.compute(from: [], days: 7, now: now)
        XCTAssertEqual(totals.count, 7)
        XCTAssertTrue(totals.allSatisfy { $0.awakeMinutes == 0 })
    }

    func testSingleHourSegmentTodayYields60Minutes() {
        // Today: ON 1h ago → OFF now.
        let entries = [
            entry("wifi", .on, at: -3600),
            entry("wifi", .off, at: 0)
        ]
        let totals = DailyTotal.compute(from: entries, days: 7, now: now)
        // dayOffset=0 corresponds to today (most-recent slot).
        let today = totals.first { $0.dayOffset == 0 }
        XCTAssertNotNil(today)
        XCTAssertEqual(today?.awakeMinutes ?? 0, 60, accuracy: 0.5)
    }

    func testParallelTriggersDoNotDoubleCount() {
        // Wifi ON 0..3600s; Calendar ON 1800..5400s — overlap 1800..3600.
        // Union = 5400s = 90 minutes (NOT 60+60 = 120).
        let entries = [
            entry("wifi", .on, at: -5400),
            entry("wifi", .off, at: -1800),
            entry("calendar", .on, at: -3600),
            entry("calendar", .off, at: 0)
        ]
        let totals = DailyTotal.compute(from: entries, days: 1, now: now)
        let today = totals.first { $0.dayOffset == 0 }
        XCTAssertEqual(today?.awakeMinutes ?? 0, 90, accuracy: 0.5,
                       "merge must union overlapping per-trigger segments")
    }

    func testDayCountMatchesRetentionWindow() {
        let totals30 = DailyTotal.compute(from: [], days: 30, now: now)
        XCTAssertEqual(totals30.count, 30)
        let totals1 = DailyTotal.compute(from: [], days: 1, now: now)
        XCTAssertEqual(totals1.count, 1)
    }

    func testDayOffsetZeroIsMostRecent() {
        // Layout convention: dayOffset = 0 is the rightmost (most recent)
        // bar so the eye reads left-to-right as "older → today".
        let totals = DailyTotal.compute(from: [], days: 5, now: now)
        let offsets = totals.map(\.dayOffset)
        XCTAssertEqual(offsets.min(), 0)
        XCTAssertEqual(offsets.max(), 4)
    }
}
