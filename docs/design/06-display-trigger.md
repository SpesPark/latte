# 06 — External Display Trigger Spec (V2-06)

| Field | Value |
|---|---|
| **Document version** | 1.0 |
| **Status** | ✅ Shipped in S11 (2026-04-30). See ROADMAP row 11a. |
| **Audience** | Implementing engineer for v1.2 |
| **Depends on** | 02-architecture.md §4.4 (Trigger protocol) + §4.4.1 (Source DI pattern) |
| **Backlog ref** | `v2-backlog.md` V2-06 |
| **Last updated** | 2026-04-30 |

---

## 1. Purpose

Add a fifth trigger — `ExternalDisplayTrigger` — that votes `wantsAwake = true`
whenever **at least one external display is connected**.

### User signal (from S8b research)

> *"Plugged into monitor → keep awake."*

MacBook-at-desk workflow: lid closed or open, external monitor attached,
user is presenting / coding / on a long render. The external-display
heuristic captures the "I'm actively at my desk" state more reliably than
calendar/app/wifi for this slice.

KYA Issue #235 surfaced the demand; Amphetamine ships an equivalent.

### Out of scope (deferred)

- **Clamshell-aware refinement** — lid-closed-while-external-display-present
  is the most awake-relevant case, but querying lid state needs
  IOPMrootDomain or `NSScreen.main` heuristics. v1.2 ships
  display-count-only; clamshell smarts can land in v1.3+ if telemetry /
  feedback warrant.
- **Per-display whitelist** — "only this monitor at home" UX adds a
  picker, settings storage, source-of-truth for display identity (UUID
  via `CGDisplayCreateUUIDFromDisplayID`). Defer until usage shows demand.

---

## 2. API surface (matches existing trigger pattern)

```swift
public final class ExternalDisplayTrigger: Trigger {
    public let id: String = "external-display"
    public var displayName: String { "External Display" }
    public var settingsKey: SettingsKey { .externalDisplayEnabled }

    public init(source: DisplaySource = NSScreenSource(),
                store: SettingsStore)

    public func start() async
    public func stop()

    public var voteStream: AsyncStream<TriggerVote> { ... }
}

public protocol DisplaySource {
    /// Current external-display count (excludes the built-in screen).
    var externalDisplayCount: Int { get }

    /// First external display's localized name (macOS 14+) or
    /// "External Display" fallback. Used for the vote reason string.
    var firstExternalDisplayName: String? { get }

    /// AsyncStream that emits whenever the screen configuration changes
    /// (display attach/detach, resolution change, sleep/wake).
    var changeStream: AsyncStream<Void> { get }
}
```

### Production adapter — `NSScreenSource`

- Wraps `NSScreen.screens` + `NSApplication.didChangeScreenParametersNotification`.
- "External" = any screen whose `localizedName` (macOS 14+) or fallback
  ID isn't the built-in display. macOS 13 fallback: count = `NSScreen.screens.count - 1` if any screen is built-in (heuristic via
  `CGDisplayIsBuiltin(CGDirectDisplayID)`).
- `changeStream` debounces — `didChangeScreenParametersNotification` fires
  multiple times during a single attach event; coalesce within 300ms.

### Test mock — `MockDisplaySource`

- Exposes `setExternalDisplayCount(_:)` + `setFirstName(_:)` to drive
  state changes from tests.
- Backing AsyncStream continuation stored, `finish()` called from `deinit`
  + an explicit `stop()` (S7.11 stream-lifecycle parity).

---

## 3. Vote semantics

| `externalDisplayCount` | Vote |
|---|---|
| 0 | `TriggerVote(wantsAwake: false, reason: "")` |
| ≥ 1 | `TriggerVote(wantsAwake: true, reason: "Display: <name>")` where `<name>` is `firstExternalDisplayName ?? "External Display"` |

Reason format mirrors `AppTrigger`'s post-S10 friendly format
(`"App: Zoom"` not `"App: us.zoom.xos"`). For consistency: `"Display: …"`.

### Combination policy unchanged

`TriggerCoordinator` already aggregates votes via "any-OR" — no policy
change needed. ExternalDisplayTrigger is one more vote in the OR.

### Re-enable behaviour (matches WiFi/AppTrigger pattern)

When the user disables the trigger while it is currently the only
awake-causing vote, `TriggerCoordinator.stop()` synthesises an immediate
grace-0 vote-OFF; the FSM transitions to `.asleep` (or `.coolingDown` if
the trigger declares `graceSecondsAfterOff > 0`).

When the user re-enables the trigger, `start()` calls `evaluate()` which
reads the current source state and yields a fresh vote if the display is
still attached. This matches WiFi/App/Schedule trigger semantics — every
v1 trigger re-evaluates on Toggle ON, the user expects "I just turned
this on, my monitor is plugged in, the cup should be active." The C-1
(battery) and C-9 (pause-all) no-auto-replay policies from S9 apply at
the **manager input boundary** (auto-resume on AC re-plug or unpause is
suppressed there), not at the per-trigger toggle level.

