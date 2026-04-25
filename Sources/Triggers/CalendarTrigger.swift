import Foundation

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

    public private(set) var permissionStatus: TriggerPermissionStatus = .notDetermined

    public let voteStream: AsyncStream<TriggerVote>
    private let continuation: AsyncStream<TriggerVote>.Continuation

    private let settings: SettingsStore
    private let logger = LatteLog.calendar

    public init(settings: SettingsStore) {
        self.settings = settings
        let (stream, continuation) = AsyncStream<TriggerVote>.makeStream()
        self.voteStream = stream
        self.continuation = continuation
    }

    public func start() async {
        // Real EventKit wiring lands in session 4.
        logger.info("CalendarTrigger.start (stub)")
    }

    public func stop() {
        logger.info("CalendarTrigger.stop (stub)")
        continuation.finish()
    }

    public func requestPermissionIfNeeded() async -> Bool {
        // Real EKEventStore.requestFullAccessToEvents lands in session 4.
        return false
    }
}

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
