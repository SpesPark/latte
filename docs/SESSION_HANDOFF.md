# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S38 (2026-05-18) — §13 SettingsKey doc-tidy + RFC §12 owner decisions locked (Phase 1 unblocked)
**v1.x release line:** v1.9 (unchanged since S20 — S38 is docs/design only)
**Branch:** `claude/focused-hamilton-417bfc` — ahead of `origin/main` by S36 + S37 + S38 docs commits. Push = owner action; push the **branch tip**. *(Exact count deliberately not frozen — a number written into a doc is invalidated by the commit that writes it, the recursion S36 hit. Authoritative: `git rev-list --count origin/main..HEAD`.)* **This one branch supersedes the standalone `claude/suspicious-kowalevski-4ffca8`** (S36-only prefix — push *this* branch, S36 rides along; old branch ignorable/deletable).
**Test count:** 611/611 PASS (unchanged — S38 touched no code)
**Smoke:** 23 scenarios (not re-run — design-only session changes no UI)
**Doc-drift:** clean
**Catalog:** 172 keys × 11 languages, ru 4 CLDR forms — unchanged (not touched in S38)

---

## Last session (S38)

S38 ran the two ADP-independent items the S37 handoff had identified — the
"§13 doc-tidy (zero gate)" and the "§12 owner decisions (owner-gated, not
Apple-gated)" — back to back, owner present. Both docs-only; 611 unchanged.

**What landed (2 commits on `claude/focused-hamilton-417bfc`, push = owner action):**

- **`2b276bf`** — `docs(design): sync 04-data-model §5 SettingsKey snapshot
  with source (24 → 34 cases)`. The §5 enum snapshot predated **10** shipped
  keys (RFC §13 estimated "~7"; actual: coffeeAccent, hasSeededAppDefaults,
  externalDisplay{Enabled,Whitelist}, keyboardShortcutEnabled, shortcutChord,
  activityRetentionDays, activityChartColors, recurringQuickPresets,
  didSeedBuiltinPresets). Now exact parity with
  `Sources/Core/SettingsStore.swift` (34 cases incl. `, Sendable`) **plus a
  new authoritative-source pointer** so the snapshot is explicitly a curated
  reader-aid and `SettingsKey.allCases` is the single source of truth — the
  drift-proofing the RFC's own §10/§13 principle implied. Closes the doc-tidy
  RFC §13 deliberately deferred.