*(Earlier draft of this spec proposed waiting for the next genuine
`didChangeScreenParametersNotification` to vote; that was rejected during
S11 implementation in favour of WiFi consistency. See commit `4895d35`.)*

---

## 4. Settings UI

`Sources/UI/Settings/TriggersTab.swift` adds a 5th `Section`:

```
External Display
┌────────────────────────────────────┐
│  ☐ Stay awake when an external     │
│    display is connected             │
│                                     │
│    Currently: 1 external display    │  ← live status (read-only)
│    Display: DELL U2723QE            │  ← only when ≥1
└────────────────────────────────────┘
```

- Toggle bound to `SettingsKey.externalDisplayEnabled` (new key, default
  `false` to keep existing users' behaviour stable).
- "Currently:" status binds to `@Published` count from
  `ExternalDisplayTrigger`'s public observable surface (matches how
  `WiFiTrigger.currentSSID` is exposed for the WiFi tab).

---

## 5. State-machine impact

**None.** Same as S10: this trigger only emits votes; it does not call
`AwakeManager.activate(reason:)` directly. The 6-state FSM in 03 is
unchanged.

---

## 6. Test plan

`Tests/ExternalDisplayTriggerTests.swift` — target ≥ 8 tests:

1. `initial_zero_external_count_emits_no_vote`
2. `attach_external_emits_awake_vote_with_friendly_reason`
3. `attach_then_detach_emits_no_awake_vote`
4. `multiple_externals_only_one_awake_vote_with_first_name`
5. `name_unavailable_falls_back_to_External_Display`
6. `stop_finishes_voteStream_continuation` (S7.11 parity)
7. `disable_while_active_drops_vote_no_replay_on_re_enable` (C-1 / C-9 parity)
8. `debounce_coalesces_burst_screen_change_notifications`

`Tests/TriggerCoordinatorTests.swift` — add 1-2 tests:

- `external_display_vote_combines_OR_with_calendar_and_app`
- `pause_all_ignores_external_display_vote` (B1 parity)

---

## 7. Smoke plan

**Cannot fully automate** — physical display attach/detach isn't scriptable
without external hardware fixtures. Instead:

### `.smoke/scenarios/20-external-display.sh` (NEW, planned)

- Hybrid scenario: launch Latte, set `externalDisplayEnabled=YES`, then use
  a `LATTE_TEST_MOCK_DISPLAY_COUNT=2` env var (new test-only injection
  point) to swap `NSScreenSource` for a fake source backed by env.
- Verify the popover's status row reflects "1 external display" via window
  capture + comparison.
- Mark as **functional** scenario (counts toward smoke total).

### Owner manual smoke (one-time)

Add to `SESSION_HANDOFF.md` 6-step checklist as new step 7:
1. Plug in an external monitor with Latte running.
2. Verify cup activates within 1s; menubar tooltip shows
   `"Display: <monitor-name>"`.
3. Unplug; verify cup deactivates after the 60s any-OR cool-down (or
   immediately if no other vote is held).

---

## 8. Effort estimate

| Phase | Hours |
|---|---|
| `DisplaySource` protocol + `NSScreenSource` adapter | 1.0 |
| `ExternalDisplayTrigger` + `voteStream` lifecycle | 1.0 |
| Settings UI section + live status binding | 0.5 |
| Tests (8 unit + 2 coordinator) | 1.0 |
| Smoke scenario 20 + env-var mock injection | 0.5 |
| Owner smoke checklist updates | 0.1 |
| **Total** | **~4.0 h** |

Within S8b's original ~3-4h estimate.

---

## 9. Open questions for owner (before code starts)

| # | Question | Default answer if owner skips |
|---|---|---|
| Q1 | Block external-display vote when on battery? Pairs awkwardly with "Sleep when on battery" setting. | **No** — battery sleep policy already gates the assertion at `AwakeManager`; trigger should vote freely. |
| Q2 | Should external-display votes respect calendar quiet hours (V2-05 schedule)? | **Yes** — schedule trigger is the global gate, applies across all triggers. (Already handled by coordinator policy; no extra work.) |
| Q3 | Settings copy "external display" vs "monitor" vs "second display"? | **"external display"** — matches Apple's `NSScreen` API naming and Amphetamine. |
| Q4 | Default-on after install? | **Default-off** — opt-in, matches v1.0 stance for app/wifi/focus triggers. |

---

## 10. Cross-references

- 02-architecture.md §4.4 — Trigger protocol contract
- 02-architecture.md §4.4.1 — `*Source` DI pattern (this trigger follows it)
- 03-state-machine.md §7 — transition table (no changes)
- v2-backlog.md V2-06 — backlog entry that drove this spec

---

## 11. Implementation order — **as shipped in S11**

Five-commit sequence landed 2026-04-30:

1. `4895d35` — **Core RED+GREEN**: `DisplaySource` protocol, `NSScreenSource`,
   `MockDisplaySource`, `ExternalDisplayTrigger`, `SettingsKey.externalDisplayEnabled`,
   9 unit tests (1 over the spec ≥8 floor — restart-after-stop split out as
   its own test once the single-consumer changeStream gotcha surfaced).
