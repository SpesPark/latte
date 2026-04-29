# 08 — C-7 "Until X PM" Quick-Preset Paths Comparison

| Field | Value |
|---|---|
| **Document version** | 0.1 |
| **Status** | Decision-pending — owner picks path A / B / C / D before any code lands |
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
