import CryptoKit
import Foundation

/// Append-only **union merge** for the activity log — **Domain B** conflict
/// resolution (docs/design/10 §4 B-2, §6, §10). Pure and CloudKit-free (§10):
/// the production `CloudKitSyncEngine` drives this, so the regression-bearing
/// merge logic stays unit-testable without a live iCloud account. Pre-built dark
/// in S43 ahead of the S8.5-gated activation (Phase 3, v2.1 per §12 Q5).
///
/// **Never last-writer-wins.** §6: the activity log is an append-only event log;
/// LWW silently destroys concurrent-day history when two Macs are awake the same
/// day. Sync-in is the *union* of every device's immutable entries, deduplicated
/// by a stable content-addressed id, then the existing 14-day ring-buffer GC runs
/// locally on the merged set. This type is the structural counterpart to
/// `SettingsLWWResolver` (Domain A) — the two-domain split exists so the log can
/// never reach an LWW path.
///
/// The merge is **commutative, associative, and idempotent**, so device wake
/// order does not matter and re-syncing an already-merged set is a no-op. The
/// result is returned in a single canonical order (timestamp, then id) so those
/// algebraic properties hold as plain array equality.
public enum ActivityLogMergeResolver {

    /// Stable, content-addressed identity for one entry → the CloudKit record name
    /// at activation (§4 B-2: "SHA-256 of the immutable tuple"). Derived from the
    /// entry's full immutable content, so it is:
    /// - **stable** across a sync round-trip (every field is immutable and the
    ///   `ActivityLogEntry` initialiser quantises the timestamp to microseconds,
    ///   matching the on-disk `secondsSince1970` precision);
    /// - **collision-free** for genuinely distinct events (the per-event `id` UUID
    ///   is part of the digest input), while
    /// - **identical** for byte-identical duplicates (the same entry arriving from
    ///   both the local cache and its own CloudKit echo) — which is exactly the
    ///   dedup key the union merge needs.
    ///
    /// 64-char lowercase hex: a valid `CKRecord.recordName` with no further
    /// transform required at activation.
    public static func contentAddressedID(for entry: ActivityLogEntry) -> String {
        let micros = Int64((entry.timestamp.timeIntervalSince1970 * 1_000_000).rounded())
        let canonical = "\(micros)|\(entry.triggerId)|\(entry.kind.rawValue)|\(entry.reasonCode.rawValue)|\(entry.id.uuidString)"
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Union-merges any number of device views of the append-only log into one
    /// deduplicated, canonically ordered set (§4 B-2). Entries sharing a
    /// `contentAddressedID` collapse to one; everything else is retained.
    public static func merge(_ sources: [[ActivityLogEntry]]) -> [ActivityLogEntry] {
        var seen = Set<String>()
        var unique: [ActivityLogEntry] = []
        for source in sources {
            for entry in source where seen.insert(contentAddressedID(for: entry)).inserted {
                unique.append(entry)
            }
        }
        return canonicallyOrdered(unique)
    }

    /// Two-view convenience over `merge(_:)`. `merge(a, b) == merge(b, a)`.
    public static func merge(_ a: [ActivityLogEntry], _ b: [ActivityLogEntry]) -> [ActivityLogEntry] {
        merge([a, b])
    }

    /// The existing 14-day ring-buffer GC as a pure function over the merged set
    /// (mirrors `ActivityLogStore.gc` exactly: drop entries *strictly older* than
    /// `now - retention`, keep the boundary). `now` is injected for determinism.
    public static func pruned(
        _ entries: [ActivityLogEntry],
        now: Date,
        retention: TimeInterval = ActivityLogStore.defaultRetention
    ) -> [ActivityLogEntry] {
        let cutoff = now.addingTimeInterval(-retention)
        return entries.filter { $0.timestamp >= cutoff }
    }

    /// The full Domain B sync-in transform: union-merge every device view, then run
    /// the local retention GC on the merged set (§4 B-2: "the existing 14-day GC
    /// runs locally on the merged set"). Order preserved from `merge(_:)`.
    public static func mergedAndPruned(
        _ sources: [[ActivityLogEntry]],
        now: Date,
        retention: TimeInterval = ActivityLogStore.defaultRetention
    ) -> [ActivityLogEntry] {
        pruned(merge(sources), now: now, retention: retention)
    }

    // MARK: - Internal

    /// Total, input-order-independent ordering (timestamp ascending, then the
    /// content-addressed id as a tie-break) so union merge is commutative and
    /// associative as array equality.
    private static func canonicallyOrdered(_ entries: [ActivityLogEntry]) -> [ActivityLogEntry] {
        entries.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
            return contentAddressedID(for: lhs) < contentAddressedID(for: rhs)
        }
    }
}
