import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(EventKit)
import EventKit
#endif

// MARK: - CalendarSource protocol (for DI / testing)

/// Abstracts EventKit so `CalendarTrigger` is testable without a live store.
@MainActor
public protocol CalendarSource: AnyObject {
    var permissionStatus: TriggerPermissionStatus { get }
    func requestAccess() async -> Bool
    /// Returns events whose `[startDate, endDate]` intersects `[windowStart, windowEnd]`,
    /// optionally restricted to the given calendar identifiers (empty = all granted).
    func events(in window: ClosedRange<Date>, calendarIDs: [String]) -> [CalendarEventSnapshot]
    /// Enumerates the user's accessible calendars for the picker UI (V2-04).
    /// Returns `[]` when permission is not granted; the UI is expected to
    /// guard against showing the picker before the access prompt resolves.
    func availableCalendars() -> [CalendarSummary]
}

/// Lightweight projection of an EKCalendar for the picker UI. Avoids
/// holding EventKit references past the snapshot.
public struct CalendarSummary: Equatable, Sendable, Identifiable {
    public let id: String           // EKCalendar.calendarIdentifier
    public let title: String
    /// CGColor not Sendable; persist as sRGB components so the UI can
    /// reconstruct an `NSColor`/`Color` without a live EKCalendar.
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
    /// `local`, `iCloud`, `subscription`, `birthday`, `exchange`, etc.
    /// We surface this so the UI can group calendars by source.
    public let sourceTitle: String

    public init(
        id: String,
        title: String,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double,
        sourceTitle: String
    ) {
        self.id = id
        self.title = title
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.sourceTitle = sourceTitle
    }
}

/// Snapshot of an EKEvent. We never hold EventKit objects past their fetch.
public struct CalendarEventSnapshot: Equatable, Sendable, Identifiable {
    public let id: String           // EKEvent.eventIdentifier (or stable composite for tests)
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let calendarID: String

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarID: String
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarID = calendarID
    }
}

// MARK: - Real EventKit-backed source

#if canImport(EventKit)
@MainActor
public final class EKCalendarSource: CalendarSource {

