# 04 — Data Model

| Field | Value |
|---|---|
| **Document version** | 0.2 |
| **Status** | Approved (sign-off at session 2 close); §4.5 footnote added at session 4 |
| **Resolves Open Questions** | OQ-03 (where do trigger configs live?), OQ-04 (UserDefaults → SwiftData migration path) |
| **Depends on** | 01-PRD.md, 02-architecture.md (esp. §4.3 `SettingsStore`), 03-state-machine.md |
| **Last updated** | 2026-04-26 |

---

## 1. Purpose & scope

This doc defines **all persistent state** that survives across app launches:

- user preferences (display sleep mode, launch at login, …),
- per-trigger enable flags and configs (calendar IDs, app bundle IDs, SSIDs, focus IDs),
- schema versioning so we can evolve safely.

Out of scope:
- **Awake state itself** is *not* persisted. Per 03-state-machine.md §8.6, every cold launch starts in `Asleep`. This is intentional.
- **Calendar event data** is read-only at runtime via `EKEventStore` — never copied into our store.
- **Wi-Fi network details** and **running apps** are queried live; we only persist user-selected SSIDs/bundle IDs.

---

## 2. Resolved Open Questions

### 2.1 OQ-03 — UserDefaults vs SwiftData for v1

**Question**: Where do trigger configs live for v1 launch?

**Decision**: **UserDefaults**, accessed through the `SettingsStore` protocol from 02-architecture.md §4.3.

**Rationale**:
- **Simple**: a 1-developer menu-bar utility doesn't need a query engine. Configs are at most ~100 entries (calendar IDs × triggers × per-user limits).
- **Apple-blessed for menu-bar utilities**: `UserDefaults` is the documented persistence path for `LSUIElement` apps and is fully sandbox-safe.
- **No schema migrations** in v1: adding a new key with a default is a one-line change. SwiftData migrations require explicit migration plans even for trivial changes.
- **No external dependencies**: SwiftData requires macOS 14+; we target macOS 13.
- **Testable**: `InMemorySettingsStore` (an in-process dict) implements the same protocol; tests don't touch disk.

**Trade-off accepted**: UserDefaults gives us no transactional writes, no relational queries, no iCloud sync. None of these matter for v1. They matter for v2 (Phase 2 cross-device).

### 2.2 OQ-04 — Migration to SwiftData for Phase 2

**Question**: How do we migrate from UserDefaults to SwiftData when Phase 2 adds iCloud sync?

**Decision**: **Migrate at first launch of v2.0 via a one-time copy.** UserDefaults stays around as a fallback during the transition window (one minor version, then removed).

**Migration plan** (executes once on first v2.0 launch):

1. Read `schemaVersion` from UserDefaults, **treating an absent value as `1`** — the shipped v1.x app never wrote this key, so an existing install reads as v1, **not** as a fresh install. Migrate whenever the (possibly-defaulted) value is `< 2`. (On a genuinely fresh v2.0 install the read is also `1`, but the copy in step 3 finds no present keys — a harmless no-op — and step 4 then stamps `2`. The pre-built `SettingsMigration.currentSchemaVersion` already defaults absent → `1`; this step matches it. Earlier drafts said "absent → fresh → skip", which would have skipped migrating every real upgrading user — corrected.)
2. Open SwiftData store.
3. For each `SettingsKey`, read from UserDefaults, decode into a typed `Setting` model entity, save to SwiftData.
4. Write `schemaVersion = 2` to SwiftData.
5. Mark `migrationCompleted = true` in UserDefaults.
6. Future launches: read from SwiftData. UserDefaults is read only as fallback if SwiftData store is missing or corrupt.

**Idempotency gate (L1, S49 audit).** The pre-built `SettingsMigration.needsMigration` reads `schemaVersion` from **UserDefaults** (the `SettingsStore`), so step 4's write of `2` must land where that read sees it: either also bump UserDefaults `schemaVersion` to `2`, or gate on `migrationCompleted` (step 5). Writing the new version **only** to SwiftData leaves UserDefaults at the absent/`1` reading → `needsMigration` stays true → the migration re-runs every launch. Pin the gate to the store the check actually reads.

