# 08 — C-7 "Until X PM" Quick-Preset Paths Comparison

| Field | Value |
|---|---|
| **Document version** | 0.1 |
| **Status** | **Path A shipped** in v1.6 (S17, 2026-05-01) — see §9 below |
| **Audience** | Owner (decision) + implementing engineer (after pick) |
| **Backlog ref** | `v2-backlog.md` C-7 (carryover from S10) |
| **Last updated** | 2026-04-30 |

---

## 1. Why this doc exists

The S10 SESSION_HANDOFF flagged C-7 as "owner-pending — 3 implementation
paths documented." That was true at the conversational level but the paths
lived only in transcript. This file consolidates the four real options
(three from S10 + a fourth no-op alternative) with concrete trade-offs so
the owner can pick on a single screen.

### What "Until X PM" means

Today the popover shows 7 quick-preset durations from
`AwakeDuration.presets` ([Sources/Core/AwakeDuration.swift:26](Sources/Core/AwakeDuration.swift:26)):

```
5m / 15m / 30m / 1h / 2h / 5h / Indefinitely
```

The C-7 ask is to add **semantic time-of-day presets**:

```
"Until 5 PM"   ← end of workday
"Until 11 PM"  ← end of evening
"Until midnight"
```

These are not durations — they are **target wall-clock times**. The
arithmetic ("how many seconds until 5 PM?") changes every minute.

---

## 2. Status quo (no change)

The popover already has 7 presets and an "Indefinitely" option. Owner can
pick "1h" or "2h" and re-toggle if they need a precise EoD release. The
custom-duration row (1–1440 min stepper) covers any odd value. C-7 is a
**convenience win**, not a missing capability.

---

## 3. The four paths

### Path A — `.minutes(N)` runtime conversion (smallest)

When the user picks "Until 5 PM", compute `seconds = 5pm - now`, round to
the nearest minute, call `manager.activate(for: .minutes(N), reason: .user)`.

```swift
// Inside the popover preset handler:
case .untilTimeOfDay(let hour):
    let target = nextOccurrence(hour: hour, from: .now)
    let mins = max(1, Int(target.timeIntervalSinceNow / 60))
    manager.activate(for: .minutes(mins), reason: .user)
```

| Aspect | Verdict |
|---|---|
| LOC delta | ~40 (1 helper + 3 popover rows + 2 tests) |
| New `AwakeDuration` cases? | No — reuses `.minutes(N)` |
| State-machine changes | None |
| Persistence changes | None |
| UX correctness | **Checkmark leak**: the active preset row shows a checkmark by comparing `manager.activeDuration` to the preset. After conversion the FSM holds `.minutes(213)`, which doesn't match `.untilTimeOfDay(17)`, so the checkmark renders on the **Custom row** instead of "Until 5 PM" — minor but noticeable. |
| Time semantics | Set-and-forget: if user picks at 4:55 PM, awake fires for ~5 min then ends. Crossing-midnight ("until 6 AM" picked at 11 PM) needs a "next occurrence" helper but is straightforward. |
| Risk | Lowest — no FSM, no persistence, no protocol churn. |

### Path B — `AwakeDuration.until(Date)` enum case (semantic-clean)

Add a new case to `AwakeDuration`:

```swift
public enum AwakeDuration: Equatable, Hashable, Sendable {
    case minutes(Int)
    case hours(Int)
    case indefinite
    case until(Date)        // NEW
}
```

`seconds` for `.until(Date)` returns `max(0, date.timeIntervalSinceNow)`;
`label` returns `"Until 5:00 PM"` via a date formatter.

