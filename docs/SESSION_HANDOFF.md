# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S37 (2026-05-18) — iCloud-sync joint-design RFC + inherited-baseline & catalog verification
**v1.x release line:** v1.9 (unchanged since S20 — S37 is docs/design only)
**Branch:** `claude/focused-hamilton-417bfc` — **5 commits ahead of `origin/main`** = S36 (`2fa0668`, `4309cd3`) **+** S37 (`9598eba`, `35104b8`, `e3956fa` this wrap). Push = owner action. **This one branch supersedes the standalone `claude/suspicious-kowalevski-4ffca8`** (that branch is now a 2-commit prefix of this one — push *this* branch and the S36 work rides along; the old S36-only branch can be ignored/deleted).
**Test count:** 611/611 PASS (unchanged — S37 touched no code)
**Smoke:** 23 scenarios (not re-run — gated by harness; design-only session changes no UI)
**Doc-drift:** clean
**Catalog:** 172 keys × 11 languages, ru 4 CLDR forms — **verified, not modified**

---

## Last session

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

**1. (BLOCKER, owner-side)** **S8.5 Apple Developer Program** — check email +
portal; if past ~Day 16 of the wait, call Developer Support. Gates S9 *and*
iCloud-sync Phase ≥ 2.

**2. (BLOCKER, owner-side)** **S9 App Store Connect metadata** — depends on
S8.5. Includes deferred S8d screenshot picking.

**3. (owner-decision, then autonomous)** **iCloud-sync RFC §12** — owner answers
Q1 (activity-log: B-2 union-merge vs B-1 device-local), Q2 (privacy sign-off on
SSID/bundle-id in private DB), Q5 (phase ordering). Once answered, Phase 1
(`CloudSyncEngine` protocol seam + mock + entitlement plumbing behind the
kill-switch — *ships dark, no behaviour change*) becomes a clean autonomous
implementation session with a fully pure-unit-testable surface.

**4. (autonomous, large)** **iCloud-sync Phase 1** — only after #3. Cheapest
phase to verify (changes nothing observable). See RFC §11.

The autonomous-OPTIONAL i18n queue is empty and now *verified* empty (S37
catalog sweep). The remaining queue is owner-Apple-blocked or owner-decision-
gated (#3).

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
2. `ROADMAP.md` rows 1.31 → 1.37 (S31–S37) for the i18n + infrastructure +
   iCloud-RFC lineage.
3. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)**
   before any iCloud-sync work — it is the authoritative joint design; §12 lists
   the owner decisions that gate code.
4. Memory: `MEMORY.md` → `project_latte_v1_9.md` S20→S37 section.
5. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S37 update)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8.5 | Apple Developer Program — applied 2026-05-02 | Apple wait. Check email + portal; if past ~Day 16, call Developer Support | 1-2 days typical |
| S9 | App Store Connect metadata + screenshots + binary submission | S8.5 depends | 1-3 sessions once unblocked |
| **Push branch** | **`claude/focused-hamilton-417bfc`** — **5 commits** = S36 (`2fa0668`,`4309cd3`) + S37 (`9598eba`,`35104b8`,`e3956fa`). Push **this one branch** (it contains S36). The standalone `claude/suspicious-kowalevski-4ffca8` is now redundant — ignore/delete it. | none — ready | seconds |
| iCloud RFC §12 | Owner answers Q1/Q2/Q5 to unblock Phase 1 | owner decision | 1 reading + 3 answers |
| Smoke 23 re-run | First run incl. 00- pre-flight; S37 changed no UI so no scenario delta expected | none | 7 min |
| Phase I community PRs | TRANSLATIONS.md; Russian is the worked reference | awaiting community | ongoing |

---

## v1.9 owner-visible behaviour reference (post-S37)

**No owner-visible change in S37.** It is design-doc + verification only —
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
