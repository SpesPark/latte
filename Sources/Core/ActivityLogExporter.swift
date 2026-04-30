import Foundation

/// Owner-facing export of the activity log (C-3 deferred C). Pure — never
/// touches the file system. ActivityTab wires the output to `NSSavePanel`.
///
/// CSV uses ISO8601 timestamps for spreadsheet readability; JSON uses the
/// same `secondsSince1970` Double coder as the on-disk log so an export +
/// re-import round-trips losslessly.
public enum ActivityLogExporter {

    public enum Format: String, CaseIterable, Sendable {
        case csv
        case json
    }

    /// Schema-fixed CSV header — keep in lockstep with `ActivityLogEntry`.
    /// A new field would also need a row-emit update below.
    public static let csvHeader = "id,timestamp,triggerId,kind,reasonCode"

    public static func csv(from entries: [ActivityLogEntry]) -> String {
        let rows = entries.map { row(for: $0) }
        return ([csvHeader] + rows).joined(separator: "\n")
    }

    public static func jsonData(from entries: [ActivityLogEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries)
    }

    public static func suggestedFilename(for format: Format, on date: Date = .now) -> String {
        "latte-activity-\(Self.dateStamp.string(from: date)).\(format.rawValue)"
    }

    // MARK: - Internals

    private static func row(for entry: ActivityLogEntry) -> String {
        // None of the fields contain commas, quotes, or newlines (UUID,
        // ISO timestamp, fixed taxonomy strings, enum rawValues) — no
        // escaping needed. The schema-privacy regression test in
        // ActivityLogEntrySchemaTests guards that invariant.
        [
            entry.id.uuidString,
            Self.iso8601.string(from: entry.timestamp),
            entry.triggerId,
            entry.kind.rawValue,
            entry.reasonCode.rawValue
        ].joined(separator: ",")
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
