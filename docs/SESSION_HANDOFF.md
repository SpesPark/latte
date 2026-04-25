# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 1 of ~10 |
| **Theme** | Foundation: PRD + Architecture |
| **Date** | 2026-04-25 |
| **Duration** | (single conversation) |
| **Status** | ✅ Completed as planned |

### What was accomplished

1. **Locked product decisions** (see [01-PRD.md §12](design/01-PRD.md))
   - App name: **Latte**
   - Min OS: **macOS 13 Ventura**
   - Pricing: **$2.99 one-time** (App Store, Small Business 15%)
   - Source: **private repo**
   - Phase scope at launch: **A (automation) + C (design)**; B (iOS) deferred to Phase 2
   - Primary persona: hybrid PM / video-call-heavy remote worker

2. **Created Tier 1 design docs**
   - [01-PRD.md](design/01-PRD.md) — 14 sections: scope, target user, KPIs, features, NFRs, risks, launch criteria, 10 open questions
   - [02-architecture.md](design/02-architecture.md) — 14 sections: module structure, concurrency model, component contracts, build/dep policy, testing strategy

3. **Resolved Open Questions**
   - OQ-05 (module boundaries): folders for v1; SPM extraction in Phase 2
   - OQ-06 (`@Observable` vs `ObservableObject`): `ObservableObject` for v1
   - Plus 6 more architectural decisions logged in [02-architecture.md §12](design/02-architecture.md)

4. **Created project-wide planning artifacts**
   - [ROADMAP.md](../ROADMAP.md) — 10-session plan with milestone gates and user-side blocking tasks
   - This handoff document

5. **Earlier in session** — created initial code skeleton (`Sources/`, `Resources/`, `Configuration/`, `Tests/`) but **this skeleton will be rewritten in session 3** to match the architecture in 02. The skeleton is kept for reference only; do not extend it before session 3.

### What was *not* done (intentionally deferred)

- 03-state-machine.md, 04-data-model.md (next session)
- Code rewrite to match new architecture (session 3)
- Git init / first commit (awaiting owner decision)
- Folder rename `Caffeinated-Clone/` → `Latte/` (before first push)

---

## Next session entry point

**Theme**: Design close-out (session 2 of ~10)

**Goal**: Resolve all remaining Open Questions before any code work. After this session, design phase is **closed** and code rewrite begins in session 3.

### To-do (in order)

1. **Open** [docs/design/01-PRD.md §11](design/01-PRD.md) — review Open Questions table; confirm OQ-01, OQ-02 are still in scope for this session and OQ-03, OQ-04 too.

2. **Create `docs/design/03-state-machine.md`**
   Resolve:
   - **OQ-01** — Priority order when multiple triggers vote `wantsAwake = true` simultaneously. Recommendation: any-OR (any positive vote → awake), with a 60-second cool-down before deactivating after the last vote drops, to avoid flapping.
   - **OQ-02** — Manual toggle vs active trigger. Recommendation:
     - Manual ON during trigger ON → no-op (already on); user feels nothing weird.
     - Manual OFF while a trigger is voting ON → user wins for 5 minutes ("snooze trigger"), then trigger reasserts.
     - Manual ON when no trigger is voting → indefinite as today.
   - State diagram (Mermaid): nodes = {Asleep, AwakeUserIndefinite, AwakeUserTimed, AwakeTriggered, AwakeTriggeredSnoozed, CoolingDown}.
   - Transition table for every input × current state.

3. **Create `docs/design/04-data-model.md`**
   Resolve:
   - **OQ-03** — Persistence: UserDefaults for v1 (matches `SettingsStore` protocol in 02). Reasons: simple, Apple-blessed for menu-bar utilities, sandbox-safe, no schema migrations.
   - **OQ-04** — UserDefaults → SwiftData migration path for Phase 2 (when iCloud sync is needed). Plan: `SettingsStore` protocol abstracts both; v2 ships `SwiftDataSettingsStore` that reads from UserDefaults on first launch and migrates.
   - Full schema: every key, type, default, validation.
   - Trigger config encoding (JSON-encoded structs in `Data` for arrays of bundle IDs, SSIDs, calendar IDs).

4. **Update sign-off checklists** in 01-PRD.md §14 and 02-architecture.md §14 once owner approves.