- **`b61015b`** — `docs(design): record RFC §12 owner decisions — Phase 1
  unblocked`. Owner answered the three code-gating questions:
  **Q1 = B-2** (activity log → CloudKit custom-zone append-only union merge;
  Phase 3 in scope), **Q2 = approved** (§5.1 privacy sign-off; "No Data
  Collected" preserved), **Q5 = v2.0 = Phase 1+2, Phase 3 = v2.1**. §12
  rewritten as a decision log (Q3 resolved-by-Q5; **Q4 container-id remains
  open + explicitly non-gating**). RFC header/intro/§11-Phase-0/§14 +
  07-spec §1 + 09-c3 §14 cross-refs all flipped from "owner decision
  pending" → "decisions locked 2026-05-18". RFC bumped 0.1 → 0.2.

**Gate effect — the important carry-over:** iCloud-sync **Phase 1 is now an
actionable autonomous session** (no longer owner-decision-gated). Phase 1 =
`CloudSyncEngine` protocol seam + `MockCloudSyncEngine` + entitlement file +
`cloudKitDatabase` wiring **behind the compile-time kill-switch — ships dark,
zero behaviour change**, 100% pure-unit-testable per RFC §10. It does **not**
need the Apple Developer Program (entitlement file only; container stubbable
until S8.5). Phase ≥ 2 (live CloudKit) stays S8.5-gated.

**Patterns reinforced this session — S38 NEW (2):**

a. **A "separate doc-tidy, not gating" deferral in an RFC is itself a
   zero-gate autonomous unit — do it, don't just re-defer.** RFC §13's
   explicitly-scoped, non-gating drift is exactly the kind of small, real,
   prerequisite-free work that survives the "don't invent work" filter
   *because the RFC already identified it*. Fixing a stale inlined snapshot:
   add an authoritative-source pointer so it can't silently re-drift, don't
   just refresh the copy.
b. **"Owner-decision-gated" ≠ "blocked" when the owner is in the session.**
   The S37 handoff filed §12 under the same queue as the Apple blocks; they
   are categorically different — §12 needed 3 answers obtainable *now*, and
   answering them converted the single largest remaining autonomous item
   (iCloud Phase 1) from blocked to actionable. Always separate
   owner-*decision* gates from owner-*Apple* gates when triaging the queue.

Cumulative NEW S20→S38 ≈ 57.

---

## Prior session (S37)

S37 was an autonomous session opened on top of S36. Goal: progress the
genuinely autonomous backlog with maximal verification safety. Outcome: the
single remaining substantive autonomous item — the long-deferred iCloud-sync
**joint design** — delivered as an RFC-first, **zero-code** design doc, plus a
full verification sweep of the inherited state.

### What landed this session

Two substantive commits on `claude/focused-hamilton-417bfc` (plus this docs wrap `e3956fa` = 3 S37 commits total; push = owner action):

- **`9598eba`** — `docs(design): C-3/B1.2/Settings iCloud sync joint-design RFC`.
  New [`docs/design/10-c3-icloud-sync-rfc.md`](design/10-c3-icloud-sync-rfc.md)
  resolves the iCloud-sync deferral recorded in 09-c3 §14 and 07-spec §1. Core
  design: **one CloudKit entitlement/migration event** (the OQ-04 v2.0
  UserDefaults→SwiftData migration from 04-data-model §2.2) covering **two
  independent sync domains** — Settings (last-writer-wins, includes the B1.2
  chord with per-device best-effort registration + optional non-synced local
  override) and the Activity log (recommended: CloudKit custom-zone
  **append-only union merge**, never LWW, immutable content-addressed entries,
  local 14-day GC on the merged set). Privacy analysis shows "No Data
  Collected" is **preserved** (private DB only, no developer-side processing,
  the existing S14 structured-`reasonCode` discipline already excludes all
  PII). A `CloudSyncEngine` protocol seam mirrors the codebase's existing
  mock pattern (`SettingsStore`/`HotKeyRegistrar`/`DisplaySource`) so
  merge/LWW/migration/chord-fallback are 100% pure-unit-testable without
  CloudKit; only final two-Mac confirmation is owner-gated. Ships dark behind a
  compile-time kill-switch. Blocks on S8.5. **09-c3 §14 and 07-spec §1 now
  cross-reference the RFC** so the joint design is discoverable from the docs
  that deferred it.

- **`35104b8`** — `docs(design): RFC precision pass`. Consistency audit of the
  RFC against the docs it extends. Two precision fixes, **no design change**:
  §8 fallback window pinned to the exact 04-data-model §2.2 wording
  (UserDefaults read-only through v2.0, deleted in **v2.1** after one minor
  release); §1 adds an explicit reconciliation that this RFC **is** the
  v2-backlog "Re-evaluate post-v1.0 ship" gate firing (not a contradiction of
  the non-goals list) and that PRD §7.4 "no telemetry / local-first" is
  permanent and *preserved*, not traded away.

### What was verified but not changed

- **Inherited baseline on S36 tip**: `pkill -9 -f "Latte.app"` pre-flight →
  `xcodebuild test` **611/611 PASS** (~12s); `check_doc_drift.sh --strict`
  clean; catalog 172 keys; ru `%lld minutes`/`%lld hours`/`Currently: %lld
  external displays` each carry one/few/many/other. (Project regenerated via
  `xcodegen generate` — the worktree had no `.xcodeproj`; expected for a fresh
  worktree.)
- **Full catalog completeness sweep**: 172 keys × 10 target locales = **1720
  cells, zero missing/empty** (plural-aware). The 3 plural keys all carry
  correct `variations.plural`. The inherited i18n state is complete and
  self-consistent.
- **LanguageStep defer-and-watch item — empirically CLOSED.** Onboarding
  `languageStep` uses exactly 2 localized strings ("Choose your language" +
  the restart caption); **no bullets** (the "bullet review" carry-over from S34
  referred to the helper caption). Both have full 11-locale coverage, and
  `LocalizationCatalogTests.testEveryEntryCoversAllPhaseHLanguages()` *already*
  asserts the every-key × every-locale non-empty invariant (plural-aware) and
  is in the green 611. No code/test change warranted — adding another guard
  would duplicate an existing one.
