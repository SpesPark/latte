import Foundation

/// One trigger-fire event recorded for the Activity history view (C-3).
///
/// Persisted to `~/Library/Application Support/Latte/activity-log.json` by
/// `ActivityLogStore`. See `docs/design/09-c3-activity-history.md` §2 for the
/// privacy contract — no free-text or user-content fields by design.
public struct ActivityLogEntry: Codable, Equatable, Sendable, Identifiable {

    public let id: UUID
    public let timestamp: Date
    public let triggerId: String
    public let kind: Kind
    public let reasonCode: ReasonCode

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        triggerId: String,
        kind: Kind,
        reasonCode: ReasonCode
    ) {
        self.id = id
        self.timestamp = timestamp
        self.triggerId = triggerId
        self.kind = kind
        self.reasonCode = reasonCode
    }

    public enum Kind: String, Codable, Sendable, CaseIterable {
        case on
        case off
    }

    public enum ReasonCode: String, Codable, Sendable, CaseIterable {
        /// Generic ON vote from a trigger (organic detection).
        case voteOn
        /// Generic OFF vote from a trigger (organic detection).
        case voteOff
        /// User-explicit OFF: Toggle in Settings, last watched app removed, etc.
        /// Bypasses any per-trigger grace period (graceSecondsAfterOff = 0).
        case userToggleOff
        /// Trigger.stop() invoked by coordinator (e.g. trigger disabled in Settings).
        case stoppedByCoordinator
    }
}
