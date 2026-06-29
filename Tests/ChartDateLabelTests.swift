import XCTest
@testable import Latte

/// Pure-helper tests for the daily-totals chart x-axis label (B3).
///
/// The label formerly used `en_US_POSIX` + a hardcoded `"M/d"` pattern, which
/// forced US month-first ordering in all 11 shipped locales. `ChartDateLabel`
/// derives the field order/separators from the supplied locale instead. These
/// tests pin that the ordering actually follows the locale.
final class ChartDateLabelTests: XCTestCase {

    /// Noon UTC of a known day — same anchor convention as `DailyTotalTests`.
    /// Day/month are unambiguous (15 ≠ 1) so field order is observable.
    private let now: Date = Date(timeIntervalSince1970: 1_800_043_200)   // 2027-01-15T12:00:00Z

    /// Build the formatter, but pin its time zone to UTC so the rendered day
    /// matches the fixture regardless of the CI host's zone. Production uses
    /// the current zone (correct for on-screen display); only field *ordering*
    /// is under test here.
    private func label(_ localeID: String) -> String {
        let f = ChartDateLabel.makeFormatter(locale: Locale(identifier: localeID))
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: now)
    }

    func testUSEnglishIsMonthFirst() {
        XCTAssertEqual(label("en_US"), "1/15")
    }

    func testBritishEnglishIsDayFirst() {
        XCTAssertEqual(label("en_GB"), "15/01")
    }

    func testGermanUsesDayFirstWithDotSeparators() {
        XCTAssertEqual(label("de_DE"), "15.1.")
    }

    func testKoreanDiffersFromUSOrdering() {
        // The B3 bug: every locale rendered identical en_US_POSIX output.
        // ko_KR must not collapse to the US form.
        XCTAssertNotEqual(label("ko_KR"), label("en_US"),
                          "chart labels must localize, not hardcode US ordering")
    }
}