    private let store: EKEventStore
    private let logger = LatteLog.calendar

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public var permissionStatus: TriggerPermissionStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        case .authorized, .writeOnly: return .granted
        case .fullAccess: return .granted
        @unknown default: return .notDetermined
        }
    }

    public func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            do {
                return try await store.requestFullAccessToEvents()
            } catch {
                logger.error("requestFullAccessToEvents failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { granted, error in
                    if let error {
                        self.logger.error("requestAccess(.event) failed: \(error.localizedDescription, privacy: .public)")
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    public func events(in window: ClosedRange<Date>, calendarIDs: [String]) -> [CalendarEventSnapshot] {
        let calendars: [EKCalendar]?
        if calendarIDs.isEmpty {
            calendars = nil // all granted
        } else {
            let allowed = Set(calendarIDs)
            calendars = store.calendars(for: .event).filter { allowed.contains($0.calendarIdentifier) }
        }
        let predicate = store.predicateForEvents(
            withStart: window.lowerBound,
            end: window.upperBound,
            calendars: calendars
        )
        let events = store.events(matching: predicate)
        return events.map { event in
            CalendarEventSnapshot(
                id: event.eventIdentifier ?? "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)",
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarID: event.calendar?.calendarIdentifier ?? ""
            )
        }
    }

    public func availableCalendars() -> [CalendarSummary] {
        guard permissionStatus == .granted else { return [] }
        let calendars = store.calendars(for: .event)
        return calendars.map { calendar in
            // EKCalendar.cgColor is the user-set hue. Decompose into sRGB.
            let nsColor = NSColor(cgColor: calendar.cgColor) ?? NSColor.systemBlue
            let resolved = nsColor.usingColorSpace(.sRGB) ?? nsColor
            return CalendarSummary(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                red: Double(resolved.redComponent),
                green: Double(resolved.greenComponent),
                blue: Double(resolved.blueComponent),
                alpha: Double(resolved.alphaComponent),
                sourceTitle: calendar.source?.title ?? ""
            )
        }
        .sorted { lhs, rhs in
            // Group by source, then alphabetic within source for stable display.
            if lhs.sourceTitle != rhs.sourceTitle {
                return lhs.sourceTitle.localizedCaseInsensitiveCompare(rhs.sourceTitle) == .orderedAscending
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
#endif

// MARK: - CalendarTrigger

@MainActor
public final class CalendarTrigger: Trigger {

    public let id = "calendar"
    public let displayName = "Calendar events"
    public let symbol = "calendar"
    public let requiresPermission = true

    public var isEnabled: Bool {
        get { settings.bool(.calendarTriggerEnabled, default: false) }
        set { settings.setBool(newValue, for: .calendarTriggerEnabled) }
    }

    public var permissionStatus: TriggerPermissionStatus { source.permissionStatus }

    public let voteStream: AsyncStream<TriggerVote>
    private let continuation: AsyncStream<TriggerVote>.Continuation

    private let settings: SettingsStore
    private let source: CalendarSource
    private let pollInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let logger = LatteLog.calendar

    /// Set of event IDs currently driving an ON vote (event is in [now-trailing, now+lead] window).
    private var activeEventIDs: Set<String> = []
    private var pollTask: Task<Void, Never>?

    public init(
        settings: SettingsStore,
        source: CalendarSource? = nil,
        pollInterval: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.settings = settings
        self.pollInterval = pollInterval
        self.now = now
        let (stream, continuation) = AsyncStream<TriggerVote>.makeStream()
        self.voteStream = stream
        self.continuation = continuation
        if let source {
            self.source = source
        } else {
            #if canImport(EventKit)
            self.source = EKCalendarSource()
            #else
            self.source = NoopCalendarSource()
            #endif
        }
    }

    public func start() async {
        guard pollTask == nil else { return }
        logger.info("CalendarTrigger.start")
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
        logger.info("CalendarTrigger.stop")
        pollTask?.cancel()
        pollTask = nil
        activeEventIDs.removeAll()
        // Per S7.9 / S7.11: do NOT call `continuation.finish()`. Finishing
        // the AsyncStream permanently closes it and any future `start()` would
        // be unable to deliver votes (the next consumer's `for await` would
        // exit immediately, future yields silently dropped). The coordinator
        // cancels its consumer task on stop and recreates one on start; both
        // subscribe to the same long-lived stream.
    }

    public func requestPermissionIfNeeded() async -> Bool {
        switch source.permissionStatus {
        case .granted: return true
        case .denied: return false
        case .notRequired, .notDetermined: return await source.requestAccess()
        }
    }

    /// V2-04 — picker UI delegate. Exposes the underlying source's
    /// available calendars so the Settings form can render a multi-select
    /// list. Returns `[]` when permission is not granted.
    public func availableCalendars() -> [CalendarSummary] {
        source.availableCalendars()
    }

    /// V2-02 — re-evaluate immediately after a UI edit so settings changes
    /// commit within one render pass instead of waiting up to 60 s for the
    /// next poll. No-op when the trigger is stopped (running indicator is
    /// `pollTask`); the next `start()` will read fresh settings on its
    /// initial poll.
    public func reevaluateWatched() {
        guard pollTask != nil else { return }
        Task { await pollOnce() }
    }

    /// Test seam — invoked by `start`'s polling loop, also callable directly from tests.
    public func pollOnce() async {
        guard isEnabled else { return }
        guard source.permissionStatus == .granted else { return }

        let leadMinutes = settings.calendarTriggerLeadTimeMinutes
        let trailingMinutes = settings.calendarTriggerTrailingMinutes
        let calendarIDs = settings.calendarTriggerCalendarIDs
        let excludeAllDay = settings.calendarTriggerExcludeAllDay

        let nowDate = now()
        // Look-ahead window: 24h covers any leadTime up to a day; we filter again per-event below.
        let windowStart = nowDate.addingTimeInterval(-3600 * 24)
        let windowEnd = nowDate.addingTimeInterval(3600 * 24)
        let events = source.events(in: windowStart...windowEnd, calendarIDs: calendarIDs)

        let active = events.filter { event in
            if excludeAllDay && event.isAllDay { return false }
            // Event is "active" iff: event.start − leadTime ≤ now ≤ event.end + trailingTime
            let voteOnAt = event.startDate.addingTimeInterval(-Double(leadMinutes) * 60)
            let voteOffAt = event.endDate.addingTimeInterval(Double(trailingMinutes) * 60)
            return nowDate >= voteOnAt && nowDate <= voteOffAt
        }

        let activeIDs = Set(active.map(\.id))

        // Newly-active events emit ON. Newly-inactive events: if no others remain, emit OFF.
        let newlyActive = activeIDs.subtracting(activeEventIDs)
        let newlyInactive = activeEventIDs.subtracting(activeIDs)

        for event in active where newlyActive.contains(event.id) {
            continuation.yield(TriggerVote(
                wantsAwake: true,
                reason: "Calendar: \(event.title)",
                until: event.endDate.addingTimeInterval(Double(trailingMinutes) * 60)
            ))
        }

        if !newlyInactive.isEmpty && activeIDs.isEmpty {
            continuation.yield(TriggerVote(wantsAwake: false, reason: "Calendar: no active events"))
        }

        activeEventIDs = activeIDs
    }
}

// MARK: - Mock source for tests

@MainActor
public final class MockCalendarSource: CalendarSource {
    public var permissionStatus: TriggerPermissionStatus
    public var events: [CalendarEventSnapshot]
    public var calendars: [CalendarSummary]
    public private(set) var requestAccessCalls = 0
    public private(set) var lastQueryCalendarIDs: [String]?
    public private(set) var lastQueryWindow: ClosedRange<Date>?

    public init(
        permissionStatus: TriggerPermissionStatus = .granted,
        events: [CalendarEventSnapshot] = [],
        calendars: [CalendarSummary] = []
    ) {
        self.permissionStatus = permissionStatus
        self.events = events
        self.calendars = calendars
    }

    public func requestAccess() async -> Bool {
        requestAccessCalls += 1
        if permissionStatus == .notDetermined { permissionStatus = .granted }
        return permissionStatus == .granted
    }

    public func events(in window: ClosedRange<Date>, calendarIDs: [String]) -> [CalendarEventSnapshot] {
        lastQueryWindow = window
        lastQueryCalendarIDs = calendarIDs
        if calendarIDs.isEmpty {
            return events.filter { !($0.endDate < window.lowerBound || $0.startDate > window.upperBound) }
        } else {
            let allowed = Set(calendarIDs)
            return events.filter {
                allowed.contains($0.calendarID)
                && !($0.endDate < window.lowerBound || $0.startDate > window.upperBound)
            }
        }
    }

    public func availableCalendars() -> [CalendarSummary] {
        guard permissionStatus == .granted else { return [] }
        return calendars
    }
}

#if !canImport(EventKit)
@MainActor
final class NoopCalendarSource: CalendarSource {
    var permissionStatus: TriggerPermissionStatus { .denied }
    func requestAccess() async -> Bool { false }
    func events(in window: ClosedRange<Date>, calendarIDs: [String]) -> [CalendarEventSnapshot] { [] }
    func availableCalendars() -> [CalendarSummary] { [] }
}
#endif

// MARK: - SettingsStore typed extensions (unchanged from S3)

public extension SettingsStore {
    var calendarTriggerCalendarIDs: [String] {
        get { decodeStringArray(.calendarTriggerCalendarIDs) }
        set { encodeStringArray(newValue, for: .calendarTriggerCalendarIDs) }
    }

    var calendarTriggerExcludeAllDay: Bool {
        get { bool(.calendarTriggerExcludeAllDay, default: true) }
        set { setBool(newValue, for: .calendarTriggerExcludeAllDay) }
    }

    var calendarTriggerLeadTimeMinutes: Int {
        get { clampedInteger(.calendarTriggerLeadTimeMinutes, default: 0, range: 0...15) }
        set { setInteger(max(0, min(15, newValue)), for: .calendarTriggerLeadTimeMinutes) }
    }

    var calendarTriggerTrailingMinutes: Int {
        get { clampedInteger(.calendarTriggerTrailingMinutes, default: 0, range: 0...15) }
        set { setInteger(max(0, min(15, newValue)), for: .calendarTriggerTrailingMinutes) }
    }
}
