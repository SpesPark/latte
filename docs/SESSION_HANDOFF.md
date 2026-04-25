# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 2 of ~10 |
| **Theme** | Design close-out |
| **Date** | 2026-04-25 |
| **Status** | ✅ Completed as planned. Design phase is **closed**. |

### What was accomplished

1. **Created [03-state-machine.md](design/03-state-machine.md)** — resolves OQ-01 + OQ-02
   - 6-state FSM: `Asleep`, `AwakeUserIndefinite`, `AwakeUserTimed`, `AwakeTriggered`, `CoolingDown`, `Snoozed`
   - **OQ-01 resolved**: any-OR aggregation across triggers; 60 s cool-down before deactivating to prevent flapping (back-to-back meetings).
   - **OQ-02 resolved**: manual-OFF during a trigger-ON enters `Snoozed(until: now+5min)`; manual-ON during trigger-ON is a no-op; manual-ON with no votes is `AwakeUserIndefinite`.
   - Mermaid state diagram, full transition table (6 states × 9 inputs), 6 worked examples used as test fixtures.
   - "Shadow set" pattern documented so user-states retain trigger votes for promotion on exit.

2. **Created [04-data-model.md](design/04-data-model.md)** — resolves OQ-03 + OQ-04
   - **OQ-03 resolved**: UserDefaults via `SettingsStore` protocol for v1. No direct `UserDefaults.standard` calls outside `UserDefaultsSettingsStore` — enables cheap migration later.
   - **OQ-04 resolved**: SwiftData migration runs once at first launch of v2 (Phase 2). UserDefaults retained for one minor version as fallback.
   - Full schema: every key (`latte.` prefixed), type, default, validation rule.
   - Default app bundle IDs curated for v1 install (Zoom, Teams, Webex, Discord, Slack).
   - Validation policy: corruption never crashes; falls back to defaults.
   - Awake state explicitly **not persisted** — cold launch always = `Asleep` (consistent with 03 §8.6).

3. **Updated [01-PRD.md](design/01-PRD.md)** — version 0.2
   - §11 Open Questions table: OQ-01 ~ OQ-04 marked ✅ Resolved with cross-references; OQ-05/06 also confirmed resolved (in 02-architecture.md from S1).
   - §13 Change Log entry added for v0.2.
   - §14 Sign-off checklist: all 5 boxes checked. **Status flipped from Draft → Approved.**

4. **Updated [02-architecture.md](design/02-architecture.md)** — version 0.2
   - §11 Open Questions table updated with cross-references to 03 / 04.
   - §13 Change Log entry added for v0.2.
   - §14 Sign-off checklist: all 5 boxes checked. **Status flipped from Draft → Approved.**

5. **Updated [ROADMAP.md](../ROADMAP.md)** — version 0.2
   - Sessions 1 + 2: 🟢 Done.
   - Session 3 marked 🟡 Next.

### What was *not* done (intentionally deferred)

- **Code rewrite** — this is the entire scope of session 3. Skeleton in `Sources/` is unchanged.
- **OQ-07 ~ OQ-10** — content/marketing decisions (onboarding copy, app icon visual direction, App Store category, Korean tone). These do **not** block session 3 code work; they're resolved in future docs (06-ui-spec.md, 10-release-plan.md, 11-localization.md) before launch prep in sessions 7–8.
- **Folder rename `Caffeinated-Clone/` → `Latte/`** and `Caffeinated.entitlements → Latte.entitlements`. Plan: do this in session 3 as part of the rewrite, before any external push.

---

## Next session entry point

**Theme**: Phase 1.0 implementation — rewrite `Sources/` to match the architecture (session 3 of ~10)

**Goal**: After this session, `Sources/Core/` and `Sources/Triggers/` are implemented and unit-tested per the architecture/FSM specs. Triggers themselves are stubs (real EventKit / NSWorkspace / CWWiFiClient / AppIntents focus integration arrives in session 4). UI is wired up to the new manager but visual polish is session 5.

### To-do (in order)

#### A. Pre-rewrite housekeeping (~10 min)

1. **Rename folder** `Caffeinated-Clone/` → `Latte/` at the filesystem level. Update `project.yml`, `README.md`, `ROADMAP.md` references. Commit as `chore: rename project folder Caffeinated-Clone → Latte`.
2. **Rename** `Configuration/Caffeinated.entitlements` → `Configuration/Latte.entitlements`. Update `project.yml`.
3. **Delete** existing skeleton files in `Sources/` per [02-architecture.md §10](design/02-architecture.md). Keep `Sources/` directory; layout will be created as needed.

#### B. Build `Sources/Core/` (TDD; ~60 min)

Order matters — each step produces inputs for the next.

