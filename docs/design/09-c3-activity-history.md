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

## §11. As shipped (S14, 2026-04-30)

Shipped in 4 commits same-day after the design doc was approved:

| # | Commit | Scope |
|---|---|---|
| 1 | `e4a401c` | C-3 part 1 — ActivityLogEntry + ActivityLogStore actor + TriggerCoordinator hooks (handleVote + stop) + LatteLog.activity. 426 → 438 tests (+12). |
| 2 | `c4dac06` | C-3 part 2 — SettingsTab.activity + 4th tab in SettingsRoot + ActivityTab UI (Charts: 24h bar + 14d heatmap + Currently active) + AppEnvironment wiring + microsecond timestamp quantisation. 438 → 439 tests. |
| 3 | `6ef4e45` | 7th simplify-pass follow-through — 0 CRIT/HIGH, 2 MED + 2 LOW all addressed. AwakeSegment.merge added with 3 regression tests. 439 → 442 tests. |
| 4 | `7bfa1b7` | Smoke scenario 22 — file-absence on fresh launch + 4th-tab capture + jq schema assertion. Smoke 21 → 22, all PASS. |

**Deviations from §3 plan**:
- Persistence init was originally specified as `async`; pivoted to **lazy-load**
  (sync `init` + first `append`/`snapshot` triggers disk read once) so the store
  composes cleanly with `AppEnvironment.init` without an async hop. Behavior
  equivalent — actor isolation guarantees the load-once flag is race-safe.
- §3 schedule called `JSONEncoder.dateEncodingStrategy = .iso8601`. Switched to
  `.secondsSince1970` and added a microsecond quantisation in
  `ActivityLogEntry.init` because ISO8601 (whole or millisecond seconds)
  truncates `Date.now`'s nanosecond precision and breaks round-trip equality.
  Tradeoff noted in `ActivityLogStore.swift` — file is slightly less
  human-readable than ISO timestamps, but jq-friendly and the activity log is
  owner-facing only via Charts, not raw text inspection.

**Deviations from §5 plan**:
- `ContentUnavailableView` empty-state replaced with a manual `VStack` (Image
  + Text) because `ContentUnavailableView` is macOS 14+ and Latte targets
  macOS 13.
- `Color+ActivityTrigger` extension was inlined as `static let triggerDomain` /
  `triggerRange` arrays inside `HourlyAwakeChart` — the extension would have
  added a file with one helper used by one view, simpler to keep local.

**MED bugs fixed by 7th simplify-pass** (preserved here for changelog
durability — the design doc was technically correct, the implementation
drifted):
- `triggerDomain` had `"externalDisplay"` (camelCase) instead of
  `"external-display"` (matches `ExternalDisplayTrigger.id`). External display
  events were rendering with a fallback Charts colour outside the palette.
- `DailyHeatmapChart.compute` was passing the full sorted cross-trigger entry
  list to `AwakeSegment.pair`, which has a single-state machine that gets
  confused by interleaved triggers (a second trigger's `.on` while another is
  open is silently ignored, then closed by an unrelated `.off`). Now pairs
  per-trigger then unions overlapping intervals via `AwakeSegment.merge`.

**Smoke 22 limitations**: bash cannot deterministically force a real trigger
fire (Wi-Fi SSID match needs TCC; calendar event needs EventKit permission;
Schedule needs running through a real time window). The smoke verifies the
**file-absence-on-fresh-launch** lazy-load contract and the **Activity-tab
deep-link path**, plus a **schema privacy assertion** (jq) if any entry happens
to be written during the run. The "real trigger fires → entry recorded → tab
shows it" flow is owner manual smoke (handoff step 8).

## §12. As shipped — v1.3.1 (S15, 2026-05-01) — §10 deferred items B/C/D/F

Same-day continuation of S14. The 4 deferred items in §10 ranked by owner
ergonomic value were shipped in 4 feat commits + 1 simplify-pass:

| # | Commit | Scope |
|---|---|---|
| 1 | `0b59e67` | **F — customisable retention window**. `ActivityLogStore.retention` mutable via `setRetention(_:)`; immediate GC + flush on shrink. Range 1…90 days, default 14. New `SettingsKey.activityRetentionDays` + `AppEnvironment.activityRetentionDays` published mirror; ActivityTab Stepper. 442 → 450 tests. |
| 2 | `6a55c02` | **B — per-trigger filter UI**. `ActivityFilter` enum (.all / .only) gates both charts; picker domain dynamic (only triggers in current snapshot). Heatmap frame now follows user's retention setting. 450 → 455 tests. |
| 3 | `86bc5b1` | **C — CSV/JSON export**. Pure `ActivityLogExporter`; CSV ISO8601 / JSON secondsSince1970 round-trippable. NSSavePanel kept at call site; `ExportButtons` stays a pure SwiftUI primitive. 455 → 462 tests. |
| 4 | `0dfb9d2` | **D — click-row → trigger config jump**. Activity rows are buttons with chevron; click flips tab + `ScrollViewReader` scrolls. Deep-link form `latte://settings/triggers?focus=<id>`. `parseRoute(_:)` returns `SettingsRoute`; legacy `parse(_:)` kept. Already-open window re-emits via `Notification.Name.settingsRequestFocusTrigger`. 462 → 467 tests. |
| 5 | `4343d2a` | **8th simplify-pass follow-through**. APPROVE-WITH-NITS, 0 CRIT/HIGH, 2 MED + 5 LOW all addressed: reload on retention `.onChange`, `isLoading=true` at reload entry, `ActivityLogStore.secondsPerDay` constant collapses 4 magic-86_400 sites, `ActivityFilter.label(for:)` extraction (kebab → Title-Case, no `.capitalized` locale dep), DST cosmetic note documented on `splitByHourWithDate`. 467 → **468 tests**. |

**Deferred design decisions resolved during ship**:
- **F: which Settings tab does the Stepper live in?** — Activity tab itself
  (not General). It's contextually about activity; owner adjusting retention
  is already looking at the chart they want more/less of. Section "Retention".
- **B: dynamic picker domain or fixed taxonomy?** — Dynamic. A fresh install
  with only the WiFi trigger configured shouldn't see all 6 trigger labels in
  the menu when 5 of them have produced zero entries.
- **C: where does the side effect live?** — `ExportButtons` is a pure SwiftUI
  primitive; the host (`ActivityTab.export(_:as:)`) owns the NSSavePanel call.
  Mirrors the test-friendliness pattern from `RetentionStepper` (binding-only).
- **D: how does the legacy `parse(_:)` survive?** — Thin wrapper around the
  new `parseRoute(_:)`. `LatteApp.application(_:open:)` was migrated to
  `parseRoute` directly so `parse(_:)` only carries the test-coverage call
  sites. Considered `@available(*, deprecated)` but skipped — there's no
  pending callsite migration; leaving the dual API minimises noise.

**Still-deferred (per §10)** — ~~multi-day comparison view~~ (shipped v1.5),
live polling, iCloud sync, user-customisable Charts colours.

## §13. As shipped — v1.5 (S16, 2026-05-01) — §10 deferred E

`DailyTotalsChart` (commit `4e3c548`) — bar chart of total awake minutes
per day across the retention window. Today's bar darkened so the eye
reads day-over-day pattern without a separate overlay.

`DailyTotal.compute` reuses the existing per-trigger pair → merge → split
pipeline so parallel triggers don't double-count. Layout: dayOffset = 0
is the rightmost (most recent) bar so the eye reads left-to-right as
"older → today". Bar count auto-sizes to retention (1d → 1 bar; 90d →
90 bars with auto-stride x-axis).

9th simplify-pass MED-3 fix on this method: switched the window-start
anchor from raw `-86400` arithmetic to `Calendar.date(byAdding: .day)`
so DST-transition days don't shift the window by ±1h.

477 → 482 tests (+5): empty/zero-day, 60-min hour segment, parallel-merge
union, day-count == retention, dayOffset zero is most-recent.

## §14. As shipped — v1.7 (S18, 2026-05-01) — §10 deferred (live polling + chart colours)

Same-day continuation of S17. Two of the three remaining §10 deferred
items shipped (live polling + chart colours); iCloud sync remains
deferred for joint design with B1.2 iCloud-chord-sync (schema risk if
shipped in isolation).