- **RFC↔existing-docs consistency**: every RFC cross-reference checked against
  04-data-model §2.2 (migration steps 1-6, schemaVersion 1→2, v2.1 deletion,
  the `grep UserDefaults` lint rule), PRD §7.4 (no-telemetry non-goal), 09-c3
  §3/§6/§7 (decoupled JSON store, privacy exclusions, version wrapper), 07-spec
  §1/§2 (`register(chord:)` API, S17 "J" disabled-cue), and v2-backlog
  Won't-do line 319. **No contradictions found.**

### Patterns reinforced this session

S37 NEW (4):

a. **RFC-first is the correct autonomous move for a "solo ship risks migration
   churn" deferral.** When a feature was deferred *specifically* because
   piecemeal shipping endangers a one-time schema migration, the highest-value
   autonomous action is a design-only RFC that unifies the migration event —
   not code. Zero code = zero regression = it *protects* the very
   verification-safety the deferral existed to guard.
b. **CloudKit *private* DB preserves Apple's "No Data Collected" label.** Data
   in the user's own private CloudKit database with no developer-side
   processing is not "developer collection" under App Store privacy semantics.
   Load-bearing for all future sync work. The S14 structured-`reasonCode`
   boundary already excludes PII, so it carries over for free once entries
   leave the single device.
c. **An append-only log must never ride a last-writer-wins sync path.** The
   two-domain split (Settings = LWW, Activity = union-merge) is a *structural*
   data-loss guard, not a stylistic choice — funnelling both through one
   generic "sync the blob" mechanism silently destroys concurrent-day history.
d. **"Re-evaluate post-X" in a Won't-do list is a gate, not a refusal.** An RFC
   opened against such an item is the gate firing; state that explicitly in the
   doc so a future reader doesn't misread the RFC as contradicting the
   non-goals list.

Cumulative NEW S20→S37 ≈ 55.

### What was deferred / why the autonomous backlog is now terminal

The single-session autonomous backlog is **exhausted at the RFC boundary**. The
RFC is the *last* autonomous deliverable: its next step (Phase 1 code) requires
the owner to answer RFC §12 (Q1 activity-log scope, Q2 privacy sign-off, Q5
phase ordering). Everything else remaining is owner-Apple-blocked (S8.5/S9) or
owner-decision-gated. Inventing further work to consume context would be
net-negative churn against the "don't add work beyond what's needed" principle —
so S37 stops here deliberately, not prematurely.

---

## Next-session entry points (priority order)

**1. (AUTONOMOUS, large — now actionable)** **iCloud-sync Phase 1.** §12 is
decided (S38), so this is unblocked and needs **no Apple prerequisite**.
Scope (RFC §11 row 1): `CloudSyncEngine` protocol + `MockCloudSyncEngine` +
entitlement file + `cloudKitDatabase` wiring **behind the compile-time
kill-switch — ships dark, zero behaviour change**. Verify: full unit suite
green + app behaviour identical with sync off (cheapest phase to verify —
changes nothing observable). Design contract is RFC §3/§4(B-2)/§6/§7/§10;
Q1=B-2, Q5=v2.0[P1+2]/v2.1[P3] are locked. **Read RFC §10 + §11 before
starting.** Q4 (container-id `iCloud.com.parkbyeongjun.latte`) is non-gating
— inject it via the seam; literal lives in one adapter + the entitlement
file. This is the single largest remaining autonomous deliverable.

