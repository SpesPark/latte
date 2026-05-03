import Foundation

/// Time-of-day quick presets (C-7 — Path A per `docs/design/08-c7-quick-presets-paths.md`).
///
/// **Deprecated by S19 #2** (2026-05-02): superseded by the
/// seed-then-mutable model. `RecurringQuickPreset.builtinSeeds()` now
/// holds the three legacy rows as data, and the popover renders only
/// from `recurringQuickPresets`. This enum is retained for the existing
/// nextOccurrence/minutes regression tests in `QuickPresetTests` —
/// no production code path references it. New rows must be added by
/// editing `builtinSeeds()` (with new stable UUIDs) or via the user
/// CRUD UI in General Settings.
///
/// These are NOT durations — they are wall-clock targets. The preset
/// computes "minutes from now to the next occurrence" at activation time
/// and routes that through `AwakeManager.activate(for: .minutes(N))`.
public enum QuickPreset: String, CaseIterable, Sendable {
    case until5PM
    case until11PM
    case untilMidnight

    /// 24-hour-clock target. Midnight is encoded as the next day's 00:00.
    public var targetHour: Int {
        switch self {
        case .until5PM:        return 17
        case .until11PM:       return 23
        case .untilMidnight:   return 24
        }
    }

    /// Owner-facing label for the popover row.
    public var label: String {
        switch self {
        case .until5PM:        return "Until 5 PM"
        case .until11PM:       return "Until 11 PM"
        case .untilMidnight:   return "Until midnight"
        }
    }

    /// Returns the number of whole minutes from `now` to the next
    /// occurrence of `targetHour:00`. If the target has already passed
    /// today, jumps to the next day. Never returns less than 1 — a 0-min
    /// or negative result would mean "activate for 0 minutes" which
    /// instantly deactivates and confuses the owner.
    public func minutes(from now: Date, calendar: Calendar = .current) -> Int {
        let target = nextOccurrence(after: now, calendar: calendar)
        let secondsAhead = target.timeIntervalSince(now)
        // S23 / P-issue-1: round up (not to-nearest) so endsAt is never
        // before target. Same fix as RecurringQuickPreset.minutes — kept
        // parallel even though this enum is dead code (regression tests
        // remain). See RecurringQuickPreset.minutes for the user-facing
        // rationale.
        let mins = Int((secondsAhead / 60).rounded(.up))
        return max(1, mins)
    }

    /// Computes the next wall-clock occurrence of `targetHour:00`.
    /// `targetHour == 24` means "tomorrow 00:00" — encoded by adding a
    /// day and using hour 0 of that day.
    func nextOccurrence(after now: Date, calendar: Calendar = .current) -> Date {
        if targetHour == 24 {
            // Next midnight = tomorrow's startOfDay.
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            return tomorrow ?? now
        }
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = targetHour
        components.minute = 0
        components.second = 0
        guard let candidate = calendar.date(from: components) else { return now }
        if candidate > now {
            return candidate
        }
        // Target already passed today — jump to tomorrow.
        return calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
    }
}
