import XCTest
@testable import Latte

final class ActivityLogStoreTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a fresh, empty temp directory unique to this test invocation.
    /// Caller is responsible for cleanup.
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LatteActivityLogStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeEntry(
        triggerId: String = "wifi",
        kind: ActivityLogEntry.Kind = .on,
        reasonCode: ActivityLogEntry.ReasonCode = .voteOn,
        timestamp: Date = .now
    ) -> ActivityLogEntry {
        ActivityLogEntry(
            timestamp: timestamp,
            triggerId: triggerId,
            kind: kind,
            reasonCode: reasonCode
        )
    }

    // MARK: - Tests

    func testAppendsEntryAndPersistsAcrossReloads() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ActivityLogStore(directory: dir)
        let entry = makeEntry(triggerId: "wifi", kind: .on, reasonCode: .voteOn)
        await store.append(entry)

        let snap1 = await store.snapshot()
        XCTAssertEqual(snap1.count, 1)
        XCTAssertEqual(snap1.first, entry)

        // Reload from disk via a new instance — entry must survive.
        let reloaded = ActivityLogStore(directory: dir)
        let snap2 = await reloaded.snapshot()
        XCTAssertEqual(snap2.count, 1)
        XCTAssertEqual(snap2.first, entry)
    }

    func testGCDropsEntriesOlderThanRetention() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        // Tight 1-second retention so the test runs fast.
        let store = ActivityLogStore(directory: dir, retention: 1.0)
        let stale = makeEntry(timestamp: Date(timeIntervalSinceNow: -3600))   // 1h ago
        let fresh = makeEntry(timestamp: .now)
        await store.append(stale)
        await store.append(fresh)

        let snap = await store.snapshot()
        XCTAssertEqual(snap.count, 1, "GC must drop the 1-hour-old entry under 1s retention")
        XCTAssertEqual(snap.first?.id, fresh.id)
    }

    /// Pins the cutoff boundary far tighter than the coarse 1h-vs-1s test
    /// above: ±10 s around `now - retention`. (`gc` removes strictly-older
    /// (`timestamp < cutoff`) entries, but `Date()` advances between entry
    /// construction and the gc call, so the boundary is pinned via margins
    /// rather than exact equality — S51 audit.)
    func testGCBoundaryTenSecondsEitherSideOfCutoff() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ActivityLogStore(directory: dir, retention: 3600)
        let justInside = makeEntry(timestamp: Date(timeIntervalSinceNow: -3600 + 10))
        let justOutside = makeEntry(timestamp: Date(timeIntervalSinceNow: -3600 - 10))
        await store.append(justOutside)
        await store.append(justInside)

        let snap = await store.snapshot()
        XCTAssertEqual(snap.count, 1, "10s outside retention must drop; 10s inside must survive")
        XCTAssertEqual(snap.first?.id, justInside.id)
    }

    func testConcurrentAppendsAllPersist() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ActivityLogStore(directory: dir)

        // Fire 20 concurrent appends — actor isolation must serialise without loss.
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    let e = ActivityLogEntry(
                        timestamp: Date(timeIntervalSinceNow: -Double(i)),
                        triggerId: "concurrent-\(i)",
                        kind: .on,
                        reasonCode: .voteOn
                    )
                    await store.append(e)
                }
            }
        }

        let snap = await store.snapshot()
        XCTAssertEqual(snap.count, 20, "all concurrent appends must be retained")
    }

    func testSnapshotSinceFiltersByDate() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ActivityLogStore(directory: dir)
        let old = makeEntry(timestamp: Date(timeIntervalSinceNow: -1000))
        let recent = makeEntry(timestamp: Date(timeIntervalSinceNow: -10))
        await store.append(old)
        await store.append(recent)

        let cutoff = Date(timeIntervalSinceNow: -100)
        let filtered = await store.snapshot(since: cutoff)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, recent.id)
    }

    func testClearEmptiesStoreAndFile() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ActivityLogStore(directory: dir)
        await store.append(makeEntry())
        await store.append(makeEntry(triggerId: "calendar"))

        await store.clear()
        let snap = await store.snapshot()
        XCTAssertTrue(snap.isEmpty)

        // File should be gone (or empty) — verify reload is also empty.
        let reloaded = ActivityLogStore(directory: dir)
        let snap2 = await reloaded.snapshot()
        XCTAssertTrue(snap2.isEmpty)
    }

    func testInitFromMissingFileReturnsEmptyStore() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        // No write happens before init — file does not exist.
        let store = ActivityLogStore(directory: dir)
        let snap = await store.snapshot()
        XCTAssertTrue(snap.isEmpty)
    }

    func testInitFromCorruptFileReturnsEmptyStore() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        // Plant a corrupt JSON file at the expected path.
        let url = dir.appendingPathComponent(ActivityLogStore.fileName)
        try Data("not valid json {{{".utf8).write(to: url)

        let store = ActivityLogStore(directory: dir)
        let snap = await store.snapshot()
        XCTAssertTrue(snap.isEmpty, "corrupt file must be treated as empty, not crash")
    }

    // MARK: - F: customisable retention window (S15)

    func testSetRetentionShrinksWindowAndGCsImmediately() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        // Start with a 1-day retention, then shrink to 1 second — the 12h-old
        // entry must be GCed by the shrink, not wait for the next append.
        let store = ActivityLogStore(directory: dir, retention: 86_400)
        let stale = makeEntry(timestamp: Date(timeIntervalSinceNow: -43_200))   // 12h ago
        let fresh = makeEntry(timestamp: .now)
        await store.append(stale)
        await store.append(fresh)
        let preCount = await store.snapshot().count
        XCTAssertEqual(preCount, 2)

        await store.setRetention(1.0)
        let snap = await store.snapshot()
        XCTAssertEqual(snap.count, 1, "shrinking retention must GC stale entries on the spot")
        XCTAssertEqual(snap.first?.id, fresh.id)
    }

    func testSetRetentionGrowsWindowKeepsExistingEntries() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ActivityLogStore(directory: dir, retention: 1.0)
        let fresh = makeEntry(timestamp: .now)
        await store.append(fresh)

        await store.setRetention(86_400 * 30)
        let snap = await store.snapshot()
        XCTAssertEqual(snap.count, 1, "growing retention is a no-op for existing entries")
    }

    func testSetRetentionPersistsAcrossReloads() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        // Retention is a runtime knob (not file-persisted) — but the post-GC
        // entries set must be on disk so a reload sees the GCed shape.
        let store = ActivityLogStore(directory: dir, retention: 86_400)
        await store.append(makeEntry(timestamp: Date(timeIntervalSinceNow: -43_200)))
        await store.append(makeEntry(timestamp: .now))
        await store.setRetention(1.0)

        let reloaded = ActivityLogStore(directory: dir, retention: 86_400)
        let snap = await reloaded.snapshot()
        XCTAssertEqual(snap.count, 1, "shrink-GC must flush, so a reload sees the trimmed entries")
    }
}

