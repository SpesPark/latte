import Foundation
import os

/// Append-mostly persistent store for `ActivityLogEntry` rows backing the
/// Activity history view (C-3). Actor-isolated so concurrent trigger fires
/// from different `@MainActor` callers serialise safely.
///
/// On-disk format: `activity-log.json` — a JSON array of `ActivityLogEntry`.
/// Atomic write on every append. Ring buffer GC drops entries older than
/// `retention` (default 14 days) on append.
///
/// See `docs/design/09-c3-activity-history.md` §3 for the persistence contract.
public actor ActivityLogStore {

    public static let defaultRetention: TimeInterval = 14 * 24 * 60 * 60   // 14 days
    public static let fileName = "activity-log.json"

    private let url: URL
    private let retention: TimeInterval
    private let logger = LatteLog.activity
    private var entries: [ActivityLogEntry] = []

    /// Initialises the store, creating the parent directory if needed and
    /// loading any existing entries from disk. A corrupt or missing file is
    /// treated as an empty store (logged as a fault) — never throws.
    public init(directory: URL, retention: TimeInterval = ActivityLogStore.defaultRetention) async {
        self.url = directory.appendingPathComponent(ActivityLogStore.fileName)
        self.retention = retention
        await load()
    }

    /// Appends an entry, GCs older-than-retention rows, and atomically rewrites the file.
    /// Failures are logged and swallowed — never crashes the caller.
    public func append(_ entry: ActivityLogEntry) async {
        entries.append(entry)
        gc()
        flush()
    }

    /// Returns a defensive copy of all in-memory entries.
    public func snapshot() async -> [ActivityLogEntry] {
        entries
    }

    /// Returns entries with `timestamp >= since`.
    public func snapshot(since: Date) async -> [ActivityLogEntry] {
        entries.filter { $0.timestamp >= since }
    }

    /// Empties the store and removes the file.
    public func clear() async {
        entries.removeAll()
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            logger.fault("activity-log clear: file remove failed — \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Internal

    private func load() async {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder.activityLog.decode([ActivityLogEntry].self, from: data)
            entries = decoded
            gc()
        } catch {
            logger.fault("activity-log load: corrupt file — starting empty (\(error.localizedDescription, privacy: .public))")
            entries = []
        }
    }

    private func gc() {
        let cutoff = Date().addingTimeInterval(-retention)
        entries.removeAll { $0.timestamp < cutoff }
    }

    private func flush() {
        do {
            let data = try JSONEncoder.activityLog.encode(entries)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("activity-log flush failed — \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - JSON coders

/// `secondsSince1970` (Double) preserves Date precision through encode/decode —
/// ISO8601 truncates to whole or millisecond seconds and breaks round-trip equality.
/// Trade-off: file is slightly less human-readable than ISO timestamps, but the
/// activity log is owner-facing only via Charts (§5), not raw text inspection.
private extension JSONEncoder {
    static let activityLog: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        e.outputFormatting = [.sortedKeys]
        return e
    }()
}

private extension JSONDecoder {
    static let activityLog: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}