1. **`Sources/Core/AwakeDuration.swift`** — value type
   - Re-implement the existing skeleton's `Duration` enum as `AwakeDuration` (renamed for clarity vs `Foundation.Duration`).
   - Cases: `.minutes(Int)`, `.hours(Int)`, `.indefinite`. Add static `presets: [AwakeDuration]` matching PRD F-1.0.04.
   - Tests: `AwakeDurationTests` — duration-arithmetic, presets list shape.

2. **`Sources/Core/PowerAssertion.swift`** — IOKit wrapper
   - Match the contract in [02-architecture.md §4.2](design/02-architecture.md). Two modes (`displayAndSystem`, `systemOnly`).
   - Provide a `PowerAssertion` protocol/abstract class so tests can inject `MockPowerAssertion` (records calls, no IOKit).
   - Tests: `PowerAssertionTests` — only the mock path; real IOKit test is integration-only and gated.

3. **`Sources/Core/SettingsStore.swift`** — protocol + 2 impls
   - Protocol per [02-architecture.md §4.3](design/02-architecture.md), extended with the full `SettingsKey` enum from [04-data-model.md §5](design/04-data-model.md) (`latte.` prefixed).
   - `UserDefaultsSettingsStore` — wraps `UserDefaults.standard`. Validation per [04 §6.1](design/04-data-model.md).
   - `InMemorySettingsStore` — dict-backed, for tests.
   - Helper extensions: `decodeStringArray` / `encodeStringArray` for JSON-encoded `[String]` keys.
   - Tests: `SettingsStoreTests` — round-trip every type; corruption → default; both impls share a parametrized test base.

4. **`Sources/Core/Logging.swift`** — `os.Logger` conveniences
   - `Logger(subsystem: "com.example.latte", category:)` factory; one logger per module.
   - Tests: not directly tested; verified by other modules' use.

5. **`Sources/Core/AwakeManager.swift`** — the FSM
   - `AwakeState` enum and `AwakeInput` enum exactly as in [03 §3, §4](design/03-state-machine.md).
   - Pure `process(input:)` step function: `(state, input, votes) -> (newState, sideEffects)`. No I/O inside.
   - Public API per [02 §4.1](design/02-architecture.md): `toggle()`, `activate(for:)`, `deactivate()`, `receiveTriggerVote(_:from:)`, the four `@Published` properties.
   - Side-effect dispatcher applies assertion / timer changes after a transition.
   - `signal()` handler installed at boot (per [02 §6.3](design/02-architecture.md)) to release assertion on SIGINT/SIGTERM/SIGABRT.
   - Tests: `AwakeManagerTests` — **one test per cell of the transition table** in [03 §7](design/03-state-machine.md). Plus the 6 worked examples in [03 §8](design/03-state-machine.md).

#### C. Build `Sources/Triggers/` (TDD; ~30 min)

6. **`Sources/Triggers/Trigger.swift`** — protocol + types
   - `Trigger` protocol per [02 §4.4](design/02-architecture.md).
   - `TriggerVote`, `TriggerPermissionStatus` types.
   - `MockTrigger` for tests (manual `voteStream` push).

7. **`Sources/Triggers/TriggerCoordinator.swift`** — orchestrator
   - Per [02 §4.5](design/02-architecture.md). Aggregates streams; calls `awakeManager.receiveTriggerVote(_:from:)`.
   - Tests: `TriggerCoordinatorTests` — register / start / stop, multi-trigger aggregation, vote forwarding.

8. **Stub trigger files** — `CalendarTrigger.swift`, `AppTrigger.swift`, `WiFiTrigger.swift`, `FocusTrigger.swift`
   - Each conforms to `Trigger` but `start()` does nothing and `voteStream` is empty.
   - Real EventKit / NSWorkspace / CoreWLAN / AppIntents wiring is **session 4**.
   - Each has `id`, `displayName`, `symbol`, `requiresPermission`, `isEnabled` reading from `SettingsStore`.

#### D. Build `Sources/Intents/` (~10 min)

9. **`Sources/Intents/AwakeIntents.swift`** — Toggle / Start(minutes:) / Stop intents
   - Match PRD F-1.0.11. Each intent calls `AwakeManager.shared.toggle()` / `activate(for:)` / `deactivate()`.
   - `AppShortcutsProvider` registers all three with phrases per the PRD.

#### E. Build `Sources/UI/` (~30 min)

10. **`Sources/UI/Theme/Theme.swift`** — colors/fonts/spacing constants.
11. **`Sources/UI/Components/CoffeeCupView.swift`** — minimal version (real animation = session 5).
12. **`Sources/UI/Components/LiquidGlassModifier.swift`** — `#available(macOS 26, *)` branch + ultraThinMaterial fallback.
13. **`Sources/UI/MenuBar/MenuBarRoot.swift`**, `HeaderView.swift`, `DurationPickerRow.swift` — split per [02 §3.1](design/02-architecture.md).
14. **`Sources/UI/Settings/SettingsRoot.swift`**, `GeneralTab.swift`, `TriggersTab.swift`, `AboutTab.swift` — TabView shell.