| Aspect | Verdict |
|---|---|
| LOC delta | ~140 (enum case + Codable + label + seconds + ~6 switch sites + ~10 tests) |
| New `AwakeDuration` cases? | **Yes** (`.until`) |
| State-machine changes | None — FSM holds the case opaquely. |
| Persistence changes | `Codable` conformance widens — tests must cover round-trip of `.until(Date)`; backward-compat for old payloads stored as `.minutes(N)`. |
| UX correctness | **Clean** — checkmark matches because the held duration **is** "Until 5 PM"; no leak to Custom row. |
| Time semantics | `seconds` recomputes every getter call (depends on `Date.now`). FSM timer is set once at activate; if the popover re-renders, it sees a smaller `seconds` value and the label can show a live countdown. |
| Risk | Medium — every `switch self {…}` over `AwakeDuration` (5 sites in repo at last count) needs a new branch. SwiftUI Picker must handle non-Hashable date payloads (fix: hash by `Calendar.dateComponents([.hour, .minute, .day], from: date)`). |

### Path C — `@Published var activeQuickPreset` (decoupled)

Don't add a duration case at all. Add a separate published property to
`AwakeManager` that holds the **semantic intent** independently of the
underlying duration:

```swift
public enum QuickPreset: Equatable, Sendable {
    case duration(AwakeDuration)
    case until(hour: Int, minute: Int)
}

@Published public private(set) var activeQuickPreset: QuickPreset?
```

`activate(for:reason:)` is overloaded; the duration variant clears
`activeQuickPreset = nil`, the preset variant sets it and computes
internal `.minutes(N)` for the FSM.

| Aspect | Verdict |
|---|---|
| LOC delta | ~80 (new enum + 2 activate overloads + popover binding + 6-8 tests) |
| New `AwakeDuration` cases? | No |
| State-machine changes | None — FSM still operates on `AwakeDuration`. |
| Persistence changes | `activeQuickPreset` is **session-only** by design (resets on quit). Persisting it is opt-in for v2. |
| UX correctness | Clean — popover binds checkmark to `activeQuickPreset`, not to derived duration. **Future-proofs C-3** (snooze recurring presets, "until calendar event end", etc.). |
| Time semantics | Same as path A under the hood (computes `.minutes(N)`). |
| Risk | Medium-low — touches `AwakeManager` public surface. New tests for "duration variant clears preset" and "preset variant sets it". |

### Path D — Skip C-7, ship C-3 instead

C-3 ("Snooze for X minutes" recurring presets) is a separate
v2-backlog item. Some research findings during S10 noted that "Until 5 PM"
is one specific instance of a more general recurring-pattern feature, and
that path C above is partly motivated by future C-3 needs.

| Aspect | Verdict |
|---|---|
| LOC delta | 0 here; defer to C-3 sprint. |
| Risk | Owner perceives C-7 as overdue if C-3 is many weeks away. |

---

## 4. Side-by-side at a glance

| Criterion | A (`.minutes` conversion) | B (`.until(Date)` case) | C (`activeQuickPreset` aside) | D (skip → C-3) |
|---|---|---|---|---|
| **LOC delta** | ~40 | ~140 | ~80 | 0 |
| **New `AwakeDuration` cases** | No | **Yes** | No | No |
| **FSM modified** | No | No | No | No |
| **Public API surface change** | Popover only | `AwakeDuration` (≥1 site is `Codable`) | `AwakeManager` adds 1 published + 2 overloads | None |
| **Checkmark leak** | **Yes** (UX nit) | No | No | N/A |
| **Persistence churn** | None | Codable round-trip | None (session-only) | None |
| **Future-proofs C-3** | No | Partially | **Yes** | (it IS C-3) |
| **Risk** | Lowest | Medium | Medium-low | Lowest |
| **Implementation hours** | ~1.5 | ~3.5 | ~2.5 | 0 |

---

## 5. Recommendation

**Path A** if the owner wants C-7 in the next code session and is
comfortable with the checkmark falling on Custom for active "Until X PM"
sessions. The UX nit is real but minor — Caffeinated and Amphetamine both
show "Custom: 213 min remaining" or similar in this state and users tolerate
it.

**Path C** if the owner is also planning C-3 inside the next 2-3 sprints.
The marginal extra hour vs path A pays for itself once C-3 lands; doing C-3
on top of path A means partly undoing path A's checkmark logic.

**Path B** only if the owner wants the cleanest model and is fine with the
~3.5h cost. It's the "right" abstraction; the cost is the every-`switch`-
exhaustiveness churn.

