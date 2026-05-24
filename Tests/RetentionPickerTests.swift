import XCTest
@testable import Latte

/// S23 / P-issue-4: pure helper test for the Stepper → Picker UX migration.
/// `nearestPreset` maps any stored retention value (including legacy values
/// the user could have set via the old Stepper, e.g. 22) to one of the 6
/// preset windows so the Picker always renders a tag-matching selection.
@MainActor
final class RetentionPickerTests: XCTestCase {

    func testNearestPresetExactMatchReturnsItself() {
        for preset in RetentionPicker.presets {
            XCTAssertEqual(RetentionPicker.nearestPreset(to: preset), preset)
        }
    }

    func testNearestPresetMapsLegacyValueToClosest() {
        // 25 firmly closer to 30 than to 14.
        XCTAssertEqual(RetentionPicker.nearestPreset(to: 25), 30)
        // 4 is equidistant from 1 and 7 (|4-1|=3, |4-7|=3) → tiebreak
        // returns the smaller preset since `min(by:)` keeps the earlier
        // element when the comparator returns false on a tie.
        XCTAssertEqual(RetentionPicker.nearestPreset(to: 4), 1)
        // 5 is strictly closer to 7 than to 1.
        XCTAssertEqual(RetentionPicker.nearestPreset(to: 5), 7)
        // 45 ties between 30 and 60 → smaller preset wins (30).
        XCTAssertEqual(RetentionPicker.nearestPreset(to: 45), 30)
        // 80 is strictly closer to 90.
        XCTAssertEqual(RetentionPicker.nearestPreset(to: 80), 90)
    }

    func testNearestPresetClampsAboveAndBelow() {
        // Out-of-range values clamp to nearest endpoint.
        XCTAssertEqual(RetentionPicker.nearestPreset(to: 0), 1)
        XCTAssertEqual(RetentionPicker.nearestPreset(to: 999), 90)
        XCTAssertEqual(RetentionPicker.nearestPreset(to: -10), 1)
    }

    func testAllPresetsWithinRetentionDayRange() {
        for preset in RetentionPicker.presets {
            XCTAssertTrue(
                ActivityLogStore.retentionDayRange.contains(preset),
                "preset \(preset) must be within \(ActivityLogStore.retentionDayRange)"
            )
        }
    }

    func testLabelsAreNonEmpty() {
        for preset in RetentionPicker.presets {
            XCTAssertFalse(RetentionPicker.label(for: preset).isEmpty,
                           "preset \(preset) needs a non-empty label")
        }
    }
}