#### F. Compose root (~10 min)

15. **`Sources/App/LatteApp.swift`** — `@main` scene; install signal handler; create `AwakeManager.shared`.
16. **`Sources/App/AppEnvironment.swift`** — wires `SettingsStore`, `AwakeManager`, `TriggerCoordinator` into the SwiftUI environment for views to consume.

#### G. Wrap (~10 min)

17. **`Tests/`** — `AwakeManagerTests`, `SettingsStoreTests`, `TriggerCoordinatorTests`, `AwakeDurationTests`. Target ≥80 % coverage on `Core/` + `Triggers/` per [02 §8.1](design/02-architecture.md). UI views uncovered.
18. Update `01-PRD.md` change log (no version bump unless content changed) and `02-architecture.md` §10 (skeleton-rewrite gap → "completed in session 3").
19. **Update [ROADMAP.md](../ROADMAP.md)** — mark session 3 🟢 Done.
20. **Overwrite this file** ([SESSION_HANDOFF.md](SESSION_HANDOFF.md)) with session 3's accomplishments and session 4 entry point (Phase 1.A trigger implementations).

### Estimated session 3 effort

- ~3 hours of focused work
- ~1,500 lines of new Swift across `Sources/` + `Tests/`
- 1 owner review checkpoint at the end (single decision: "approved or revise")
- **Code does not need to compile in Xcode** during session 3 — Xcode is not yet installed (session 6 prerequisite). The goal is correct-looking code per spec; build verification happens in session 6.

### Cannot-start-without checks

- Read [03-state-machine.md §7](design/03-state-machine.md) (transition table) before writing `AwakeManager.swift`. The table is the spec — implement it cell-by-cell, not from intuition.
- Read [04-data-model.md §4–5](design/04-data-model.md) before writing `SettingsStore.swift`. Every key listed there must exist in `SettingsKey`.
- Read [02-architecture.md §3.2](design/02-architecture.md) (dependency rule) — `Core/` must not import SwiftUI; `Triggers/` must not import SwiftUI.

---

## Decisions still pending owner approval

**None for session 3.** All design decisions needed for code work are signed off (01 §14, 02 §14 both checked). Remaining open questions (OQ-07 ~ OQ-10) are content/marketing — they unblock launch prep in sessions 7–8 and do not block coding.

---

## Known issues / debt

| Issue | Impact | Plan |
|---|---|---|
| Skeleton in `Sources/` does not match architecture | Code is unbuildable until rewritten | Rewrite is **the** scope of session 3 |
| Folder name `Caffeinated-Clone/` doesn't match app name `Latte` | Cosmetic | Rename in session 3 step A.1 |
| Bundle ID `com.example.latte` is placeholder | Cannot ship as-is | Owner provides real reverse-domain before session 8 |
| Xcode (full) not installed locally | Cannot build/run | Owner installs before session 6 |
| No app icon yet | Cannot ship | Owner produces before session 8 |
| No Apple Developer Program enrollment | Cannot submit | Owner enrolls before session 8 |
| Stub triggers in session 3 are non-functional | Real EventKit/NSWorkspace/CoreWLAN integration arrives in session 4 | Tracked in session 4 to-do |

---

## Files changed this session

```
A  docs/design/03-state-machine.md       (561 lines)
A  docs/design/04-data-model.md          (320 lines)
M  docs/design/01-PRD.md                 (v0.1 → v0.2; OQ table + change log + sign-off)
M  docs/design/02-architecture.md        (v0.1 → v0.2; OQ table + change log + sign-off)
M  ROADMAP.md                            (v0.1 → v0.2; sessions 1+2 done; session 3 next)
M  docs/SESSION_HANDOFF.md               (overwritten for session 3 entry)
```

No code files touched. No `Sources/` changes — that is session 3.

---

## How to resume

1. Read [ROADMAP.md](../ROADMAP.md) — orientation (~30 sec).
2. Read this file — current state (~2 min).
3. Open the three spec docs in tabs and keep them open for the whole session:
   - [02-architecture.md](design/02-architecture.md) (esp. §3 module structure, §4 contracts)
   - [03-state-machine.md](design/03-state-machine.md) (esp. §7 transition table — this is the implementation spec for `AwakeManager`)
   - [04-data-model.md](design/04-data-model.md) (esp. §4–5 — this is the implementation spec for `SettingsStore`)
4. Start step A (housekeeping) → step B (Core) → … → step G (wrap).
5. TDD discipline: write each test first, watch it fail, implement, watch it pass.

If owner raised concerns about 03 or 04 in the interim, address those **first** by re-opening the relevant doc and bumping its version. Then proceed with session 3.