**Path D** is honest: if C-3 is the actual product win and C-7 was
just-an-instance-of-it, ship the general feature and skip the special case.

---

## 6. Decision matrix for owner

Pick the row that matches your priorities for the next 1-2 sprints:

| If you care most about… | Pick |
|---|---|
| Shipping C-7 fastest, accepting one UX nit | **A** |
| Shipping C-7 cleanly, no nits, ~1h extra | **C** |
| Best long-term abstraction regardless of effort | **B** |
| Maximizing strategic value — bundle into C-3 | **D** |

---

## 7. What to do after picking

1. Owner writes pick (A/B/C/D) into a 1-line note in `SESSION_HANDOFF.md`
   "Owner-side decisions" section.
2. Implementing engineer adds the picked path's RED tests first
   (3 tests for path A, 8-10 for path B, 6-8 for path C).
3. Path A and C touch only `Sources/Core/AwakeManager.swift` +
   `Sources/UI/Menu/PopoverContent.swift` (or wherever the preset rows
   live); path B touches every `switch self` over `AwakeDuration`.
4. After GREEN, add an entry under `Shipped in v1.x` in `v2-backlog.md`
   under C-7 with the picked path noted.

---

## 8. Cross-references

- [Sources/Core/AwakeDuration.swift](Sources/Core/AwakeDuration.swift) — current 7-preset table.
- `docs/SESSION_HANDOFF.md` — "C-7 scope" reference (line 156 at S10 tail).
- `docs/v2-backlog.md` — C-7 backlog entry (one-line surface).
- `docs/design/03-state-machine.md` §7 — FSM (unchanged across all four paths).

---

## 9. As shipped — v1.6 (S17, 2026-05-01) — Path A

Path D was retired before pick: C-3 has been shipped (v1.3 + v1.5
deferred items), so "skip C-7 → ship C-3" no longer applies. Of the
remaining three paths the owner prioritised lowest-risk, fastest-to-ship
(fix-first cadence), accepting the documented checkmark-on-Custom-row
UX nit per §5.

| # | Commit | Scope |
|---|---|---|
| 1 | `7252a0b` | New pure `QuickPreset` enum (case `until5PM` / `until11PM` / `untilMidnight`) with `nextOccurrence(after:)` + `minutes(from:)`. Conversion to `.minutes(N)` happens at click time; FSM unchanged. Already-passed targets roll to tomorrow. Midnight encoded as `targetHour=24` → next day's `startOfDay`. `min(1)` clamp guarantees no 0-min activation at boundary. New `QuickPresetRow` component (distinct from `DurationPickerRow`, no checkmark logic — preset rows never highlight). MenuBarRoot popover gains a 4th Section after the existing 7 duration presets + Custom row. 485 → 494 tests (+9). |

**Decisions resolved during ship**:
- **Custom row checkmark stays as-is** (not redirected to the matching
  preset row) — per spec §3 Path A trade-off. Active "Until 5 PM"
  session shows checkmark on Custom row, not the preset row. Owner
  tolerated for v1.6; revisit if user feedback flags it.
- **Minute rounding** — `(secondsAhead / 60).rounded()` plus `max(1, …)`
  clamp. A 4:59:59 PM tap on "Until 5 PM" yields 1 minute (rounds 0,
  clamps to 1). A 4:59:30 PM tap also yields 1 minute. Slightly biased
  but never below the activation floor.
- **Tests use UTC-anchored `DateComponents`** instead of raw epoch
  arithmetic so CI hosts in any timezone produce the same results.
  Pattern reaffirmed from prior sessions.

**Still-deferred** (no further v1.x scope unless owner requests):
- Path B (`.until(Date)` enum case) — clean abstraction, 3.5h cost,
  every `switch self` over `AwakeDuration` would need a new branch.
- Path C (`@Published activeQuickPreset` aside) — rationale was
  "future-proofs C-3"; C-3 has now shipped, so the marginal benefit
  is gone.

## §10. As shipped — v1.7 (S18, 2026-05-01) — Per-day-of-week recurring presets

