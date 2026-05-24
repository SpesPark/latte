import XCTest
@testable import Latte

/// Domain B (activity log) append-only union merge — pure, CloudKit-free
/// (docs/design/10 §4 B-2, §6, §10). Phase 3 pre-built dark in S43; no live
/// iCloud needed. The load-bearing invariant: this is a **union**, never
/// last-writer-wins — collapsing same-instant entries would destroy real
/// concurrent-day history across two Macs (§6).
final class ActivityLogMergeResolverTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(
        id: UUID = UUID(),
        offset: TimeInterval = 0,
        trigger: String = "wifi",
        kind: ActivityLogEntry.Kind = .on,
        reason: ActivityLogEntry.ReasonCode = .voteOn
    ) -> ActivityLogEntry {
        ActivityLogEntry(
            id: id,
            timestamp: t0.addingTimeInterval(offset),
            triggerId: trigger,
            kind: kind,
            reasonCode: reason
        )
    }

    private func entryAt(_ date: Date, id: UUID = UUID(), trigger: String = "wifi") -> ActivityLogEntry {
        ActivityLogEntry(id: id, timestamp: date, triggerId: trigger, kind: .on, reasonCode: .voteOn)
    }

    // MARK: - Union (no data loss)

    func testDisjointDeviceViewsUnionLosesNothing() {
        let a = [entry(offset: 0), entry(offset: 1)]
        let b = [entry(offset: 2)]
        let merged = ActivityLogMergeResolver.merge(a, b)
        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(Set(merged.map(\.id)), Set((a + b).map(\.id)))
    }

    // MARK: - Dedup / idempotency

    func testEntryPresentOnBothDevicesDedupesToOne() {
        let shared = entry(offset: 5)
        XCTAssertEqual(ActivityLogMergeResolver.merge([shared], [shared]), [shared])
    }

    func testMergeIsIdempotent() {
        let a = [entry(offset: 0), entry(offset: 3)]
        let b = [entry(offset: 1)]
        let once = ActivityLogMergeResolver.merge(a, b)
        XCTAssertEqual(ActivityLogMergeResolver.merge(once, once), once)
    }

    // MARK: - Commutativity / associativity (device wake order must not matter)

    func testMergeIsCommutative() {
        let a = [entry(offset: 0), entry(offset: 5)]
        let b = [entry(offset: 2), entry(offset: 9)]
        XCTAssertEqual(
            ActivityLogMergeResolver.merge(a, b),
            ActivityLogMergeResolver.merge(b, a)
        )
    }

    func testMergeIsAssociative() {
        let a = [entry(offset: 0)]
        let b = [entry(offset: 4)]
        let c = [entry(offset: 8)]
        let left = ActivityLogMergeResolver.merge(ActivityLogMergeResolver.merge(a, b), c)
        let right = ActivityLogMergeResolver.merge(a, ActivityLogMergeResolver.merge(b, c))
        XCTAssertEqual(left, right)
    }

    // MARK: - Never last-writer-wins (the §6 invariant)

    func testSameContentDifferentIdsAreBothKept() {
        // Two Macs each log a wifi-ON at the same instant. An append-only log must
        // keep BOTH — collapsing them (LWW) would destroy real concurrent history.
        let macA = entry(id: UUID(), offset: 42)
        let macB = entry(id: UUID(), offset: 42)
        let merged = ActivityLogMergeResolver.merge([macA], [macB])
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(Set(merged.map(\.id)), [macA.id, macB.id])
    }

    // MARK: - Content-addressed id (collision-freeness + stability)

    func testContentAddressedIDIsStableForIdenticalContent() {
        let id = UUID()
        let e1 = entry(id: id, offset: 7, trigger: "calendar", kind: .off, reason: .voteOff)
        let e2 = entry(id: id, offset: 7, trigger: "calendar", kind: .off, reason: .voteOff)
        XCTAssertEqual(
            ActivityLogMergeResolver.contentAddressedID(for: e1),
            ActivityLogMergeResolver.contentAddressedID(for: e2)
        )
    }

    func testContentAddressedIDDiffersWhenAnyFieldDiffers() {
        let base = entry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            offset: 0, trigger: "wifi", kind: .on, reason: .voteOn
        )
        let baseID = ActivityLogMergeResolver.contentAddressedID(for: base)
        let variants = [
            entry(id: base.id, offset: 1, trigger: "wifi", kind: .on, reason: .voteOn),
            entry(id: base.id, offset: 0, trigger: "calendar", kind: .on, reason: .voteOn),
            entry(id: base.id, offset: 0, trigger: "wifi", kind: .off, reason: .voteOn),
            entry(id: base.id, offset: 0, trigger: "wifi", kind: .on, reason: .voteOff),
            entry(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                  offset: 0, trigger: "wifi", kind: .on, reason: .voteOn),
        ]
        for other in variants {
            XCTAssertNotEqual(baseID, ActivityLogMergeResolver.contentAddressedID(for: other))
        }
    }

    func testContentAddressedIDSurvivesCodableRoundTrip() throws {
        // The id must be stable across a sync round-trip (entry travels to CloudKit
        // and back via the on-disk secondsSince1970 format) or dedup breaks.
        let original = entry(id: UUID(), offset: 123.456789, trigger: "external", kind: .on, reason: .voteOn)
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        let restored = try dec.decode(ActivityLogEntry.self, from: try enc.encode(original))
        XCTAssertEqual(restored, original)
        XCTAssertEqual(
            ActivityLogMergeResolver.contentAddressedID(for: restored),
            ActivityLogMergeResolver.contentAddressedID(for: original)
        )
    }

    func testContentAddressedIDIsLowercaseHexSHA256() {
        let id = ActivityLogMergeResolver.contentAddressedID(for: entry(offset: 0))
        XCTAssertEqual(id.count, 64)
        XCTAssertTrue(id.allSatisfy { $0.isHexDigit && (!$0.isLetter || $0.isLowercase) })
    }

    // MARK: - Canonical ordering / determinism

    func testOutputIsSortedByTimestampRegardlessOfInputOrder() {
        let e0 = entry(offset: 0)
        let e1 = entry(offset: 10)
        let e2 = entry(offset: 20)
        let merged = ActivityLogMergeResolver.merge([[e2, e0], [e1]])
        XCTAssertEqual(merged.map(\.id), [e0.id, e1.id, e2.id])
    }

    func testMergeIsDeterministic() {
        let a = [entry(offset: 3), entry(offset: 1)]
        let b = [entry(offset: 2)]
        XCTAssertEqual(
            ActivityLogMergeResolver.merge(a, b),
            ActivityLogMergeResolver.merge(a, b)
        )
    }

    // MARK: - Empty inputs

    func testMergeOfNothingIsEmpty() {
        XCTAssertEqual(ActivityLogMergeResolver.merge([]), [])
        XCTAssertEqual(ActivityLogMergeResolver.merge([[], []]), [])
        XCTAssertEqual(ActivityLogMergeResolver.merge([], []), [])
    }

    func testPruneOfNothingIsEmpty() {
        XCTAssertEqual(ActivityLogMergeResolver.pruned([], now: t0), [])
    }

    // MARK: - GC after merge (mirrors ActivityLogStore.gc: strictly-older dropped)

    func testPrunedDropsEntriesOlderThanRetention() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let retention: TimeInterval = 14 * 86_400
        let old = entryAt(now.addingTimeInterval(-15 * 86_400))
        let recent = entryAt(now.addingTimeInterval(-1 * 86_400))
        let result = ActivityLogMergeResolver.pruned([old, recent], now: now, retention: retention)
        XCTAssertEqual(result, [recent])
    }

    func testPrunedKeepsEntryExactlyAtCutoff() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let retention: TimeInterval = 14 * 86_400
        let boundary = entryAt(now.addingTimeInterval(-retention))
        XCTAssertEqual(
            ActivityLogMergeResolver.pruned([boundary], now: now, retention: retention),
            [boundary]
        )
    }

    func testPrunedUsesFourteenDayDefaultRetention() {
        // Confirms the default tracks ActivityLogStore.defaultRetention (14 days).
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let justInside = entryAt(now.addingTimeInterval(-13.5 * 86_400))
        let justOutside = entryAt(now.addingTimeInterval(-14.5 * 86_400))
        let result = ActivityLogMergeResolver.pruned([justInside, justOutside], now: now)
        XCTAssertEqual(result, [justInside])
    }

    func testMergedAndPrunedUnionsThenGarbageCollects() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let shared = entryAt(now.addingTimeInterval(-2 * 86_400),
                             id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!)
        let oldA = entryAt(now.addingTimeInterval(-30 * 86_400))
        let freshB = entryAt(now.addingTimeInterval(-1 * 86_400))
        let result = ActivityLogMergeResolver.mergedAndPruned([[oldA, shared], [shared, freshB]], now: now)
        // old dropped, shared deduped, fresh kept → sorted ascending by timestamp.
        XCTAssertEqual(result, [shared, freshB])
    }
}
