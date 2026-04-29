import Foundation

/// Pure formatting helpers for the About tab's status section.
/// Kept free of SwiftUI / view types so they can be unit-tested directly.
public enum AssertionStatusFormatter {

    public static func stateLabel(isAwake: Bool) -> String {
        isAwake ? "Awake" : "Asleep"
    }

    /// Active assertion mode shown only while awake. Returns `nil` when
    /// the manager is asleep (no assertion to describe).
    public static func modeLabel(isAwake: Bool, allowDisplaySleep: Bool) -> String? {
        guard isAwake else { return nil }
        return allowDisplaySleep
            ? "System awake (display may sleep)"
            : "System + display awake"
    }

    /// Friendly description of what is currently keeping the Mac awake.
    /// `triggerReason` is the latest `TriggerVote.reason` (e.g. "Calendar:
    /// Standup", "App: Zoom"). Passing `nil` falls back to a generic label
    /// for `.trigger`.
    public static func reasonLabel(
        _ reason: AwakeReason,
        triggerReason: String? = nil
    ) -> String {
        switch reason {
        case .user: return "Manually activated"
        case .trigger:
            if let triggerReason, !triggerReason.isEmpty {
                return triggerReason
            }
            return "Trigger active"
        case .launch: return "Activated at launch"
        case .none: return "Idle"
        }
    }

    /// Power status row. Returns `nil` when the user has not opted into
    /// battery-aware mode (no need to clutter the About tab with power
    /// details unless the user has explicitly engaged the feature).
    public static func powerLabel(isOnAC: Bool, requireACForAwake: Bool) -> String? {
        guard requireACForAwake else { return nil }
        return isOnAC
            ? "On AC power"
            : "On battery — Latte is suspended"
    }
}