The "larger feature" deferred at §9 above shipped same-day after S17 in
commit `0693f3a`.

### Model

New `RecurringQuickPreset` (`Sources/Core/RecurringQuickPreset.swift`),
Codable / Equatable / Identifiable / Sendable:

```swift
public struct RecurringQuickPreset: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let targetHour: Int       // 0…23
    public let targetMinute: Int     // 0…59
    public let weekdays: Set<Int>    // subset of 1…7 (Sun=1 … Sat=7)
}
```

Pure helpers:
- `isActiveOn(date:calendar:) -> Bool` — true if `date`'s weekday is in
  `weekdays`. Used by the popover to filter — only "active today"
  presets render.
- `nextOccurrence(after:calendar:) -> Date` — looks today + 7 days
  ahead (8 candidates, since worst case is "today is the right weekday
  but target time just passed → 7 days forward"). Empty `weekdays`
  returns `now` so the caller's clamp produces 1 minute rather than
  crashing — but the popover never invokes this for empty weekdays
  because `isActiveOn` filters them out first.
- `minutes(from:calendar:) -> Int` — `max(1, …)` clamp mirrors the
  built-in `QuickPreset.minutes(from:)` semantics. Click at the
  boundary never activates for 0 minutes.

### Persistence

Static `write(_:to:)` / `read(from:)` round-trip via
`SettingsKey.recurringQuickPresets`. Empty list removes the key
(preserves "absent = never customised" invariant). Corrupt JSON
returns `[]` and never crashes.

### UI

**Popover** (`MenuBarRoot.swift`): user presets render as a separate
section after the built-in QuickPresets, filtered by today's weekday.
Click → `preset.minutes(from: .now)` → `manager.activate(for: .minutes(N))`.
Same conversion path as built-in presets — FSM unchanged. New
`RecurringQuickPresetRow` view matches `QuickPresetRow` visually so
users perceive built-in and custom presets as one cohesive section.
No checkmark logic — preset rows never highlight (consistent with
Path A trade-off from v1.6).

**Editor** (`RecurringQuickPresetEditor.swift`): new "Custom presets"
Section in the General Settings tab.
- List: each preset shows label + "HH:MM · day-summary" subtitle (e.g.
  "18:00 · Weekdays").
- Tap row → edit sheet (item-binding so a different preset replaces
  the previous).
- Context menu → Edit / Delete.
- "Add preset…" button → new sheet.
- Sheet has TextField label + hour picker (0..23) + minute picker
  (0..55 in 5-min stride) + 7 weekday chips. Save disabled while label
  is empty or no weekdays selected.

Pure `RecurringPresetWeekday` helper (`orderedCases` / `shortLabel(for:)`
/ `summary(for:)`). Summary special-cases:
- empty → "Never"
- {1,2,3,4,5,6,7} → "Every day"
- {2,3,4,5,6} → "Weekdays"
- {1,7} → "Weekends"
- otherwise comma-separated short labels in Sun-first order
  (e.g. "Tue, Thu, Sat").

### Path B / C status

**Retired**. Path B was justified by clean abstraction; Path C by C-3
future-proofing. Both rationales are obsolete:
- Path C: C-3 shipped (v1.3 + v1.5 + v1.7) — the future-proofing
  motivation is gone.
- Path B: the "every `switch self` over `AwakeDuration` would need a
  new branch" cost outweighs the benefit now that custom presets ship
  as a parallel surface (no new `AwakeDuration` case needed).

### Test coverage

514 → 537 tests (+23) for the model + persistence + weekday helper:
- `isActiveOn` (in/out/empty)
- `nextOccurrence` (today/tomorrow/skip-inactive/weekend-only/empty/
  minute-offset)
- `minutes` (clamp/360min)
- Codable round-trip + array round-trip
- SettingsStore round-trip + empty clears + nil → [] + corrupt → []
- Weekday helper (every-day / weekdays / weekends / arbitrary /
  short-label / empty)

## §11. As shipped — v1.8 (S19 #2, 2026-05-02) — Built-in seed-then-mutable redesign

Owner-reported in step 6 manual smoke (S19): the three legacy
`QuickPreset` rows (until 5 PM / 11 PM / midnight) are valuable for
some users but waste popover space for users who never use them.
Hard-coded enum cases are by definition not deletable.

**Redesign**: built-ins become *seed data* in the regular
`recurringQuickPresets` list. First-launch migration writes the three
legacy rows as `RecurringQuickPreset` values; from that moment on they
behave like any user-defined preset (editable label / time / weekdays,
deletable via right-click in General Settings).

### Migration semantics

A new `SettingsKey.didSeedBuiltinPresets` (Bool, default false) is the
**only** state that distinguishes "fresh install" from "user emptied
the list intentionally". Without this sentinel, `seedBuiltinPresets`
on every empty list would resurrect the seeds whenever a user deleted
all three — a rage-quit scenario. With the sentinel:

| State at launch | Sentinel | Existing list | Action |
|---|---|---|---|
| Fresh install | false | empty | Write 3 seeds, set sentinel true |
| v1.7 upgrader (had user presets) | false | non-empty | Preserve list, set sentinel true |
| Returning user | true | any | No-op |

The sentinel is set in **all three** pre-true cases so the migration
runs at most once per install regardless of subsequent edits.

### Seed values (per S19 #2 owner decisions)

```
"Until 5 PM"       hour=17 minute=0  weekdays={1...7}  UUID=C7000001-…-017
"Until 11 PM"      hour=23 minute=0  weekdays={1...7}  UUID=C7000001-…-023
"Until midnight"   hour=0  minute=0  weekdays={1...7}  UUID=C7000001-…-000
```

Stable hard-coded UUIDs so two `builtinSeeds()` calls return equal
arrays — writes stay idempotent and edge-case re-runs (theoretical) can't
double-seed.

Midnight uses `hour=0` instead of the legacy `targetHour=24` sentinel.
`RecurringQuickPreset.nextOccurrence` looks ahead 8 candidates (today +
7 days) — a candidate that has already passed (always true for hour=0
when `now > today's startOfDay`) naturally rolls forward to tomorrow.
Result is identical minutes-from-now to the legacy
`QuickPreset.untilMidnight` calculation.

### Owner-decision recap

- (a) Empty popover (zero presets) is acceptable — popover wraps the
  recurring section in `if !activePresets.isEmpty`, no empty divider.
- (b) Seed weekdays = `{1...7}` (Every day) so first-launch behaviour
  matches the legacy enum exactly. Users freely narrow to platform
  patterns (Weekdays / Weekends) themselves.
- (c) `QuickPreset` enum + `QuickPresetRow` view: deprecated via
  doc-comment, retained for API stability and existing
  `nextOccurrence` / `minutes` regression tests.
- (d) Seed labels stay verbatim ("Until 5 PM" / "Until 11 PM" / "Until
  midnight") — the seed visibility is via the editor list, not via
  label suffix.

### Test coverage

547 → 547 tests (no change at total because the SettingsStoreTests
allowlist update was a tracked invariant, not a new behaviour test).
The 9 new RED→GREEN tests live in `RecurringQuickPresetTests`:
- `builtinSeeds()` cardinality / labels / weekdays / target times /
  UUID stability / midnight-rolls-to-tomorrow (6 tests)
- `seedBuiltinPresetsIfNeeded(in:)` fresh-install / upgrader-preserves /
  user-cleared-no-respawn (3 tests)

### Cross-references

- `Sources/Core/RecurringQuickPreset.swift` — `builtinSeeds()` +
  `seedBuiltinPresetsIfNeeded(in:)` + stable seed UUIDs
- `Sources/App/AppEnvironment.swift` — migration call before recurring
  list read
- `Sources/UI/MenuBar/MenuBarRoot.swift` — popover renders only from
  `recurringQuickPresets`, gated on non-empty
- `Sources/Core/QuickPreset.swift` — deprecated, kept for tests
- `Sources/UI/MenuBar/QuickPresetRow.swift` — deprecated, kept for
  API stability