### Live polling refresh (commit `54f7d7a`)

`TriggerCoordinator.recordActivity` posts
`Notification.Name.activityLogDidAppend` on every recordActivity site
(vote ON / vote OFF / user-explicit `stop(_:)` with an active vote).
The notification carries no userInfo — the canonical consumer
(`ActivityTab`) just refetches the snapshot, so emitting `triggerId` /
`kind` to every in-process observer would be needless payload (11th
simplify-pass LOW-3).

`ActivityTab.scheduleLiveReload()` debounces with a 300 ms
`liveReloadTask`: each new notification cancels the pending Task and
schedules a fresh one. Bursty boot-time trigger fires (all triggers
fire within ~50 ms) collapse to a single snapshot fetch. Cancellation
uses `do/catch` — letting `Task.sleep` throw `CancellationError` is the
single mechanism that aborts reload (11th simplify-pass LOW-2).

Suppression cases preserve correctness:
- `stop(_:)` with no active vote does NOT post (no append happened, no
  spurious refresh).
- nil `activityStore` does NOT post (no append happened, no phantom
  reload in any consumer that subscribes regardless of store presence).

**Actor ordering guarantee**: the post happens synchronously on
@MainActor *after* `Task { await activityStore.append(entry) }` is
queued. By the time a subscriber's reload `await`s a snapshot, FIFO
actor ordering guarantees the append has committed — no race between
notification and committed state.

494 → 499 tests (+5).

### User-customisable Charts colours (commit `67b18b3`)

New pure `ActivityChartPalette` (`Sources/Core/ActivityChartPalette.swift`):
- `triggerOrder: [String]` — canonical 6-trigger render order. Drift
  with `HourlyAwakeChart` is impossible because the chart reads this
  list directly (no parallel `triggerDomain` static).
- `defaultHex: [String: String]` — frozen v1.3 palette (`.blue`/`.red`/
  `.purple`/`.green`/`.orange`/`.teal`) so a user who never touches the
  picker sees no visual change across upgrades.
- `color(for:overrides:) -> Color` — override hex wins if it parses;
  falls through to default; falls through again to system accent for
  unknown triggers (never returns clear, which would silently hide
  bars).
- `encode(overrides:) -> Data?` — empty map returns nil so the caller
  can clear the key, preserving the "absent = never customised"
  invariant the v1.5 `encodeStringArray` empty-clear pattern relied on.
- `decode(overrides:) -> [String: String]` — tolerant: nil / corrupt
  payload returns `[:]` and the chart falls back to defaults.

New `Color(hex:)` and `Color.hexString` SwiftUI Color extensions:
- `Color(hex:)` parses `#RRGGBB` (or `RRGGBB`); rejects 3-digit
  shorthand and 8-digit RGBA (the picker UI never produces them);
  tolerates leading whitespace (11th simplify-pass LOW-4 — the prior
  implementation operated on the original string after trimming, which
  produced an 8-char "stripped" input and parse-failure for
  `"  #FF0000"`).
- `Color.hexString` reads from sRGB component space + 8-bit-per-channel
  rounding so the picker round-trip stays stable at the LSB.

New `SettingsKey.activityChartColors` mirrors via
`AppEnvironment.activityChartColors` ([String: String]). Reset button
in the ActivityTab "Chart colours" Section assigns `[:]`, removes the
key.

499 → 514 tests (+15).

**Deferred design decision resolved during ship**:
- **Section placement**: chart colours live in the Activity tab itself
  (not General). It's contextually about activity; owner adjusting
  colours is already looking at the chart they want to recolour.
  Mirrors the precedent from §12 retention stepper.

### Still-deferred (no further v1.x scope)

- **iCloud sync**: postponed for joint design with B1.2 iCloud-chord-
  sync — both touch the same Settings schema and a solo ship would
  risk migration churn. **Joint design now drafted:
  [10-c3-icloud-sync-rfc.md](10-c3-icloud-sync-rfc.md)** — **owner
  decisions locked 2026-05-18 (RFC §12): Q1=B-2, so the activity log is
  Domain B / append-only union merge, deliberately *not* last-writer-wins;
  ships as Phase 3 / v2.1, S8.5-gated.**
