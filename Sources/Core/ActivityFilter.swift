import Foundation

/// Selection state for the per-trigger filter picker in ActivityTab
/// (C-3 deferred B). `.all` is the default; `.only(triggerId)` narrows the
/// charts + export to a single trigger.
public enum ActivityFilter: Hashable, Sendable {
    case all
    case only(String)

    /// Filters a snapshot down to the entries this filter accepts.
    public func apply(to entries: [ActivityLogEntry]) -> [ActivityLogEntry] {
        switch self {
        case .all:
            return entries
        case .only(let id):
            return entries.filter { $0.triggerId == id }
        }
    }

    /// Returns the sorted unique trigger IDs present in `entries`. Used to
    /// build picker options dynamically — a fresh install with no schedule
    /// trigger entries yet won't show "Schedule" as a filter option.
    public static func triggerIdsObserved(in entries: [ActivityLogEntry]) -> [String] {
        Array(Set(entries.map(\.triggerId))).sorted()
    }

    /// Maps a kebab-case trigger ID to a Title-Cased UI label. Trigger IDs
    /// are an invariant lowercase-ASCII taxonomy (see `Trigger.id` callers),
    /// so a manual per-word upper-case avoids `.capitalized`'s locale
    /// surprises while staying obvious to a future reader.
    public static func label(for triggerId: String) -> String {
        triggerId
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
