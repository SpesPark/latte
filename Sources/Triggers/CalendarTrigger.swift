import EventKit
import Foundation
import os.log

/// Phase A scaffolding: keeps the Mac awake during in-progress calendar events.
///
/// Implementation plan:
/// 1. Request `EKEventStore` full access.
/// 2. Subscribe to `.EKEventStoreChanged` notifications.
/// 3. Every minute (or on change), query events that are happening "now"
///    (`predicateForEvents(withStart:end:calendars:)`).
/// 4. If at least one event is in progress, call `awake.activate(for: .indefinite)`.
///    When all events end, deactivate.
@MainActor
final class CalendarTrigger: Trigger {

    let id = "calendar"
    let name = "Calendar Events"

    private static let logger = Logger(subsystem: "com.example.caffeinated", category: "CalendarTrigger")

    var isEnabled: Bool = false {
        didSet { isEnabled ? start() : stop() }
    }

    private let store = EKEventStore()
    private weak var awakeManager: AwakeManager?
    private var observer: NSObjectProtocol?
    private var pollTimer: Timer?

    init(awakeManager: AwakeManager) {
        self.awakeManager = awakeManager
    }

    /// Requests full calendar access (macOS 14+) with a fallback for macOS 13.
    func requestAccess() async -> Bool {
        if #available(macOS 14, *) {
            do {
                return try await store.requestFullAccessToEvents()
            } catch {
                Self.logger.error("Calendar access denied: \(error.localizedDescription)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func start() {
        // TODO Phase A:
        // - Subscribe to .EKEventStoreChanged
        // - Schedule a 60s poll timer that checks current events
        // - On any in-progress event, call awakeManager?.activate(for: .indefinite)
        Self.logger.info("CalendarTrigger.start() — not yet implemented")
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
        Self.logger.info("CalendarTrigger.stop()")
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