// MARK: - AwakeSegment merge (heatmap union — 7th simplify-pass MED-2 regression gate)

final class AwakeSegmentMergeTests: XCTestCase {

    /// Two triggers fire in parallel — heatmap must count their union, not
    /// double-count the overlap. Single-stream pairing would mis-attribute
    /// the second trigger's OFF to the first trigger's ON.
    func testParallelTriggerSegmentsMergeIntoUnion() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let entries: [ActivityLogEntry] = [
            // Wifi: ON 0:00 → OFF 1:00
            .init(timestamp: now, triggerId: "wifi", kind: .on, reasonCode: .voteOn),
            .init(timestamp: now.addingTimeInterval(3600), triggerId: "wifi", kind: .off, reasonCode: .voteOff),
            // Calendar: ON 0:30 → OFF 1:30 (overlaps wifi)
            .init(timestamp: now.addingTimeInterval(1800), triggerId: "calendar", kind: .on, reasonCode: .voteOn),
            .init(timestamp: now.addingTimeInterval(5400), triggerId: "calendar", kind: .off, reasonCode: .voteOff)
        ]

        // Per-trigger pair → merge.
        let byTrigger = Dictionary(grouping: entries, by: \.triggerId)
        var segs: [AwakeSegment] = []
        for (_, rows) in byTrigger {
            segs += AwakeSegment.pair(
                rows.sorted { $0.timestamp < $1.timestamp },
                windowStart: now,
                windowEnd: now.addingTimeInterval(7200)
            )
        }
        let merged = AwakeSegment.merge(segs.sorted { $0.start < $1.start })

        XCTAssertEqual(merged.count, 1, "overlapping segments must collapse")
        let total = merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        XCTAssertEqual(total, 5400, "union of [0,3600]+[1800,5400] = [0,5400] (90 min)")
    }

    func testNonOverlappingSegmentsAreNotMerged() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let segs = [
            AwakeSegment(start: now, end: now.addingTimeInterval(600)),
            AwakeSegment(start: now.addingTimeInterval(1200), end: now.addingTimeInterval(1800))
        ]
        let merged = AwakeSegment.merge(segs)
        XCTAssertEqual(merged.count, 2, "disjoint segments must remain distinct")
    }

    func testTouchingSegmentsAreMerged() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let segs = [
            AwakeSegment(start: now, end: now.addingTimeInterval(600)),
            AwakeSegment(start: now.addingTimeInterval(600), end: now.addingTimeInterval(1200))
        ]
        let merged = AwakeSegment.merge(segs)
        XCTAssertEqual(merged.count, 1, "back-to-back segments must merge")
    }
}

// MARK: - ActivityLogEntry schema privacy contract

final class ActivityLogEntrySchemaTests: XCTestCase {

    /// Privacy contract per design doc §6: only fixed-vocabulary fields persist.
    /// If a future refactor accidentally adds a free-text "reason" or "appName"
    /// field, this test fails — protecting App Store privacy label.
    func testJSONEncodingHasOnlyAllowedKeys() throws {
        let entry = ActivityLogEntry(
            timestamp: .now,
            triggerId: "wifi",
            kind: .on,
            reasonCode: .voteOn
        )
        let data = try JSONEncoder().encode(entry)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let keys = Set(json?.keys ?? [:].keys)
        XCTAssertEqual(keys, ["id", "timestamp", "triggerId", "kind", "reasonCode"],
                       "schema must not gain free-text fields — see 09-c3 §6 privacy")
    }
}
