import XCTest
@testable import Latte

final class RecurringQuickPresetTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a Gregorian calendar in UTC so weekday/hour assertions are
    /// deterministic across CI hosts. All fixtures below build dates via
    /// `dateComponents` against this calendar.
    private static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    private func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute; comps.second = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)!
        return Calendar(identifier: .gregorian).date(from: {
            var c = comps; return c
        }()) ?? Date()
    }

    private func makePreset(
        label: String = "Until 6 PM",
        hour: Int = 18,
        minute: Int = 0,
        weekdays: Set<Int> = [2, 3, 4, 5, 6]   // Mon-Fri
    ) -> RecurringQuickPreset {
        RecurringQuickPreset(
            id: UUID(),
            label: label,
            targetHour: hour,
            targetMinute: minute,
            weekdays: weekdays
        )
    }

    // MARK: - isActiveOn

    func testIsActiveOnReturnsTrueWhenTodayMatchesWeekdays() {
        // 2026-05-04 is a Monday (weekday=2 in Calendar's 1=Sun convention).
        let monday = date(year: 2026, month: 5, day: 4, hour: 12)
        let preset = makePreset(weekdays: [2, 3, 4, 5, 6])   // Mon-Fri
        XCTAssertTrue(preset.isActiveOn(date: monday, calendar: Self.utcCalendar))
    }

    func testIsActiveOnReturnsFalseWhenTodayNotInWeekdays() {
        let saturday = date(year: 2026, month: 5, day: 9, hour: 12)
        let preset = makePreset(weekdays: [2, 3, 4, 5, 6])
        XCTAssertFalse(preset.isActiveOn(date: saturday, calendar: Self.utcCalendar))
    }

    func testIsActiveOnFalseForEmptyWeekdays() {
        // Degenerate "no days selected" — preset never appears in the popover.
        let any = date(year: 2026, month: 5, day: 4, hour: 12)
        let preset = makePreset(weekdays: [])
        XCTAssertFalse(preset.isActiveOn(date: any, calendar: Self.utcCalendar))
    }

    // MARK: - nextOccurrence

    func testNextOccurrencePicksTodayWhenTargetIsFutureAndWeekdayActive() {
        // Monday 10:00 UTC, target = 18:00 today. Result: same day 18:00.
        let monday10am = date(year: 2026, month: 5, day: 4, hour: 10)
        let preset = makePreset(hour: 18, weekdays: [2, 3, 4, 5, 6])
        let next = preset.nextOccurrence(after: monday10am, calendar: Self.utcCalendar)
        XCTAssertEqual(next, date(year: 2026, month: 5, day: 4, hour: 18))
    }

    func testNextOccurrenceJumpsToNextActiveWeekdayWhenTargetPassed() {
        // Monday 19:00, target = 18:00 (already passed). Tue is also active
        // → next = Tuesday 18:00.
        let mondayEvening = date(year: 2026, month: 5, day: 4, hour: 19)
        let preset = makePreset(hour: 18, weekdays: [2, 3, 4, 5, 6])
        let next = preset.nextOccurrence(after: mondayEvening, calendar: Self.utcCalendar)
        XCTAssertEqual(next, date(year: 2026, month: 5, day: 5, hour: 18))
    }

    func testNextOccurrenceSkipsInactiveWeekdays() {
        // Friday 19:00 with Mon-Fri only → next active is Monday 18:00 (3 days).
        let fridayEvening = date(year: 2026, month: 5, day: 8, hour: 19)
        let preset = makePreset(hour: 18, weekdays: [2, 3, 4, 5, 6])
        let next = preset.nextOccurrence(after: fridayEvening, calendar: Self.utcCalendar)
        XCTAssertEqual(next, date(year: 2026, month: 5, day: 11, hour: 18))   // Monday
    }

    func testNextOccurrenceWeekendOnly() {
        // Mon 12:00 with weekend-only preset → next = Sat 18:00 (5 days ahead).
        let monday = date(year: 2026, month: 5, day: 4, hour: 12)
        let preset = makePreset(hour: 18, weekdays: [1, 7])   // Sun + Sat
        let next = preset.nextOccurrence(after: monday, calendar: Self.utcCalendar)
        XCTAssertEqual(next, date(year: 2026, month: 5, day: 9, hour: 18))   // Saturday
    }

    func testNextOccurrenceEmptyWeekdaysReturnsNow() {
        // Defensive: empty configured set → "no future occurrence". Returning
        // `now` keeps `minutes(from:)` defined and clamped to 1; the popover
        // never shows an empty-weekday preset (filtered by isActiveOn).
        let monday = date(year: 2026, month: 5, day: 4, hour: 12)
        let preset = makePreset(weekdays: [])
        XCTAssertEqual(preset.nextOccurrence(after: monday, calendar: Self.utcCalendar), monday)
    }

    func testNextOccurrenceWithMinuteOffset() {
        // 18:30 target on Monday 10:00 → Monday 18:30 (not 18:00, not 19:00).
        let monday10am = date(year: 2026, month: 5, day: 4, hour: 10)
        let preset = makePreset(hour: 18, minute: 30, weekdays: [2])
        let next = preset.nextOccurrence(after: monday10am, calendar: Self.utcCalendar)
        XCTAssertEqual(next, date(year: 2026, month: 5, day: 4, hour: 18, minute: 30))
    }

    // MARK: - minutes(from:)

    func testMinutesFromClampsToOne() {
        let monday1759 = date(year: 2026, month: 5, day: 4, hour: 17, minute: 59)
        let preset = makePreset(hour: 18, minute: 0, weekdays: [2])
        // Target is 1 minute away. Clamp guarantees at least 1.
        XCTAssertEqual(preset.minutes(from: monday1759, calendar: Self.utcCalendar), 1)
    }

    func testMinutesFromComputesWholeMinutes() {
        let monday12pm = date(year: 2026, month: 5, day: 4, hour: 12)
        let preset = makePreset(hour: 18, minute: 0, weekdays: [2])
        // 6 hours = 360 min.
        XCTAssertEqual(preset.minutes(from: monday12pm, calendar: Self.utcCalendar), 360)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original = RecurringQuickPreset(
            id: UUID(),
            label: "Until 6 PM weekdays",
            targetHour: 18,
            targetMinute: 0,
            weekdays: [2, 3, 4, 5, 6]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecurringQuickPreset.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testArrayCodableRoundTrip() throws {
        let presets = [
            makePreset(label: "A"),
            makePreset(label: "B", weekdays: [1, 7])
        ]
        let data = try JSONEncoder().encode(presets)
        let decoded = try JSONDecoder().decode([RecurringQuickPreset].self, from: data)
        XCTAssertEqual(decoded, presets)
    }

    // MARK: - SettingsStore round-trip

    func testEncodeDecodeViaSettingsHelpers() throws {
        let store = InMemorySettingsStore()
        let presets = [
            makePreset(label: "Until 6 PM"),
            makePreset(label: "Until 11 PM", hour: 23)
        ]
        RecurringQuickPreset.write(presets, to: store)
        XCTAssertEqual(RecurringQuickPreset.read(from: store), presets)
    }

    func testWriteEmptyClearsTheKey() {
        let store = InMemorySettingsStore()
        RecurringQuickPreset.write([makePreset()], to: store)
        XCTAssertNotNil(store.data(.recurringQuickPresets), "non-empty list persists")

        RecurringQuickPreset.write([], to: store)
        XCTAssertNil(store.data(.recurringQuickPresets),
                     "empty list must remove the key, not store [] data")
    }

    func testReadNilDataReturnsEmpty() {
        let store = InMemorySettingsStore()
        XCTAssertEqual(RecurringQuickPreset.read(from: store), [])
    }

    func testReadCorruptDataReturnsEmpty() {
        let store = InMemorySettingsStore()
        store.setData(Data([0xFF, 0x00, 0xAB]), for: .recurringQuickPresets)
        XCTAssertEqual(RecurringQuickPreset.read(from: store), [],
                       "corrupt JSON must NOT crash — fall through to empty list")
    }

    // MARK: - Weekday summary

    func testWeekdaySummaryEmpty() {
        XCTAssertEqual(RecurringPresetWeekday.summary(for: []), "Never")
    }

    func testWeekdaySummaryEveryDay() {
        XCTAssertEqual(
            RecurringPresetWeekday.summary(for: Set([1, 2, 3, 4, 5, 6, 7])),
            "Every day"
        )
    }

    func testWeekdaySummaryWeekdays() {
        XCTAssertEqual(
            RecurringPresetWeekday.summary(for: Set([2, 3, 4, 5, 6])),
            "Weekdays"
        )
    }

    func testWeekdaySummaryWeekends() {
        XCTAssertEqual(
            RecurringPresetWeekday.summary(for: Set([1, 7])),
            "Weekends"
        )
    }

    func testWeekdaySummaryArbitraryListsInWeekOrder() {
        XCTAssertEqual(
            RecurringPresetWeekday.summary(for: Set([3, 5, 7])),
            "Tue, Thu, Sat",
            "comma-separated short labels in Sun-first weekday order"
        )
    }

    func testShortLabelForKnownWeekdays() {
        XCTAssertEqual(RecurringPresetWeekday.shortLabel(for: 1), "Sun")
        XCTAssertEqual(RecurringPresetWeekday.shortLabel(for: 7), "Sat")
    }

    // MARK: - builtinSeeds (S19 #2 — seed-then-mutable model)

    /// `builtinSeeds()` returns the three legacy `QuickPreset` cases as
    /// `RecurringQuickPreset` values so they migrate into the regular
    /// CRUD list and can be edited or deleted by the owner.
    func testBuiltinSeedsReturnsThreePresets() {
        let seeds = RecurringQuickPreset.builtinSeeds()
        XCTAssertEqual(seeds.count, 3)
    }

    /// Labels match the prior `QuickPreset` enum exactly so a v1.7 user
    /// who upgrades sees the same three rows in the popover (now backed
    /// by data instead of hard-coded enum cases).
    func testBuiltinSeedsLabelsMatchLegacyQuickPreset() {
        let labels = RecurringQuickPreset.builtinSeeds().map(\.label)
        XCTAssertEqual(labels, ["Until 5 PM", "Until 11 PM", "Until midnight"])
    }

    /// Seeds run every day so the migrated presets are indistinguishable
    /// from the previous always-shown enum cases. Owner-confirmed (S19
    /// #2 design point b).
    func testBuiltinSeedsRunEveryDay() {
        for seed in RecurringQuickPreset.builtinSeeds() {
            XCTAssertEqual(seed.weekdays, Set(1...7), "seed \(seed.label) must be every-day")
        }
    }

    /// Target hour/minute matches `QuickPreset.targetHour`. Midnight
    /// (legacy `targetHour == 24`) is encoded as hour 0 — the
    /// `nextOccurrence` lookahead naturally jumps to tomorrow when the
    /// candidate has already passed (which it always has if hour == 0).
    func testBuiltinSeedsTargetTimes() {
        let seeds = RecurringQuickPreset.builtinSeeds()
        XCTAssertEqual(seeds[0].targetHour, 17)   // Until 5 PM
        XCTAssertEqual(seeds[0].targetMinute, 0)
        XCTAssertEqual(seeds[1].targetHour, 23)   // Until 11 PM
        XCTAssertEqual(seeds[1].targetMinute, 0)
        XCTAssertEqual(seeds[2].targetHour, 0)    // Until midnight (next day's 00:00)
        XCTAssertEqual(seeds[2].targetMinute, 0)
    }

    /// Each seed gets a stable UUID so two calls produce equal lists. A
    /// fresh UUID per call would make the migration write a different
    /// list on every launch and double-seed across edge cases.
    func testBuiltinSeedsAreStableAcrossCalls() {
        let first = RecurringQuickPreset.builtinSeeds()
        let second = RecurringQuickPreset.builtinSeeds()
        XCTAssertEqual(first, second, "seed UUIDs must be stable so writes are idempotent")
    }

    /// `nextOccurrence` for the midnight seed jumps to tomorrow's
    /// 00:00 when called after the day has started — same behaviour as
    /// the legacy `QuickPreset.untilMidnight` (which used the
    /// `targetHour == 24` sentinel).
    func testBuiltinSeedsMidnightRollsToTomorrow() {
        let utc = Self.utcCalendar
        let seeds = RecurringQuickPreset.builtinSeeds()
        let midnightSeed = seeds[2]   // Until midnight
        // 9 AM today → next 00:00 = tomorrow's start, 15 hours away.
        let nineAM = date(year: 2027, month: 1, day: 15, hour: 9)
        let mins = midnightSeed.minutes(from: nineAM, calendar: utc)
        XCTAssertEqual(mins, 15 * 60)
    }

    // MARK: - Migration (seedBuiltinPresetsIfNeeded)

    /// Case A — fresh install: sentinel false + no presets stored. Migration
    /// writes the 3 seeds and sets the sentinel to true.
    func testMigrationSeedsOnFreshInstall() {
        let store = InMemorySettingsStore()
        XCTAssertFalse(store.bool(.didSeedBuiltinPresets, default: false))
        XCTAssertTrue(RecurringQuickPreset.read(from: store).isEmpty)

        RecurringQuickPreset.seedBuiltinPresetsIfNeeded(in: store)

        XCTAssertTrue(store.bool(.didSeedBuiltinPresets, default: false))
        XCTAssertEqual(RecurringQuickPreset.read(from: store), RecurringQuickPreset.builtinSeeds())
    }

    /// Case B — v1.7 user upgrading with existing user-defined presets.
    /// The existing presets must NOT be overwritten; sentinel still moves
    /// to true so the migration never runs again.
    func testMigrationDoesNotOverwriteExistingPresets() {
        let store = InMemorySettingsStore()
        let existing = [makePreset(label: "Existing", hour: 19, weekdays: [2, 3])]
        RecurringQuickPreset.write(existing, to: store)

        RecurringQuickPreset.seedBuiltinPresetsIfNeeded(in: store)

        XCTAssertTrue(store.bool(.didSeedBuiltinPresets, default: false))
        XCTAssertEqual(RecurringQuickPreset.read(from: store), existing)
    }

    /// Case C — sentinel already true. Migration is a no-op even if the
    /// list is empty (owner deleted all seeds intentionally).
    func testMigrationDoesNotReseedAfterUserDeletedAllPresets() {
        let store = InMemorySettingsStore()
        store.setBool(true, for: .didSeedBuiltinPresets)
        // List intentionally empty — owner cleared all presets.

        RecurringQuickPreset.seedBuiltinPresetsIfNeeded(in: store)

        XCTAssertTrue(store.bool(.didSeedBuiltinPresets, default: false))
        XCTAssertTrue(
            RecurringQuickPreset.read(from: store).isEmpty,
            "sentinel-true means user has full control; never re-seed"
        )
    }

    /// Regression for the third launch-time case in §11: sentinel true +
    /// non-empty list (i.e. a normal returning user) is a no-op. The
    /// presets are not modified, the sentinel stays true, and no
    /// `write` runs that could perturb timestamps or ordering.
    func testMigrationIsNoOpForReturningUserWithPresets() {
        let store = InMemorySettingsStore()
        store.setBool(true, for: .didSeedBuiltinPresets)
        let existing = [makePreset(label: "User preset", hour: 14, weekdays: [1, 7])]
        RecurringQuickPreset.write(existing, to: store)

        RecurringQuickPreset.seedBuiltinPresetsIfNeeded(in: store)

        XCTAssertTrue(store.bool(.didSeedBuiltinPresets, default: false))
        XCTAssertEqual(RecurringQuickPreset.read(from: store), existing)
    }
}
