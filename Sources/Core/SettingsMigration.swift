import Foundation

/// The storage trichotomy each `SettingsKey` maps to (04-data-model §3.2).
/// Drives the migration snapshot's typed read.
public enum SettingsValueType: Equatable, Sendable {
    case bool
    case int
    case double
    case string
    case data
}

public extension SettingsKey {
    /// Authoritative per-key storage type. The exhaustive `switch` is
    /// compiler-enforced: a new `SettingsKey` added without a classification
    /// fails the build — a structural drift guard for the migration
    /// (cf. 04-data-model §2.2's "no automatic introspection" copy).
    var valueType: SettingsValueType {
        switch self {
        // Bool
        case .firstRunCompleted, .lastQuitCleanly, .allowDisplaySleep,
             .activateOnLaunch, .launchAtLogin, .calendarTriggerEnabled,
             .calendarTriggerExcludeAllDay, .appTriggerEnabled, .hasSeededAppDefaults,
             .wifiTriggerEnabled, .wifiTriggerInverseLogic, .focusTriggerEnabled,
             .scheduleTriggerEnabled, .externalDisplayEnabled, .requireACForAwake,
             .triggersPaused, .keyboardShortcutEnabled, .didSeedBuiltinPresets:
            return .bool
        // Int
        case .schemaVersion, .calendarTriggerLeadTimeMinutes,
             .calendarTriggerTrailingMinutes, .activityRetentionDays:
            return .int
        // Double
        case .firstRunCompletedAt:
            return .double
        // String
        case .menuBarIconStyle, .coffeeAccent:
            return .string
        // Data (JSON-encoded arrays / objects / KeyChord)
        case .calendarTriggerCalendarIDs, .appTriggerBundleIDs, .wifiTriggerSSIDs,
             .focusTriggerFocusIDs, .scheduleTriggerEntries, .externalDisplayWhitelist,
             .shortcutChord, .activityChartColors, .recurringQuickPresets:
            return .data
        }
    }
}

/// A single migrated settings value, tagged by its storage type. Codable so the
/// snapshot serialises to a stable cross-device wire form.
public enum SettingsValue: Equatable, Sendable, Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case data(Data)
}

/// One migrated record: `SettingsKey.rawValue` + its value + the write time.
/// Mirrors the `GeneralSetting` SwiftData entity sketch (04-data-model §2.2),
/// kept as a plain value type so the transform stays on macOS 13.
public struct SettingsSnapshotEntry: Equatable, Sendable, Codable {
    public let key: String
    public let value: SettingsValue
    public let updatedAt: Date

    public init(key: String, value: SettingsValue, updatedAt: Date) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

/// The full v2 settings snapshot: the new schema version plus one entry per
/// present key. The S8.5-gated activation writes these into the SwiftData
/// model container; this pure transform is the risk-bearing part.
public struct SettingsSnapshot: Equatable, Sendable, Codable {
    public let schemaVersion: Int
    public let entries: [SettingsSnapshotEntry]

    public init(schemaVersion: Int, entries: [SettingsSnapshotEntry]) {
        self.schemaVersion = schemaVersion
        self.entries = entries
    }
}

/// OQ-04 UserDefaults → SwiftData migration (04-data-model §2.2, docs/design/10
/// §3). **Pure and CloudKit-free** (§10): pre-built dark in S42 ahead of the
/// S8.5-gated activation. This builds the typed v2 snapshot; persisting it into
/// a SwiftData `@Model` container (which forces macOS 14) is the activation step.
public enum SettingsMigration {

    /// Target schema version (04-data-model §2.2 step 4).
    public static let targetSchemaVersion = 2

    /// The store's current schema version. Defaults to `1` when absent: the
    /// shipped v1.x app never wrote `schemaVersion`, so an existing install
    /// reads as v1 (not "fresh") — the doc's "absent → fresh install"
    /// assumption predates that fact and is corrected here.
    public static func currentSchemaVersion(in store: SettingsStore) -> Int {
        store.integer(.schemaVersion, default: 1)
    }

    /// Whether a migration to the target version is warranted.
    public static func needsMigration(_ store: SettingsStore) -> Bool {
        currentSchemaVersion(in: store) < targetSchemaVersion
    }

    /// Snapshot every **present** key into a typed record set, stamping
    /// `schemaVersion = 2` and a uniform `now` write time. Absent keys are
    /// omitted (preserves "never touched = default"); `schemaVersion` itself is
    /// represented by the top-level field, not a copied entry.
    ///
    /// ⚠️ **Activation contract (RFC L1 — S51 audit):** the caller must run
    /// this EXACTLY ONCE per upgrade and then write `schemaVersion = 2` back
    /// to **this** `SettingsStore` (UserDefaults), not only to the SwiftData
    /// container — `needsMigration` reads from the store, so skipping that
    /// write re-runs the migration every launch, re-stamping all entries with
    /// a fresh uniform `now` and clobbering per-key LWW provenance.
    public static func snapshot(from store: SettingsStore, now: Date) -> SettingsSnapshot {
        let entries = SettingsKey.allCases.compactMap { key -> SettingsSnapshotEntry? in
            guard key != .schemaVersion, store.exists(key) else { return nil }
            guard let value = readValue(key, from: store) else { return nil }
            return SettingsSnapshotEntry(key: key.rawValue, value: value, updatedAt: now)
        }
        return SettingsSnapshot(schemaVersion: targetSchemaVersion, entries: entries)
    }

    private static func readValue(_ key: SettingsKey, from store: SettingsStore) -> SettingsValue? {
        switch key.valueType {
        case .bool:   return .bool(store.bool(key, default: false))
        case .int:    return .int(store.integer(key, default: 0))
        case .double: return .double(store.double(key, default: 0))
        case .string: return store.string(key).map(SettingsValue.string)
        case .data:   return store.data(key).map(SettingsValue.data)
        }
    }
}
