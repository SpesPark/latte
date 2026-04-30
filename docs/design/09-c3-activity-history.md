# 09 — C-3 Activity History

> Status: **Plan (decision-ready)**. Owner approved defaults 2026-04-30 (S14 entry).
> Targets: macOS 13.0+ (deployment min, see `project.yml`). Swift 6 strict concurrency.

## §1. Goal

Surface the **history of trigger fire events** to the owner so they can:

1. See whether configured triggers actually fire (own-pattern visibility).
2. Confirm a trigger turned ON/OFF when expected (debugging "why did Latte sleep").
3. Generate marketing PNG material (App Store screenshot — Charts visual).

**Non-goals (deferred to v2.x)**: per-trigger filtering UI, CSV export, "click to jump to
trigger config", any reason-text customisation, multi-day comparison views.

## §2. Schema

```swift
public struct ActivityLogEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let triggerId: String          // e.g. "wifi", "calendar", "schedule"
    public let kind: Kind
    public let reasonCode: ReasonCode     // structured, NOT free text — see §6 Privacy

    public enum Kind: String, Codable, Sendable { case on, off }

    public enum ReasonCode: String, Codable, Sendable {
        case voteOn               // generic ON
        case voteOff              // generic OFF
        case userToggleOff        // user-explicit Toggle OFF / list edit (grace=0 path)
        case stoppedByCoordinator // trigger.stop() from coordinator (e.g. trigger disabled)
    }
}
```

- **id**: persisted UUID (idempotent if file replayed).
- **triggerId**: matches the existing `Trigger.id` ("wifi", "calendar", "focus", "app",
  "schedule", "externalDisplay").
- **kind**: ON/OFF only — no "modified" or "config-changed" entries (out of scope).
- **reasonCode**: enum, not raw `TriggerVote.reason` string (privacy — see §6).

## §3. Persistence — actor + JSON file (NOT SwiftData)

**Decision**: actor-based store + atomic JSON file write. Rejected SwiftData v1 because
this is a single append-mostly entity with a small bound (14 days × ~hundreds of
events) — the dependency cost dwarfs the benefit. Pattern follows `swift-actor-persistence`
skill.

```swift
public actor ActivityLogStore {
    private let url: URL                  // ~/Library/Application Support/Latte/activity-log.json
    private var entries: [ActivityLogEntry] = []
    private let retention: TimeInterval = 14 * 24 * 60 * 60   // 14 days

    public init(directory: URL) async throws { ... }   // creates dir, loads file if present
    public func append(_ entry: ActivityLogEntry) async                      // appends + GC + atomic write
    public func snapshot() async -> [ActivityLogEntry]                       // for Charts read
    public func snapshot(since: Date) async -> [ActivityLogEntry]            // ranged read
    public func clear() async                                                // for tests + future "Clear history" UI
}
```

- **File location**: `FileManager.default.url(for: .applicationSupportDirectory, ...)`
  / `Latte/activity-log.json`. Sandbox: `com.parkbyeongjun.latte` container OK.
- **Atomic write**: `Data.write(to: url, options: .atomic)`.
- **GC**: on every `append`, drop entries older than `retention`. No background timer.
- **Concurrency**: actor isolation = no shared-mutable hazard. All callers `await`.
- **Failure modes**:
  - Init can `throw` on directory create failure → `App` logs + falls back to in-memory
    store (history lost across launches but app keeps running).
  - Write failure → log via `LatteLog.activity.error`, drop the entry. Never crash.
- **NOT** persisted: which view filters owner used, "last viewed at" markers
  (UI-only state).

## §4. Hook point

Single funnel: `TriggerCoordinator.handleVote(_:from:)` (`Sources/Triggers/TriggerCoordinator.swift:84-91`).
This is where every ON/OFF vote already lands — adding the log call here covers all
6 triggers + future triggers automatically.

```swift
private func handleVote(_ vote: TriggerVote, from triggerId: String) {
    if vote.wantsAwake {
        activeVotes[triggerId] = vote
    } else {
        activeVotes.removeValue(forKey: triggerId)
    }
    awakeManager.receiveTriggerVote(vote, from: triggerId)
    Task { [activityStore] in
        await activityStore?.append(.init(
            id: UUID(), timestamp: .now,
            triggerId: triggerId,
            kind: vote.wantsAwake ? .on : .off,
            reasonCode: vote.wantsAwake ? .voteOn : .voteOff
        ))
    }
}
```

`stop(_:)` already routes through `awakeManager.receiveTriggerVote` with
`wantsAwake: false, graceSecondsAfterOff: 0` for user-explicit OFF — but it does NOT
go through `handleVote`, so it's a separate write site that needs its own append with
`reasonCode: .userToggleOff`.

**Coordinator init**: `ActivityLogStore` injected as optional (`activityStore: ActivityLogStore?`)
— nil in unit tests that don't care about logging, real instance in app boot.

## §5. UX

**New 4th Settings tab "Activity"** (next to General / Triggers / About).

- `SettingsTab` enum gains `case activity` (rawValue `"activity"`) — `latte://settings/activity` becomes a valid deep link.
- `SettingsRoot` gains a 4th `tabItem` with `Label("Activity", systemImage: "chart.bar.xaxis")`.
- New file `Sources/UI/Settings/ActivityTab.swift`.

### Layout (top to bottom)