**2. (BLOCKER, owner-side)** **S8.5 Apple Developer Program** — check email +
portal; if past ~Day 16 of the wait, call Developer Support. Gates S9 *and*
iCloud-sync Phase ≥ 2 (live CloudKit). Does **not** gate Phase 1 (#1).

**3. (BLOCKER, owner-side)** **S9 App Store Connect metadata** — depends on
S8.5. Includes deferred S8d screenshot picking.

The autonomous-OPTIONAL i18n queue is empty and *verified* empty (S37 catalog
sweep). After Phase 1 ships, Phase 2/3 are S8.5-gated. Q4 is the only open
RFC item and is non-gating.

---

## Cold-start (다음 세션 진입)

S31's one-command ritual still applies: `latte` (zsh alias) or
`bash ~/Documents/Claude/Projects/Latte/scripts/latte-resume.sh`.

```bash
# PRE-FLIGHT (MANDATORY before any xcodebuild test / Cmd-R) — kill stale Latte.
# A surviving Latte.app + LSMultipleInstancesProhibited makes the test host
# launch fail "Could not launch LatteTests" (LaunchServices) — NOT a code
# regression. See feedback_smoke_iteration.md §5. Re-hit at S36 cold-start.
pkill -9 -f "Latte.app" 2>/dev/null; sleep 1

# A FRESH WORKTREE HAS NO .xcodeproj — generate it first (xcodegen project):
xcodegen generate

# IMPORTANT in a git worktree: edit + test the worktree path, NOT the repo
# root. Absolute repo-root paths resolve to the main checkout (S36 footgun;
# feedback_smoke_iteration.md §7). Verify: git -C <worktree-path> status

# Tests (~12s, expect 611 PASS)
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed"

# Catalog summary (expect 172 keys; ru 3 plural keys each one/few/many/other)
python3 -c "
import json
d=json.load(open('Resources/Localizable.xcstrings'))
print('keys:',len(d['strings']))
ru=d['strings']['%lld minutes']['localizations']['ru']['variations']['plural']
print('ru %lld minutes forms:',sorted(ru.keys()))  # [few, many, one, other]
"

# Doc drift
scripts/check_doc_drift.sh

# Bundle pre-flight + smoke (~7min, expect 23/23) — owner-side, GUI-gated
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/Latte-*/Build/Products/Release/Latte.app | head -1)
~/dev/smoke-harness/lib/assert_bundle_resources.sh "$APP" 11 cold-start-check
~/dev/smoke-harness/run.sh --project .
```

**Expect**: 611/611 PASS; doc-drift clean; 172 keys × 11 langs; ru 4 CLDR forms.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.31 → 1.38 (S31–S38) for the i18n + infrastructure +
   iCloud-RFC + decision-lock lineage.
3. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)**
   before any iCloud-sync work — authoritative joint design; §12 is now a
   **decision log** (Q1/Q2/Q5 locked 2026-05-18), §10/§11 define the Phase 1
   test surface and scope.
4. Memory: `MEMORY.md` → `project_latte_v1_9.md` S20→S38 section.
5. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S38 update)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8.5 | Apple Developer Program — applied 2026-05-02 | Apple wait. Check email + portal; if past ~Day 16, call Developer Support | 1-2 days typical |
| S9 | App Store Connect metadata + screenshots + binary submission | S8.5 depends | 1-3 sessions once unblocked |
| **Push branch** | **`claude/focused-hamilton-417bfc`** — S36 + S37 + S38 docs commits. Push the **branch tip** (count via `git rev-list --count origin/main..HEAD`). Standalone `claude/suspicious-kowalevski-4ffca8` redundant — ignore/delete. | none — ready | seconds |
| ~~iCloud RFC §12~~ | **DONE 2026-05-18 (S38)** — Q1=B-2, Q2=approved, Q5=v2.0[P1+2]/v2.1[P3]. Phase 1 now autonomous. | — | ✅ |
| iCloud RFC Q4 | Container-id `iCloud.com.parkbyeongjun.latte` — accept at Phase 1 kickoff (non-gating; hold only if V2-20 changes bundle prefix) | owner, non-gating | 1 answer |
| Smoke 23 re-run | First run incl. 00- pre-flight; S37/S38 changed no UI so no scenario delta expected | none | 7 min |
| Phase I community PRs | TRANSLATIONS.md; Russian is the worked reference | awaiting community | ongoing |

---

## v1.9 owner-visible behaviour reference (post-S38)

**No owner-visible change in S38.** Design-doc + decision-recording only —
zero code, zero UI, zero test delta (611 unchanged). Russian-locale plural
correctness from S36 stands. All other surfaces unchanged from the S35/S36
reference.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` already implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S36. Pages live at https://spespark.github.io/latte/ +
/privacy.html. Cross-project helper
`~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario
`.smoke/scenarios/00-bundle-integrity.sh` (S35).