2. `9c6504c` — **Wire**: register in `AppEnvironment.registerDefaultTriggers`;
   2 coordinator integration tests (vote OR with another trigger; pause-all
   suppression).
3. `fd9df79` — **UI**: TriggersTab section + `ExternalDisplayTriggerConfigForm`.
4. `5642bbc` — **Smoke**: scenario 20 (no-monitor branch automated; CI hosts
   have no external monitor, so the natural OFF branch is what's verified
   automatically).
5. *(this commit)* — **Docs**: this spec marked Shipped, 02-architecture
   §4.4.1 updated, ROADMAP row 11a, v2-backlog V2-06 marked Shipped,
   SESSION_HANDOFF wrap.

The `LATTE_TEST_MOCK_DISPLAY_COUNT` env-var hack proposed in §7 was
**not** implemented — keeping production code free of test-only branches
proved cleaner; physical-attach simulation is owner manual smoke (handoff
step 7) territory.

The single-consumer `source.changeStream` gotcha that emerged during
implementation (`for await` can only be consumed once for the lifetime
of an `AsyncStream`) was solved with the `isRunning` gate pattern: the
observe task lives once, gated by a flag, instead of being cancelled
and recreated on each stop/start cycle. Documented inline in
`ExternalDisplayTrigger.swift`.

## As shipped — v1.5 (S16, 2026-05-01) — deferred refinements

The two §"Out of scope (deferred)" items + the §2 debounce note all
landed same-day in 4 feat commits + 1 simplify-pass:

| # | Commit | Scope |
|---|---|---|
| 1 | `dc13407` | **I — Debounce**. New `DebouncingDisplaySource` decorator collapses bursts into one yield per 300ms window using a seq-counter (each `scheduleFlush` bumps `pendingSeq` + captures it; in-flight Task yields only when its seq still equals `pendingSeq` at flush time). NSScreenSource wrapped by default in production; tests inject MockDisplaySource raw. 468 → 471 tests (+3). |
| 2 | `6495697` | **G — Clamshell**. DisplaySource gains `isInClamshellMode: Bool`, derived from NSScreen.screens (external present, built-in absent = lid closed). Vote reason becomes `"Display: <name> (clamshell)"` when in clamshell mode. Vote semantics unchanged — both lid states still vote awake; the tag refines what owner sees in About → Status / Activity → Currently active. 471 → 473 tests (+2). |
| 3 | `0dfdf73` | **H — Per-display whitelist**. `DisplayInfo` value-type (uuid + name) + `attachedExternalDisplays: [DisplayInfo]` on the protocol. NSScreenSource derives stable UUIDs via `CGDisplayCreateUUIDFromDisplayID` + `CFUUIDCreateString`. `SettingsKey.externalDisplayWhitelist` stores JSON-encoded UUIDs. Trigger filter (`resolveVoteState`): empty whitelist → match any (v1.2 preserved), non-empty → narrow to listed UUIDs. Settings UI gains "Match only these displays" toggle list. `setWhitelistedUUIDs` persists + re-evaluates on the spot. 473 → 477 tests (+4). |
| 4 | `b7a7c72` | **9th simplify-pass on 1-3 (+ S16 commit 4 = E)**. APPROVE-WITH-NITS, 0 CRIT / 1 HIGH / 2 MED / 3 LOW. HIGH-1 attached-list-name-priority regression test. MED-2 `encodeStringArray([], for:)` now `remove(key)` instead of writing `[]` blob (preserves "absent == default" migration invariant). MED-3 `DailyTotal.compute` switched to `Calendar.date(byAdding:)` for DST correctness. LOW-6 debouncer proxy test extended. 482 → 485 tests (+3). |

**Decisions resolved during ship**:
- **G — clamshell detection without IOPMrootDomain**: NSScreen.screens
  excludes the built-in display when the lid is closed. `hasExternal &&
  !hasBuiltIn` is exactly the clamshell condition without needing the
  Power Management entitlement / private API. Cleaner and more
  testable.
- **H — UUID source**: CGDisplay UUID survives reboots and reorders.
  Considered the screen serial number (vendor + model + serial) but the
  UUID is the canonical Apple-blessed identity for `CGDisplay`. The
  whitelist UI surfaces the *name* but persists the UUID so a renamed
  monitor doesn't break the filter.
- **H — empty whitelist semantics**: empty = "no filter, match any
  external" preserves v1.2 behavior for users who never touch the
  setting. Toggling on every display in the picker also produces the
  "match any" effect (semantically equivalent), but the persisted
  representation is empty (after the simplify-pass MED-2 fix removes
  the empty-array blob).
- **G + H interaction**: clamshell tag still appended even when the
  whitelist filters out the otherwise-attached external. The reason
  uses the matched display's name; if zero displays match, vote is
  off and clamshell is irrelevant.

**Still-deferred** (no further v1.x scope):
- **Lid-closed-only mode** — vote awake ONLY in clamshell, ignore
  lid-open externals. Owner-request gate; not enough demand yet.
- **Per-display position requirement** — "primary on the left,
  secondary on the right" — esoteric.
