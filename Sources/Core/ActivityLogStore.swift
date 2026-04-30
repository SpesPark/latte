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
    /// Owner-facing lower/upper bounds on the retention window setting.
    /// 1 day = "show me what fired today only"; 90 days = three months
    /// of history without unbounded file growth on heavy users.
    public static let retentionDayRange: ClosedRange<Int> = 1...90

    private let url: URL
    /// Mutable so the user can adjust retention from Settings (F deferred,
    /// S15) without restarting the app. `setRetention` runs an immediate GC
    /// + flush so a shrink takes effect on the spot.
    private var retention: TimeInterval
    private let logger = LatteLog.activity
    private var entries: [ActivityLogEntry] = []
    private var loaded = false

    /// Initialises the store. The disk read is deferred to the first
    /// `append` / `snapshot` call so this initialiser is synchronous and
    /// can be invoked from `AppEnvironment.init` without an async hop.
    /// Directory existence is the caller's responsibility — see
    /// `defaultDirectory()` for the production path.
    public init(directory: URL, retention: TimeInterval = ActivityLogStore.defaultRetention) {
        self.url = directory.appendingPathComponent(ActivityLogStore.fileName)
        self.retention = retention
    }

    /// Production path: `~/Library/Application Support/Latte/`. Creates the
    /// directory if missing. Returns nil on filesystem failure (sandbox
    /// denial, disk full at directory create) — caller falls back to no
    /// activity logging for the session.
    public static func defaultDirectory() -> URL? {
        let fm = FileManager.default
        do {
            let support = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = support.appendingPathComponent("Latte", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            LatteLog.activity.fault("activity-log: failed to create support directory — \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Appends an entry, GCs older-than-retention rows, and atomically rewrites the file.
    /// Failures are logged and swallowed — never crashes the caller.
    public func append(_ entry: ActivityLogEntry) async {
        loadIfNeeded()
        entries.append(entry)
        gc()
        flush()
    }

    /// Returns a defensive copy of all in-memory entries.
    public func snapshot() async -> [ActivityLogEntry] {
        loadIfNeeded()
        return entries
    }

    /// Returns entries with `timestamp >= since`.
    public func snapshot(since: Date) async -> [ActivityLogEntry] {
        loadIfNeeded()
        return entries.filter { $0.timestamp >= since }
    }

    /// Updates the retention window and immediately GCs entries that no
    /// longer fit, flushing the trimmed set to disk so a subsequent reload
    /// sees the post-shrink state. A grow is a no-op for existing entries.
    public func setRetention(_ newValue: TimeInterval) async {
        loadIfNeeded()
        retention = newValue
        gc()
        flush()
    }

    /// Test/observability hook — returns the current retention in seconds.
    public func currentRetention() async -> TimeInterval { retention }

    /// Empties the store and removes the file.
    public func clear() async {
        loadIfNeeded()
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

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
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
