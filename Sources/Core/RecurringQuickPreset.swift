import Foundation

/// User-defined recurring quick preset (C-7 v1.7 — "per-day-of-week
/// recurring presets" from `docs/design/08-c7-quick-presets-paths.md` §9).
///
/// Like the built-in `QuickPreset` cases (until 5 PM / 11 PM / midnight),
/// these convert to `.minutes(N)` at click time and route through
/// `AwakeManager.activate(for:)`. Unlike the built-ins they:
/// - have an owner-supplied label and minute precision
/// - only appear in the popover on configured weekdays
/// - persist across launches
///
/// `weekdays` uses the Calendar `.weekday` convention: 1 = Sunday … 7 =
/// Saturday. An empty set means "never active" (preset is filtered out
/// of the popover).
public struct RecurringQuickPreset: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let targetHour: Int       // 0…23
    public let targetMinute: Int     // 0…59
    public let weekdays: Set<Int>    // subset of 1…7

    public init(
        id: UUID = UUID(),
        label: String,
        targetHour: Int,
        targetMinute: Int,
        weekdays: Set<Int>
    ) {
        self.id = id
        self.label = label
        self.targetHour = targetHour
        self.targetMinute = targetMinute
        self.weekdays = weekdays
    }

    /// True if `date`'s weekday is in the configured set. Used by the
    /// popover to filter — only "active today" presets render.
    public func isActiveOn(date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekdays.contains(weekday)
    }

    /// Computes the next future wall-clock occurrence of `targetHour:targetMinute`
    /// on a configured weekday. Looks ahead up to 7 days. Returns `now` for
    /// an empty weekday set so `minutes(from:)` stays defined (clamped to 1
    /// at the call site).
    public func nextOccurrence(after now: Date, calendar: Calendar = .current) -> Date {
        guard !weekdays.isEmpty else { return now }
        for offset in 0...7 {
            guard let candidateDay = calendar.date(byAdding: .day, value: offset, to: now) else {
                continue
            }
            let weekday = calendar.component(.weekday, from: candidateDay)
            guard weekdays.contains(weekday) else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            comps.hour = targetHour
            comps.minute = targetMinute
            comps.second = 0
            guard let candidate = calendar.date(from: comps) else { continue }
            if candidate > now {
                return candidate
            }
        }
        // Fallback: should be unreachable for non-empty weekdays + valid
        // hour/minute, but stay defensive — return now so caller's clamp
        // produces 1 minute rather than crashing.
        return now
    }

    /// Whole minutes from `now` to the next occurrence, clamped to 1 so
    /// a click at the boundary never activates for 0 minutes (which would
    /// instantly deactivate). Mirrors `QuickPreset.minutes(from:)`.
    public func minutes(from now: Date, calendar: Calendar = .current) -> Int {
        let target = nextOccurrence(after: now, calendar: calendar)
        let secondsAhead = target.timeIntervalSince(now)
        return max(1, Int((secondsAhead / 60).rounded()))
    }

    // MARK: - Persistence (SettingsStore round-trip)

    /// Writes the list to `SettingsKey.recurringQuickPresets`. Empty list
    /// removes the key (preserves "absent = never customised" invariant).
    public static func write(_ presets: [RecurringQuickPreset], to store: SettingsStore) {
        guard !presets.isEmpty else {
            store.remove(.recurringQuickPresets)
            return
        }
        guard let data = try? JSONEncoder().encode(presets) else { return }
        store.setData(data, for: .recurringQuickPresets)
    }

    /// Reads the list from `SettingsKey.recurringQuickPresets`. Returns
    /// `[]` for nil / corrupt payload — never crashes.
    public static func read(from store: SettingsStore) -> [RecurringQuickPreset] {
        guard let data = store.data(.recurringQuickPresets) else { return [] }
        return (try? JSONDecoder().decode([RecurringQuickPreset].self, from: data)) ?? []
    }
}