```
┌────────────────────────────────────────────────┐
│ Last 24 hours                                  │  ← title
│ ┌──────────────────────────────────────────┐  │
│ │  [stacked bar Chart by hour, 24 bars]    │  │  ← per-trigger colour
│ │   Y: minutes-awake-this-hour             │  │
│ └──────────────────────────────────────────┘  │
│                                                │
│ Last 14 days                                   │
│ ┌──────────────────────────────────────────┐  │
│ │  [Chart heatmap: 14 days × 24 hours]     │  │
│ │   Cell intensity = total awake minutes   │  │
│ └──────────────────────────────────────────┘  │
│                                                │
│ Currently active                               │
│ ▸ wifi         "Office-5G"     since 09:14     │  ← owner-visible reason summary
│ ▸ calendar     "Standup"       since 10:00     │     (UI only, NOT persisted)
└────────────────────────────────────────────────┘
```

- **Charts framework**: `import Charts` (macOS 13+). `BarMark` + `RectangleMark`.
- **Active list**: read live from `coordinator.activeVotes` (already `@Published`).
  This is the ONE place we DO show the raw `TriggerVote.reason` string — but only the
  in-memory current value, never persisted.
- **Empty state**: when `entries.isEmpty`, show centered hint
  "Trigger fires will appear here." + SF symbol.
- **Reload cadence**: tab fetches `await store.snapshot()` `.task` on appear; no live
  polling. Refresh on tab re-select.

### Theming

Match existing tabs — `Form` container, default macOS spacing. Trigger colours pull
from a new `Color+ActivityTrigger` extension (one fixed hue per trigger ID). Don't
re-skin the whole app.

## §6. Privacy

**Persisted entries store NO user content**:

- ❌ App bundle ID / app name (e.g. "Zoom")
- ❌ Wi-Fi SSID
- ❌ Calendar event title
- ❌ Focus mode name
- ❌ Schedule entry label
- ❌ External-display vendor / product name

**Persisted**: trigger ID (already-public taxonomy), timestamp, ON/OFF, structured
`reasonCode`. That's it.

**App Store privacy label impact**: zero new categories. Latte already declares
"No data collected"; this design preserves that — the file is local-only, never
network-uploaded.

The "Currently active" UI list (§5) reads `coordinator.activeVotes[…].reason` in
memory only — visible to the owner on their own machine, never persisted, never
shipped to disk.

## §7. Migration

- Fresh installs: file does not exist; first append creates it.
- Existing v1.2 users: file does not exist; same flow.
- **No `SettingsKey` added** — `ActivityLogStore` is its own file, decoupled from
  `SettingsStore`. Schema changes inside `ActivityLogEntry` itself (post-v1.3) will
  use a top-level `version: Int` field on the JSON wrapper; v1 readers ignore unknown
  versions (drop history, log fault, start fresh).

## §8. Smoke 22 — `activity_log_writes_on_trigger_fire`

```bash
# Manual smoke step 22 (added to scenario list)
1. Reset: delete ~/Library/Application Support/Latte/activity-log.json
2. Launch Latte → enable WiFi trigger with current SSID listed
3. Toggle Wi-Fi off (system pref) → wait 5s → toggle on → wait 5s
4. Quit Latte
5. Cat the file: jq '. | length >= 2 and (.[0].triggerId == "wifi")'
   AND jq '. | map(.reasonCode) | inside(["voteOn","voteOff"])'
6. PASS if jq returns true on both
```

Harness automation TBD — same shape as scenarios 18-21 (state-file inspection after
deterministic input). Add to `~/dev/smoke-harness/scenarios/22_activity_log.sh`.

## §9. Tests (RED first per `tdd-workflow`)

### Unit — `ActivityLogStoreTests`

```swift
@Test("appends entry and persists across reloads")
@Test("GC drops entries older than 14 days")
@Test("atomic write survives concurrent appends")
@Test("snapshot(since:) filters by date")
@Test("clear() empties the store and the file")
@Test("init from missing file returns empty store")
@Test("init from corrupt file logs fault and returns empty store")
```

### Integration — `TriggerCoordinator+ActivityLogTests`

```swift
@Test("handleVote(.on) appends entry with kind=.on / reasonCode=.voteOn")
@Test("handleVote(.off) appends entry with kind=.off / reasonCode=.voteOff")
@Test("stop(triggerId) appends entry with reasonCode=.userToggleOff")
@Test("nil store: handleVote does not crash")  // optional injection
```

### Coverage target

Match repo standard (≥80%). `ActivityTab` SwiftUI snippets covered manually via smoke 22 + owner UI smoke step (added to handoff).

## §10. Deferred (NOT in this sprint)

| Item | Reason |
|---|---|
| Per-trigger filter UI | Owner-visible value low for v1.3 — defer to v2.x |
| CSV / JSON export | No owner request yet |
| Click row → jump to trigger config | Simple but extra plumbing — defer |
| Multi-day comparison ("this week vs last") | Charts can do it but UI scope creep |
| User-customisable retention window | 14d hard-coded for v1.3; revisit if owner asks |
| Live polling (refresh while tab open) | `.task`-on-appear is simpler; revisit if needed |
| iCloud sync of history | Not v1.x scope |

## §11. As shipped

(Filled in at end of S14 once C-3 lands. Mirror pattern from 06-display-trigger §10
and 07-shortcut-recorder §10/§11.)
