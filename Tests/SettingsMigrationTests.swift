import XCTest
@testable import Latte

/// OQ-04 settings migration transform — pure, CloudKit-free (docs/design/04 §2.2,
/// docs/design/10 §3/§10). Pre-built dark in S42 as a plain Codable snapshot so
/// it stays on the macOS 13 deployment target; the SwiftData `@Model` write is
/// the S8.5-gated activation step. The transform is the risk-bearing part: it
/// must faithfully enumerate every `SettingsKey.allCases` value.
final class SettingsMigrationTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - valueType classification

    func testValueTypeClassifiesTrichotomy() {
        XCTAssertEqual(SettingsKey.allowDisplaySleep.valueType, .bool)
        XCTAssertEqual(SettingsKey.activityRetentionDays.valueType, .int)
        XCTAssertEqual(SettingsKey.firstRunCompletedAt.valueType, .double)
        XCTAssertEqual(SettingsKey.menuBarIconStyle.valueType, .string)
        XCTAssertEqual(SettingsKey.shortcutChord.valueType, .data)
    }

    func testEveryKeyHasAValueType() {
        // The switch is exhaustive (compiler-enforced); this asserts allCases
        // can be classified without trapping and documents the live key count.
        for key in SettingsKey.allCases {
            _ = key.valueType
        }
        XCTAssertEqual(SettingsKey.allCases.count, 34)
    }

    // MARK: - snapshot copies present values by type

    func testSnapshotCopiesBool() {
        let store = InMemorySettingsStore(initial: [.allowDisplaySleep: true])
        let snap = SettingsMigration.snapshot(from: store, now: now)
        XCTAssertEqual(entry(snap, .allowDisplaySleep)?.value, .bool(true))
    }

    func testSnapshotCopiesInt() {
        let store = InMemorySettingsStore(initial: [.activityRetentionDays: 30])
        let snap = SettingsMigration.snapshot(from: store, now: now)
        XCTAssertEqual(entry(snap, .activityRetentionDays)?.value, .int(30))
    }

    func testSnapshotCopiesDouble() {
        let store = InMemorySettingsStore(initial: [.firstRunCompletedAt: 1234.5])
        let snap = SettingsMigration.snapshot(from: store, now: now)
        XCTAssertEqual(entry(snap, .firstRunCompletedAt)?.value, .double(1234.5))
    }

    func testSnapshotCopiesString() {
        let store = InMemorySettingsStore(initial: [.menuBarIconStyle: "outline"])
        let snap = SettingsMigration.snapshot(from: store, now: now)
        XCTAssertEqual(entry(snap, .menuBarIconStyle)?.value, .string("outline"))
    }

    func testSnapshotCopiesData() {
        let blob = Data([0xDE, 0xAD])
        let store = InMemorySettingsStore(initial: [.shortcutChord: blob])
        let snap = SettingsMigration.snapshot(from: store, now: now)
        XCTAssertEqual(entry(snap, .shortcutChord)?.value, .data(blob))
    }

    // MARK: - absence + version semantics

    func testSnapshotOmitsAbsentKeys() {
        let store = InMemorySettingsStore(initial: [.allowDisplaySleep: true])
        let snap = SettingsMigration.snapshot(from: store, now: now)
        XCTAssertNil(entry(snap, .triggersPaused),
                     "Absent keys must stay absent — preserves 'never touched = default'")
    }

    func testSnapshotStampsTargetSchemaVersionAndExcludesVersionKey() {
        let store = InMemorySettingsStore(initial: [.schemaVersion: 1, .allowDisplaySleep: true])
        let snap = SettingsMigration.snapshot(from: store, now: now)
        XCTAssertEqual(snap.schemaVersion, 2)
        XCTAssertNil(entry(snap, .schemaVersion),
                     "schemaVersion rides the top-level field, not a copied entry")
    }

    func testSnapshotStampsUniformUpdatedAt() {
        let store = InMemorySettingsStore(initial: [.allowDisplaySleep: true, .activityRetentionDays: 7])
        let snap = SettingsMigration.snapshot(from: store, now: now)
        for e in snap.entries { XCTAssertEqual(e.updatedAt, now) }
    }

    // MARK: - migration gating (schemaVersion never written in v1.x)

    func testNeedsMigrationTrueForV1Store() {
        // A real shipped v1.x install never wrote schemaVersion, so it reads as
        // the v1 default (1) < target (2) → must migrate.
        let store = InMemorySettingsStore(initial: [.firstRunCompleted: true])
        XCTAssertTrue(SettingsMigration.needsMigration(store))
    }

    func testNeedsMigrationFalseWhenAlreadyAtTarget() {
        let store = InMemorySettingsStore(initial: [.schemaVersion: 2])
        XCTAssertFalse(SettingsMigration.needsMigration(store))
    }

    // MARK: - Codable round-trip (cross-device wire stability)

    func testSnapshotRoundTripsThroughJSON() throws {
        let store = InMemorySettingsStore(initial: [
            .allowDisplaySleep: true,
            .activityRetentionDays: 21,
            .menuBarIconStyle: "clock",
            .shortcutChord: Data([0x01, 0x02]),
        ])
        let snap = SettingsMigration.snapshot(from: store, now: now)
        let encoded = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(SettingsSnapshot.self, from: encoded)
        XCTAssertEqual(decoded, snap)
    }

    // MARK: - parity across the full key set (RFC §10)

    func testSnapshotCoversEveryPresentKey() {
        // Seed one representative value for every key, then assert the snapshot
        // round-trips all of them (minus the version key) with no key dropped.
        var initial: [SettingsKey: Any] = [:]
        for key in SettingsKey.allCases where key != .schemaVersion {
            switch key.valueType {
            case .bool: initial[key] = true
            case .int: initial[key] = 5
            case .double: initial[key] = 1.5
            case .string: initial[key] = "x"
            case .data: initial[key] = Data([0x7F])
            }
        }
        let store = InMemorySettingsStore(initial: initial)
        let snap = SettingsMigration.snapshot(from: store, now: now)

        let migratedKeys = Set(snap.entries.map(\.key))
        let expected = Set(SettingsKey.allCases.filter { $0 != .schemaVersion }.map(\.rawValue))
        XCTAssertEqual(migratedKeys, expected, "Every present key (except schemaVersion) must migrate")
    }

    // MARK: - exists() store contract

    func testExistsReflectsPresence() {
        let store = InMemorySettingsStore(initial: [.allowDisplaySleep: true])
        XCTAssertTrue(store.exists(.allowDisplaySleep))
        XCTAssertFalse(store.exists(.triggersPaused))
        store.setBool(false, for: .triggersPaused)
        XCTAssertTrue(store.exists(.triggersPaused))
        store.remove(.triggersPaused)
        XCTAssertFalse(store.exists(.triggersPaused))
    }

    // MARK: - helper

    private func entry(_ snap: SettingsSnapshot, _ key: SettingsKey) -> SettingsSnapshotEntry? {
        snap.entries.first { $0.key == key.rawValue }
    }
}
