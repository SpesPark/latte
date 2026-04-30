import XCTest
@testable import Latte

/// Filter helper for the per-trigger Picker in ActivityTab (C-3 deferred B).
final class ActivityFilterTests: XCTestCase {

    private func entry(_ triggerId: String, _ kind: ActivityLogEntry.Kind = .on) -> ActivityLogEntry {
        ActivityLogEntry(
            timestamp: .now,
            triggerId: triggerId,
            kind: kind,
            reasonCode: kind == .on ? .voteOn : .voteOff
        )
    }

    func testAllPassesEverythingThrough() {
        let entries = [entry("wifi"), entry("calendar"), entry("schedule")]
        let filtered = ActivityFilter.all.apply(to: entries)
        XCTAssertEqual(filtered.count, 3)
    }

    func testOnlyKeepsMatchingTriggerId() {
        let entries = [entry("wifi"), entry("calendar"), entry("wifi", .off)]
        let filtered = ActivityFilter.only("wifi").apply(to: entries)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.triggerId == "wifi" })
    }

    func testOnlyWithUnknownTriggerIdReturnsEmpty() {
        let entries = [entry("wifi"), entry("calendar")]
        let filtered = ActivityFilter.only("focus").apply(to: entries)
        XCTAssertTrue(filtered.isEmpty)
    }

    func testTriggerIdsObservedReturnsSortedUniqueIds() {
        let entries = [
            entry("wifi"), entry("calendar"), entry("wifi", .off),
            entry("schedule"), entry("calendar")
        ]
        let observed = ActivityFilter.triggerIdsObserved(in: entries)
        XCTAssertEqual(observed, ["calendar", "schedule", "wifi"])
    }

    func testEquatableForPickerSelection() {
        // Picker requires Hashable selection — also exercises Equatable.
        XCTAssertEqual(ActivityFilter.all, ActivityFilter.all)
        XCTAssertEqual(ActivityFilter.only("wifi"), ActivityFilter.only("wifi"))
        XCTAssertNotEqual(ActivityFilter.only("wifi"), ActivityFilter.only("calendar"))
        XCTAssertNotEqual(ActivityFilter.all, ActivityFilter.only("wifi"))
    }
}
