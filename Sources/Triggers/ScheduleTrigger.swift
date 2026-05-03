import Foundation

// MARK: - Weekday

/// Weekday encoding aligned with `Calendar.component(.weekday, from:)` —
/// `sunday = 1`, `saturday = 7`. Stored as raw ints in JSON so the persisted
/// schema is stable across locales (Calendar's first-weekday differs per region;
/// the underlying weekday integer does not).
public enum Weekday: Int, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public var id: Int { rawValue }

    /// Display order Mon..Sun (ISO 8601 / ergonomic for most users), not raw 1..7.
    public static let displayOrder: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]

    public var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

// MARK: - TimeOfDay

/// Wall-clock time of day in the user's local calendar. Stored as `(hour, minute)`
/// rather than a `Date` so it is stable across DST transitions and timezone
/// changes — the entry "wake at 9:00 AM" should mean 9:00 AM regardless of
/// whether the user crossed a timezone boundary or DST kicked in.
public struct TimeOfDay: Codable, Sendable, Equatable, Hashable, Comparable {
    public let hour: Int   // 0..23
    public let minute: Int // 0..59

    public init(hour: Int, minute: Int) {
        // Sanitize on construction so persisted/UI-driven values cannot
        // produce out-of-range arithmetic in `contains(_:in:)`.
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }

    public var totalMinutes: Int { hour * 60 + minute }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.totalMinutes < rhs.totalMinutes
    }

    /// Convenience for tests / UI defaults.
    public static let nineAM = TimeOfDay(hour: 9, minute: 0)
    public static let sixPM = TimeOfDay(hour: 18, minute: 0)
}

// MARK: - ScheduleEntry

/// A single recurring time window. Stored as a Codable value type so persistence
/// is JSON-encoded (`SettingsKey.scheduleTriggerEntries`).
///
/// Semantics:
/// - `weekdays` is the set of days the entry's *start* falls on. Empty set =
///   never fires (UI is expected to show this as a hint).
/// - `start` and `end` are wall-clock times. If `end <= start`, the window
///   crosses midnight and continues into the next day — the next-day portion
///   still belongs to the original `weekdays` (i.e., a Monday 22:00–02:00 entry
///   covers Monday night through Tuesday 02:00, *not* Tuesday night).
/// - `start == end` is treated as "never fires" (zero-length window). Users
///   wanting a 24-hour entry can use 00:00–23:59 (effectively all day).
public struct ScheduleEntry: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var weekdays: Set<Weekday>
    public var start: TimeOfDay
    public var end: TimeOfDay
    public var label: String
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        weekdays: Set<Weekday>,
        start: TimeOfDay,
        end: TimeOfDay,
        label: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.weekdays = weekdays
        self.start = start
        self.end = end
        self.label = label
        self.isEnabled = isEnabled
    }

    /// Whether `date` falls inside this recurring window.
    ///
    /// - Same-day window (`start < end`): `weekday(date) ∈ weekdays`
    ///   AND `start ≤ time(date) < end`.
    /// - Midnight-crossing window (`start > end`): split into two halves.
    ///   - Late half `[start, 24:00)`: matches when current weekday ∈ weekdays.
    ///   - Early half `[00:00, end)`: matches when *yesterday's* weekday ∈ weekdays
    ///     (the original "starting" day).
    /// - Zero-length (`start == end`): never matches.
    public func contains(_ date: Date, in calendar: Calendar) -> Bool {
        guard isEnabled, !weekdays.isEmpty else { return false }
        if start == end { return false }

        let comps = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard
            let rawWeekday = comps.weekday,
            let weekday = Weekday(rawValue: rawWeekday),
            let hour = comps.hour,
            let minute = comps.minute
        else {
            return false
        }
        let nowMinutes = hour * 60 + minute
        let startMinutes = start.totalMinutes
        let endMinutes = end.totalMinutes

        if startMinutes < endMinutes {
            // Same-day window — half-open [start, end).
            return weekdays.contains(weekday)
                && nowMinutes >= startMinutes
                && nowMinutes < endMinutes
        } else {
            // Crosses midnight.
            if nowMinutes >= startMinutes {
                return weekdays.contains(weekday)
            } else if nowMinutes < endMinutes {
                // Yesterday's weekday matches Calendar order: Sun=1..Sat=7.
                // ((today - 2 + 7) % 7) + 1.
                let yesterdayRaw = ((rawWeekday - 2 + 7) % 7) + 1
                guard let yesterday = Weekday(rawValue: yesterdayRaw) else {
                    return false
                }
                return weekdays.contains(yesterday)
            }
            return false
        }
    }
}

// MARK: - SettingsStore extension (typed accessors)