5. **Update [ROADMAP.md](../ROADMAP.md)** — mark session 1 complete, mark session 2 in-progress.

6. **Update this file** ([SESSION_HANDOFF.md](SESSION_HANDOFF.md)) with session 2's accomplishments and session 3 entry point.

### Estimated session 2 effort

- ~2 hours of focused work
- ~600 lines of new doc content (300 each for state-machine and data-model)
- 1 owner review checkpoint at the end (single decision: "approved or revise")

---

## Decisions still pending owner approval

These are **drafted in design docs but not yet signed off**. Owner should review 01 and 02 before session 2 begins:

| Doc | Section | What to confirm |
|---|---|---|
| 01-PRD.md | §5 KPIs | Are Year 1 targets (3,000 downloads, ₩1,067만) reasonable? |
| 01-PRD.md | §6 Feature scope | Anything missing from MVP / Phase 1.A / Phase 1.C? |
| 01-PRD.md | §10 Launch Criteria | Acceptable bar for v1 launch? |
| 01-PRD.md | §14 Sign-off | Tick the 5 boxes once reviewed |
| 02-architecture.md | §3 Module structure | Folder layout acceptable? |
| 02-architecture.md | §4 Component contracts | Public APIs make sense? |
| 02-architecture.md | §10 Skeleton ↔ architecture gap | OK to rewrite skeleton in session 3? |
| 02-architecture.md | §14 Sign-off | Tick the 5 boxes once reviewed |

If any answer is "no, revise", **session 2 starts with revising 01 or 02 before creating 03/04**.

---

## Known issues / debt

| Issue | Impact | Plan |
|---|---|---|
| Skeleton in `Sources/` does not match architecture | Code is unbuildable until rewritten | Rewrite in session 3 (planned) |
| Folder name `Caffeinated-Clone/` doesn't match app name `Latte` | Cosmetic | Rename before first git push |
| Bundle ID `com.example.latte` is placeholder | Cannot ship as-is | Owner provides real reverse-domain before session 8 |
| Xcode (full) not installed locally | Cannot build/run | Owner installs before session 6 |
| No app icon yet | Cannot ship | Owner produces before session 8 |
| No Apple Developer Program enrollment | Cannot submit | Owner enrolls before session 8 |

---

## Files changed this session

```
A  ROADMAP.md
A  README.md (overwrote earlier draft)
A  docs/SESSION_HANDOFF.md
A  docs/design/01-PRD.md
A  docs/design/02-architecture.md
A  Sources/CaffeinatedApp.swift            ← skeleton, will rewrite
A  Sources/AwakeManager.swift              ← skeleton, will rewrite
A  Sources/PowerAssertion.swift            ← skeleton, will rewrite
A  Sources/Duration.swift                  ← skeleton, will rewrite
A  Sources/MenuBarView.swift               ← skeleton, will rewrite
A  Sources/SettingsView.swift              ← skeleton, will rewrite
A  Sources/CoffeeCupView.swift             ← skeleton, will rewrite
A  Sources/Triggers/TriggerProtocol.swift  ← skeleton, will rewrite
A  Sources/Triggers/CalendarTrigger.swift  ← skeleton, will rewrite
A  Sources/Intents/AwakeIntents.swift      ← skeleton, will rewrite
A  Resources/Info.plist
A  Resources/Assets.xcassets/Contents.json
A  Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
A  Resources/Assets.xcassets/AccentColor.colorset/Contents.json
A  Configuration/Caffeinated.entitlements  ← rename to Latte.entitlements before session 3
A  Tests/AwakeManagerTests.swift           ← skeleton, will rewrite
A  project.yml
A  .gitignore
```

---

## How to resume

1. Read [ROADMAP.md](../ROADMAP.md) — orientation (~30 sec).
2. Read this file — current state (~1 min).
3. Open [docs/design/01-PRD.md §11](design/01-PRD.md) — see what Open Questions are still open.
4. Open [docs/design/02-architecture.md §11](design/02-architecture.md) — see what's resolved already.
5. Start session 2 work: create `03-state-machine.md` per the to-do list above.

If owner raised concerns about 01 or 02 in the interim, address those **first**, then proceed.
