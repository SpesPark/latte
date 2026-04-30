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

        let store = await ActivityLogStore(directory: dir)
        let entry = makeEntry(triggerId: "wifi", kind: .on, reasonCode: .voteOn)
        await store.append(entry)

        let snap1 = await store.snapshot()
        XCTAssertEqual(snap1.count, 1)
        XCTAssertEqual(snap1.first, entry)

        // Reload from disk via a new instance — entry must survive.
        let reloaded = await ActivityLogStore(directory: dir)
        let snap2 = await reloaded.snapshot()
        XCTAssertEqual(snap2.count, 1)
        XCTAssertEqual(snap2.first, entry)
    }

    func testGCDropsEntriesOlderThanRetention() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        // Tight 1-second retention so the test runs fast.
        let store = await ActivityLogStore(directory: dir, retention: 1.0)
        let stale = makeEntry(timestamp: Date(timeIntervalSinceNow: -3600))   // 1h ago
        let fresh = makeEntry(timestamp: .now)
        await store.append(stale)
        await store.append(fresh)

        let snap = await store.snapshot()
        XCTAssertEqual(snap.count, 1, "GC must drop the 1-hour-old entry under 1s retention")
        XCTAssertEqual(snap.first?.id, fresh.id)
    }

    func testConcurrentAppendsAllPersist() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = await ActivityLogStore(directory: dir)

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

        let store = await ActivityLogStore(directory: dir)
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

        let store = await ActivityLogStore(directory: dir)
        await store.append(makeEntry())
        await store.append(makeEntry(triggerId: "calendar"))

        await store.clear()
        let snap = await store.snapshot()
        XCTAssertTrue(snap.isEmpty)

        // File should be gone (or empty) — verify reload is also empty.
        let reloaded = await ActivityLogStore(directory: dir)
        let snap2 = await reloaded.snapshot()
        XCTAssertTrue(snap2.isEmpty)
    }

    func testInitFromMissingFileReturnsEmptyStore() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        // No write happens before init — file does not exist.
        let store = await ActivityLogStore(directory: dir)
        let snap = await store.snapshot()
        XCTAssertTrue(snap.isEmpty)
    }

    func testInitFromCorruptFileReturnsEmptyStore() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        // Plant a corrupt JSON file at the expected path.
        let url = dir.appendingPathComponent(ActivityLogStore.fileName)
        try Data("not valid json {{{".utf8).write(to: url)

        let store = await ActivityLogStore(directory: dir)
        let snap = await store.snapshot()
        XCTAssertTrue(snap.isEmpty, "corrupt file must be treated as empty, not crash")
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