public extension SettingsStore {
    var scheduleTriggerEntries: [ScheduleEntry] {
        get {
            guard let raw = data(.scheduleTriggerEntries) else { return [] }
            guard let decoded = try? JSONDecoder().decode([ScheduleEntry].self, from: raw) else {
                settingsLogger.notice("scheduleTriggerEntries failed to decode; using empty default")
                return []
            }
            return decoded
        }
        set {
            let encoded = try? JSONEncoder().encode(newValue)
            setData(encoded, for: .scheduleTriggerEntries)
        }
    }
}

// MARK: - ScheduleTrigger

@MainActor
public final class ScheduleTrigger: Trigger {

    public let id = "schedule"
    public let displayName = "Schedule"
    public let symbol = "clock"
    public let requiresPermission = false

    public var isEnabled: Bool {
        get { settings.bool(.scheduleTriggerEnabled, default: false) }
        set { settings.setBool(newValue, for: .scheduleTriggerEnabled) }
    }

    public let permissionStatus: TriggerPermissionStatus = .notRequired

    public let voteStream: AsyncStream<TriggerVote>
    private let continuation: AsyncStream<TriggerVote>.Continuation

    private let settings: SettingsStore
    private let pollInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let logger = LatteLog.schedule

    /// Tracks the currently-firing entry ID (if any) so transitions emit
    /// exactly one ON or OFF vote per state change rather than re-emitting
    /// every poll. `nil` means no entry is currently active.
    private var activeEntryID: UUID?
    private var pollTask: Task<Void, Never>?

    public init(
        settings: SettingsStore,
        pollInterval: TimeInterval = 30,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.settings = settings
        self.pollInterval = pollInterval
        self.now = now
        self.calendar = calendar
        let (stream, continuation) = AsyncStream<TriggerVote>.makeStream()
        self.voteStream = stream
        self.continuation = continuation
    }

    public func start() async {
        guard pollTask == nil else { return }
        logger.info("ScheduleTrigger.start")
        pollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.pollOnce()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await self.pollOnce()
            }
        }
    }

    public func stop() {
        logger.info("ScheduleTrigger.stop")
        pollTask?.cancel()
        pollTask = nil
        activeEntryID = nil
        // Mirrors S7.9/S7.11 contract for other triggers — do NOT call
        // continuation.finish(). The stream stays alive across the
        // trigger's registered lifetime so Toggle OFF→ON cycles work.
    }

    public func requestPermissionIfNeeded() async -> Bool { true }

    /// Test seam — invoked by `start`'s polling loop, also callable from tests
    /// and from the UI form on edit (so changes reflect within one render pass
    /// instead of waiting for the 30s poll cycle, mirroring App/WiFi/Calendar).
    public func pollOnce() async {
        guard isEnabled else { return }
        let entries = settings.scheduleTriggerEntries
        let nowDate = now()

        // First match wins. Stable iteration order (the persisted array order)
        // means the same entry is selected when multiple windows overlap.
        let matched = entries.first { $0.contains(nowDate, in: calendar) }

        switch (matched, activeEntryID) {
        case (let new?, let prev) where new.id != prev:
            // Entered a window (or switched to a different overlapping entry).
            activeEntryID = new.id
            continuation.yield(TriggerVote(
                wantsAwake: true,
                reason: voteReason(for: new)
            ))
        case (nil, .some):
            // Left every window.
            activeEntryID = nil
            continuation.yield(TriggerVote(
                wantsAwake: false,
                reason: "Schedule: outside all windows"
            ))
        default:
            // No transition — already active in same entry, or already idle.
            break
        }
    }

    /// V2-02 — re-evaluate immediately after a UI edit so settings changes
    /// commit within one render pass instead of waiting up to 30 s for the
    /// next poll. No-op when the trigger is stopped (running indicator is
    /// `pollTask`); the next `start()` will read fresh entries on its
    /// initial poll.
    public func reevaluateWatched() {
        guard pollTask != nil else { return }
        Task { await pollOnce() }
    }

    /// **S22 / P-issue-6d** — see `Trigger.reemitCurrentVote()` doc.
    /// Clears `activeEntryID` so `pollOnce()`'s `(matched=Some, prev=nil)`
    /// branch treats the current window as a fresh entry and re-emits ON.
    /// No emission when outside all windows (the `(nil, nil)` default
    /// branch stays silent — manager is already asleep).
    public func reemitCurrentVote() {
        guard pollTask != nil else { return }
        activeEntryID = nil
        Task { await pollOnce() }
    }

    private func voteReason(for entry: ScheduleEntry) -> String {
        if !entry.label.isEmpty {
            return "Schedule: \(entry.label)"
        }
        let startStr = String(format: "%02d:%02d", entry.start.hour, entry.start.minute)
        let endStr = String(format: "%02d:%02d", entry.end.hour, entry.end.minute)
        return "Schedule: \(startStr)–\(endStr)"
    }
}