**Type-mismatch keys (L2, S49 audit).** `SettingsMigration.snapshot` omits a key whose stored value can't be read as its declared `valueType` (e.g. a `.data` key holding a non-`Data` object) → that setting reverts to its default in v2. Vanishingly rare (the app only ever writes consistent types) and non-crashing; noted so activation tests don't flag a dropped malformed key as a regression.

**Why not delete UserDefaults immediately after migration?**
- Defensive: if migration partially failed, we can re-run it.
- Removed in v2.1 after one minor release of stable telemetry-free observation.

**SwiftData schema for v2** (sketch — finalized in a future doc 05):
```swift
@Model final class TriggerConfig {
    var id: String           // "calendar", "app", "wifi", "focus"
    var isEnabled: Bool
    var encodedConfig: Data  // JSON for now; structured fields later
    var updatedAt: Date
}

@Model final class GeneralSetting {
    var key: String          // SettingsKey.rawValue
    var value: Data          // bool/string/data — same trichotomy as v1
    var updatedAt: Date
}
```

iCloud sync is added by setting the `ModelConfiguration.cloudKitDatabase = .private(...)` once entitlements are configured. Conflict policy: last-writer-wins per record (acceptable for settings; user-edits shouldn't conflict frequently).

**Implementation contract for v1**: every place we read/write settings goes through `SettingsStore`. **No direct `UserDefaults.standard` calls anywhere outside `UserDefaultsSettingsStore`.** This is what makes the migration cheap. Lint check (future): `grep -r "UserDefaults" Sources/ | grep -v "UserDefaultsSettingsStore.swift"` should return zero matches.

---

## 3. Storage layout

### 3.1 UserDefaults suite

All keys live in the **app's standard UserDefaults** (`UserDefaults.standard`). We do **not** create a custom suite — sandboxed apps get their own per-bundle UserDefaults automatically.

Key namespacing: every key is prefixed with `latte.` to make the plist self-documenting and to avoid collision if we ever read another app's defaults via App Group (not currently planned).

Example: `SettingsKey.allowDisplaySleep.rawValue == "latte.allowDisplaySleep"`.

### 3.2 Encoding rules per type

| Swift type | Stored as | Notes |
|---|---|---|
| `Bool` | `Bool` (UserDefaults native) | Default applied if key absent. |
| `Int` | `Int` (native) | Range-validated on read; out-of-range falls back to default. |
| `String` | `String?` (native) | `nil` distinguishes "never set" from `""`. |
| `enum String` | `String` rawValue | Unknown rawValues fall back to default. |
| `[String]` | JSON-encoded `Data` | Must be array of `String`. Decoder failure → default (empty array). |
| `Set<String>` | JSON-encoded `Data` (sorted array) | Order normalized for deterministic equality in tests. |
| `Date` | `Double` (timeIntervalSince1970) | Used only for internal bookkeeping (e.g., `migrationCompletedAt`); never user-edited. |

`SettingsStore` exposes typed getters/setters for `Bool`, `String?`, and `Data`. Higher-level callers (e.g., `CalendarTrigger`) own their JSON encoding/decoding via `Codable` structs.

---

## 4. Schema (v1)

### 4.1 Top-level keys

| Key (`latte.` prefixed) | Type | Default | Description | Validation |
|---|---|---|---|---|
| `schemaVersion` | `Int` | `1` | Bumped when shape of stored data changes. First *written* by v2.0's migration (§2.2). | **Shipped v1.x never wrote this key** → absent reads as `1` (an existing v1 install), **not** fresh — see §2.2 / §6.2. Migrate when `< 2`; `>` current → §6.2 downgrade handling. |
| `firstRunCompleted` | `Bool` | `false` | Set after onboarding screen dismissed. | Read-only after first true. |
| `firstRunCompletedAt` | `Double` (Date) | `0` | Timestamp of first run completion. | Informational. |
| `allowDisplaySleep` | `Bool` | `false` | When true, display may sleep but system stays awake (`NoIdleSleep`). | — |
| `activateOnLaunch` | `Bool` | `false` | When true, app boot transitions `Asleep → AwakeUserIndefinite` automatically. | Note: **overrides** the "always boot Asleep" default in 03 §8.6 — by user opt-in. |
| `launchAtLogin` | `Bool` | `false` | Mirror of `SMAppService.mainApp.status`. Source of truth is system; we cache for UI. | Synced on every Settings → General view appear. |
| `menuBarIconStyle` | `String` | `"filled"` | One of `"filled"`, `"outline"`, `"clock"`. | Unknown rawValue → `"filled"`. |
| `lastQuitCleanly` | `Bool` | `true` | Set false on app start, true on `signal` handler / clean quit. Used to detect crashes for `.fault` log on next start. | Internal diagnostic; not surfaced in UI. |

### 4.2 Calendar trigger

| Key | Type | Default | Description |
|---|---|---|---|
| `calendarTriggerEnabled` | `Bool` | `false` | Master enable. When false, trigger never starts polling EventKit. |
| `calendarTriggerCalendarIDs` | `Data` (JSON `[String]`) | `[]` (all) | Calendar identifiers to watch. Empty = all calendars the user has granted access to. |
| `calendarTriggerExcludeAllDay` | `Bool` | `true` | Exclude all-day events (typical "vacation" / "OOO"). |
| `calendarTriggerLeadTimeMinutes` | `Int` | `0` | Minutes *before* event start to begin voting ON. `0` = vote on at exact start. Range: 0–15. |
| `calendarTriggerTrailingMinutes` | `Int` | `0` | Minutes *after* event end to keep voting ON (separate from cool-down). Range: 0–15. |

### 4.3 App-presence trigger

| Key | Type | Default | Description |
|---|---|---|---|
| `appTriggerEnabled` | `Bool` | `false` | Master enable. |
| `appTriggerBundleIDs` | `Data` (JSON `[String]`) | curated default set (see §4.3.1) | Bundle IDs that, when running, vote ON. |

#### 4.3.1 Default app bundle IDs

Pre-populated for new installs. User can add or remove freely. Chosen to cover the top video-call apps with name recognition:

```json
[
  "us.zoom.xos",
  "com.microsoft.teams2",
  "com.cisco.webex.meetings",
  "com.hnc.Discord",
  "com.tinyspeck.slackmacgap",
  "com.google.Chrome.helper.meet"
]
```

Note: `Google Meet` runs in the browser, not as a standalone app. The above bundle ID is a placeholder — the actual detection of "is the user in a Meet call" requires browser-tab inspection or a heuristic, both of which are out of scope for v1. We leave the entry in defaults as a no-op; the user gets accurate detection if they open Zoom/Teams/Webex.

#### 4.3.2 Bundle ID validation

A bundle ID added by the user must match the regex `^[a-zA-Z0-9.-]+$` and be ≤ 200 characters. Invalid entries are dropped silently when the JSON is decoded (with a `.notice` log).

### 4.4 Wi-Fi trigger

| Key | Type | Default | Description |
|---|---|---|---|
| `wifiTriggerEnabled` | `Bool` | `false` | Master enable. |
| `wifiTriggerSSIDs` | `Data` (JSON `[String]`) | `[]` | SSIDs that, when joined, vote ON. |
| `wifiTriggerInverseLogic` | `Bool` | `false` | When true, treat the list as a denylist (vote ON when **not** on listed networks — useful for "stay awake everywhere except home"). |

#### 4.4.1 SSID validation

SSID strings can be arbitrary UTF-8 bytes (Wi-Fi standard); we don't restrict character set. Length: 1–32 (per 802.11 spec). Empty SSIDs are dropped on decode.

### 4.5 Focus mode trigger

| Key | Type | Default | Description |
|---|---|---|---|
| `focusTriggerEnabled` | `Bool` | `false` | Master enable. |
| `focusTriggerFocusIDs` | `Data` (JSON `[String]`) | `["work"]` | Focus mode identifiers that, when active, vote ON. |

`focusTriggerFocusIDs` references Apple's Focus identifiers. Common values: `"work"`, `"personal"`, `"do.not.disturb"`. Custom Focus modes use system-generated IDs; we surface them in the picker UI.

> **v1 limitation (added session 4)**: `INFocusStatusCenter` exposes only `focusStatus.isFocused: Bool?` for privacy reasons — it does **not** disclose the active Focus's identifier. Therefore `FocusTrigger` in v1 treats `focusTriggerFocusIDs` as a list-presence flag: if the list is non-empty AND any Focus is active, vote ON. Per-Focus filtering will require either an Apple API change or `INSetFocusStatusIntent` workaround; tracked as **Phase 1.5 follow-up**, not a blocker for v1 launch. The Settings UI will say "Active when any Focus mode is on" rather than offering a Focus-mode picker. Existing key shape is preserved so future per-Focus filtering can ship without a schema bump.

### 4.6 Schedule trigger (V2-05, added session 9 — v1.1)

| Key | Type | Default | Description |
|---|---|---|---|
| `scheduleTriggerEnabled` | `Bool` | `false` | Master enable. |
| `scheduleTriggerEntries` | `Data` (JSON `[ScheduleEntry]`) | `[]` | Recurring time-of-day windows. |

`ScheduleEntry` shape:

```swift
public struct ScheduleEntry: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var weekdays: Set<Weekday>     // Sun=1..Sat=7 (Calendar.weekday alignment)
    public var start: TimeOfDay           // hour: 0..23, minute: 0..59
    public var end: TimeOfDay
    public var label: String              // optional display label (default "")
    public var isEnabled: Bool            // per-entry enable toggle (default true)
}
```

**Membership semantics** (`ScheduleEntry.contains(_:in:)`):

- Same-day (`start < end`): half-open `[start, end)`, weekday must match the entry's weekday set.
- Midnight-crossing (`start > end`): late half `[start, 24:00)` matches entry's listed weekdays (today); early half `[00:00, end)` matches *yesterday's* weekday. A Mon 22:00–02:00 entry covers Mon 22:00 through Tue 02:00 only — Tue 22:00–24:00 does **not** match unless Tue is also in the weekday set.
- `start == end` is treated as a zero-length window — never matches. Users wanting a 24-hour entry use 00:00–23:59.
- Empty `weekdays` set: never matches (UI hint).
- `isEnabled == false`: never matches.

**Persistence**: JSON-encoded as a flat array. UUIDs are persisted, so reordering does not change identity. Decode failures fall back to `[]` (logged at `notice` level via `settingsLogger`).

**Polling**: 30 s cadence, identical lifecycle pattern to `CalendarTrigger.pollOnce()`. The trigger emits exactly **one** ON vote on enter and **one** OFF vote on exit — `activeEntryID: UUID?` is held between polls so re-poll inside the same window is a no-op. UI edits call `trigger.reevaluate()` which dispatches an immediate `pollOnce()` (no need to wait the 30 s cadence — same contract as App/WiFi/Calendar after S8b).

**DST**: handled by the system `Calendar` reading wall-clock `hour`/`minute` from the local timezone. Spring-forward gaps (clock jumps 02:00 → 03:00) cause that minute range to simply not poll-match; fall-back duplicates (01:30 happens twice) cause the entry to remain active across both — both behaviors match user expectation for a wall-clock schedule.

---

## 5. `SettingsStore` extended

Building on 02-architecture.md §4.3, this is the **complete** `SettingsKey`
enum as shipped through the v1.x line (v1.0 → v1.9). Adding a new key requires
bumping `schemaVersion` only if the new key's default is non-trivially derived
(e.g., re-keying old data); pure additions don't need a bump.

> **Authoritative source: [`Sources/Core/SettingsStore.swift`](../../Sources/Core/SettingsStore.swift).**
> This block is a curated snapshot for design readers; `SettingsKey.allCases`
> in that file is the single source of truth (the iCloud-sync RFC
> [10-c3-icloud-sync-rfc.md](10-c3-icloud-sync-rfc.md) §10/§13 references
> `allCases`, not this snapshot, so its migration stays correct regardless of
> drift here). Per-key prose (`///` doc comments, default-resolution rationale)
> lives in the Swift source; keep this list in sync when adding keys.

```swift
public enum SettingsKey: String, CaseIterable, Sendable {
    // Versioning
    case schemaVersion         = "latte.schemaVersion"
    case firstRunCompleted     = "latte.firstRunCompleted"
    case firstRunCompletedAt   = "latte.firstRunCompletedAt"
    case lastQuitCleanly       = "latte.lastQuitCleanly"

    // General preferences
    case allowDisplaySleep     = "latte.allowDisplaySleep"
    case activateOnLaunch      = "latte.activateOnLaunch"
    case launchAtLogin         = "latte.launchAtLogin"
    case menuBarIconStyle      = "latte.menuBarIconStyle"
    case coffeeAccent          = "latte.coffeeAccent"

    // Calendar trigger
    case calendarTriggerEnabled            = "latte.calendarTrigger.enabled"
    case calendarTriggerCalendarIDs        = "latte.calendarTrigger.calendarIDs"
    case calendarTriggerExcludeAllDay      = "latte.calendarTrigger.excludeAllDay"
    case calendarTriggerLeadTimeMinutes    = "latte.calendarTrigger.leadTimeMinutes"
    case calendarTriggerTrailingMinutes    = "latte.calendarTrigger.trailingMinutes"

    // App-presence trigger
    case appTriggerEnabled         = "latte.appTrigger.enabled"
    case appTriggerBundleIDs       = "latte.appTrigger.bundleIDs"
    case hasSeededAppDefaults      = "latte.appTrigger.hasSeededDefaults"

    // Wi-Fi trigger
    case wifiTriggerEnabled        = "latte.wifiTrigger.enabled"
    case wifiTriggerSSIDs          = "latte.wifiTrigger.ssids"
    case wifiTriggerInverseLogic   = "latte.wifiTrigger.inverseLogic"

    // Focus trigger
    case focusTriggerEnabled   = "latte.focusTrigger.enabled"
    case focusTriggerFocusIDs  = "latte.focusTrigger.focusIDs"

    // Schedule trigger (V2-05) — v1.1
    case scheduleTriggerEnabled = "latte.scheduleTrigger.enabled"
    case scheduleTriggerEntries = "latte.scheduleTrigger.entries"

    // External-display trigger (V2-06) — v1.2; whitelist deferred H — v1.5
    case externalDisplayEnabled   = "latte.externalDisplayTrigger.enabled"
    case externalDisplayWhitelist = "latte.externalDisplayTrigger.whitelist"

    // Battery-aware mode (C-1) and pause-all (C-9) — v1.1
    case requireACForAwake      = "latte.requireACForAwake"
    case triggersPaused         = "latte.triggersPaused"

    // Global keyboard shortcut (B1) — v1.1
    case keyboardShortcutEnabled = "latte.keyboardShortcut.enabled"

    // Custom keyboard-shortcut chord (B1.2) — v1.2
    case shortcutChord = "latte.keyboardShortcut.chord"

    // Activity history retention (C-3 deferred F) — v1.3.1
    case activityRetentionDays = "latte.activityHistory.retentionDays"

    // Activity chart colour overrides (C-3) — v1.7
    case activityChartColors = "latte.activityHistory.chartColors"

    // Recurring quick presets (C-7) — v1.7
    case recurringQuickPresets = "latte.quickPresets.recurring"

    // Built-in seed sentinel (S19 #2 — seed-then-mutable C-7 redesign)
    case didSeedBuiltinPresets = "latte.quickPresets.didSeedBuiltins"
}
```

### 5.1 Typed accessor extensions

Higher-level callers should not stringly-type their reads. We provide typed extensions on `SettingsStore` per logical group; they live next to the trigger they serve:

```swift
// Sources/Triggers/CalendarTrigger.swift
extension SettingsStore {
    var calendarTriggerCalendarIDs: [String] {
        get { decodeStringArray(.calendarTriggerCalendarIDs) }
        set { encodeStringArray(newValue, for: .calendarTriggerCalendarIDs) }
    }
}

// Sources/Core/SettingsStore.swift
extension SettingsStore {
    func decodeStringArray(_ key: SettingsKey) -> [String] {
        guard let data = data(key) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    func encodeStringArray(_ value: [String], for key: SettingsKey) {
        let data = try? JSONEncoder().encode(value)
        setData(data, for: key)
    }
}
```

### 5.2 Default value resolution

`SettingsStore.bool(_:default:)` etc. take an explicit default at the call site. This keeps defaults local to the consumer (e.g., calendar trigger declares its defaults in `CalendarTrigger.swift`) instead of a centralized "all defaults" file that becomes a god-object.

A single helper enumerates all defaults for use in the **Reset to defaults** Settings button:

```swift
public enum SettingsDefaults {
    public static func resetAll(in store: SettingsStore) {
        for key in SettingsKey.allCases {
            // explicit per-key reset, not a blanket removeObject — keeps semantics typed
            switch key {
            case .schemaVersion:           store.setBool(true, for: key)  // never auto-reset
            case .firstRunCompleted:       break                          // never auto-reset
            // … one branch per key …
            default: break
            }
        }
    }
}
```

---

## 6. Validation & corruption handling

### 6.1 Validation policy

- **Type mismatch on read**: return default, log `.notice` once per launch ("settings key X had unexpected type, using default").
- **Out-of-range numeric**: return default. Example: `calendarTriggerLeadTimeMinutes` must be 0–15; 99 → default 0.
- **JSON decode failure**: return default, log `.notice`. Do not erase the bad data — leave it for owner inspection if a user sends a `defaults read com.araforge.latte` dump.
- **Unknown enum rawValue**: return default. Same rule.

The principle: corruption never crashes the app. Worst case, settings revert to defaults silently.

### 6.2 Schema version bumps

Future bumps follow this protocol:

1. New version `N` ships with `schemaVersion = N`.
2. On launch, read current `schemaVersion`:
   - missing → **treat as `1`** (the shipped v1.x floor never wrote `schemaVersion`, so an absent key means an existing v1 install, *not* fresh) → fall into the `< N` migration path below. On a genuinely fresh install that path copies nothing — a harmless no-op — and step 3 writes `N`. **Never skip migration on a missing key.**
   - `< N` → run migration function `migrate_K_to_N(store:)` for each step `K → K+1`.
   - `== N` → no-op.
   - `> N` → user downgraded; log `.notice`, leave data untouched (forward compatibility within reason; older code reads what it knows).
3. After migration, write `schemaVersion = N`.

Each migration is a pure function over `SettingsStore`. Tested with fixture stores.

---

## 7. Privacy & sandbox notes

- **Calendar IDs** are EventKit identifiers (opaque strings). They are not personally identifying on their own but enumerate which calendars exist, which is sensitive. Stored locally only.
- **SSIDs** can identify physical locations. Stored locally only.
- **Bundle IDs** of running apps are not user-identifying. Stored locally only.
- **Focus IDs** can leak user lifestyle (e.g., a custom Focus called `"NightShift"` or `"Therapy"`). Stored locally only.

In all cases, **nothing leaves the device**. The Privacy Policy (PRD §10.3) asserts this; the data model implements it by having no network code that reads from `SettingsStore`.

---

## 8. Backup & user data export

### 8.1 v1: Time Machine + iCloud Drive (system-level)

The app's UserDefaults plist (`~/Library/Containers/com.araforge.latte/Data/Library/Preferences/com.araforge.latte.plist`) is included in:
- Time Machine backups
- iCloud Drive backup if user has "Desktop & Documents" sync (excluded — Containers/ is not in the synced set, but personal recovery via Migration Assistant works)

We don't ship an in-app export feature in v1.

### 8.2 v1.5: optional in-app export (deferred)

If users request settings backup, ship a "Export settings" button that writes `schemaVersion + all keys` as a single JSON file to the user-chosen path. Symmetric "Import settings" reads + validates + applies.

This is **explicitly deferred** to Phase 1.5 to keep launch surface small. Mentioned here so the schema's flat-key shape stays serializable in a single pass.

---

## 9. Test plan (for sessions 6–7)

### 9.1 Unit tests (must)

- `InMemorySettingsStore` round-trips every type (Bool, String, Int via Bool/String, `[String]` via Data).
- `UserDefaultsSettingsStore` round-trips against a temp UserDefaults suite (`UserDefaults(suiteName: "test-\(UUID())")`), verified persistence within a test run.
- All defaults defined here match what the consumer reads (e.g., `calendarTriggerExcludeAllDay` defaults to `true`).
- Validation: out-of-range / wrong-type / corrupt-JSON each return the default and don't throw.

### 9.2 Integration tests (must)

- Calendar trigger: enabling sets `.calendarTriggerEnabled = true` and persists across `SettingsStore` recreation.
- "Reset to defaults" clears every key without disturbing `firstRunCompleted` or `schemaVersion`.

### 9.3 Migration tests (deferred to Phase 2)

When the SwiftData migration is implemented:
- Round-trip every v1 key into a SwiftData store, then back. Values preserved exactly.
- Partial-migration recovery: kill mid-way, relaunch, finishes cleanly.

---

## 10. Open Questions resolved by this doc

| ID | Status |
|---|---|
| OQ-03 | **Resolved**: UserDefaults via `SettingsStore` protocol for v1. Centralized accessor; no direct `UserDefaults.standard` calls outside `UserDefaultsSettingsStore`. |
| OQ-04 | **Resolved**: SwiftData migration runs once at first launch of v2. UserDefaults retained for one minor version as fallback. Migration is an explicit copy keyed by `SettingsKey`; no automatic introspection. |

Remaining open questions (OQ-07 onboarding, OQ-08 icon direction, OQ-09 App Store category, OQ-10 Korean copy tone) deferred to their target docs per 01-PRD.md §11.

---

## 11. Decisions Log (this doc)

| Date | Decision |
|---|---|
| 2026-04-25 | UserDefaults for v1; SwiftData migration in v2 |
| 2026-04-25 | All keys prefixed `latte.` for self-documenting plist |
| 2026-04-25 | Single `SettingsKey` enum drives all storage; no untyped strings outside `UserDefaultsSettingsStore` |
| 2026-04-25 | `[String]`-valued keys (calendarIDs, bundleIDs, ssids, focusIDs) JSON-encoded into `Data` |
| 2026-04-25 | Awake state is **not** persisted; cold launch = `Asleep` (override available via `activateOnLaunch`) |
| 2026-04-25 | App-presence trigger ships with curated default bundle IDs (Zoom / Teams / Webex / Discord / Slack) |
| 2026-04-25 | Wi-Fi trigger supports inverse logic (denylist) via `wifiTriggerInverseLogic` |
| 2026-04-25 | Validation failures fall back to defaults silently; corrupt data preserved for inspection |
| 2026-04-25 | Settings export deferred to Phase 1.5; flat-key schema preserves serializability |

---

## 12. Document Change Log

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-04-25 | Initial draft (session 2) |
| 0.2 | 2026-04-26 | Session 4: §4.5 footnote — INFocusStatusCenter does not disclose Focus IDs; v1 uses list-presence semantic; key shape preserved for future per-Focus filtering. |

---

## 13. Sign-off Checklist (closes design phase)

- [x] Owner accepts UserDefaults for v1 (§2.1)
- [x] Owner accepts SwiftData migration plan for v2 (§2.2)
- [x] Owner accepts the schema in §4 (every key, default, validation rule)
- [x] Owner accepts the curated default app bundle IDs (§4.3.1)
- [x] Owner agrees export feature is deferred to Phase 1.5 (§8.2)
- [x] Design phase closed — code rewrite begins in session 3
