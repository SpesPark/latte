# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S39 (2026-05-22) — whole-app audit + audit-driven stabilization (Steps 1-3 of the recommended order)
**v1.x release line:** v1.9 (unchanged — S39 has code changes but no version bump; unreleased on the branch)
**Branch:** `claude/focused-hamilton-417bfc` — ahead of `origin/main` by S36 + S37 + S38 + **S39** commits. Push = owner action; push the **branch tip**. *(Exact count deliberately not frozen — authoritative: `git rev-list --count origin/main..HEAD`.)* Supersedes the standalone `claude/suspicious-kowalevski-4ffca8` (S36-only prefix).
**Test count:** 619/619 PASS (was 611 — S39 added 8: 5 AppIntents, 1 Calendar overlap, 1 PowerSource fan-out, 1 TriggerCoordinator ordering)
**Smoke:** 23 scenarios (not re-run — UI behaviour unchanged by S39's fixes; dark/internal only)
**Doc-drift:** clean (now also asserts `Sources/Core` is SwiftUI-free)
**Catalog:** 172 keys × 11 languages, ru 4 CLDR forms — unchanged

---

## Last session (S39)

Owner asked for a thorough whole-app verification before opening iCloud Phase 1.
S39 ran a **5-stream parallel audit** (code-quality, security, concurrency,
architecture/test-gaps, compiler-warnings), **self-verified the top findings
by direct file reads** (agent summaries are intent, not fact), then executed
the cheap-high-value fixes with **regression-test-per-fix**. **Audit verdict:
0 CRITICAL; the codebase is healthy.** These are the **first code changes
since S20** (S21-S38 were i18n/docs/design).

**Step 1 — stabilization (6 commits):**
- `d4c7007` `fix(security)` — drop unused `network.client` entitlement (no
  network code anywhere in Sources/; it only widened the sandbox + invited an
  App Store reviewer question against No-Data-Collected).
- `423e331` `fix(core)` — stop trapping **SIGABRT** (it suppressed the OS crash
  report *and* spawned a Task from an already-faulting runtime; the kernel
  releases the IOPMAssertion on process death regardless). SIGINT/SIGTERM kept.
- `888b2f3` `fix(triggers)` — post `.activityLogDidAppend` only **after** the
  append `await` commits. The old comment claimed actor-FIFO ordering
  guaranteed it; in reality the unstructured Task only worked via the
  consumer's 300 ms debounce. + contract test.
- `f749818` `fix(core)` — snapshot power-source observers (`Array(...)`) before
  fan-out; a callback that cancels its observation mutated the dict
  mid-iterate. + cancel-during-callback test.
- `7d6297a` `fix(triggers)` — guard WiFi `requestAccess` against the
  continuation overwrite-leak (a concurrent second call stranded the first
  coroutine forever). **The `requestAlways→WhenInUse` downgrade is deferred**
  (owner device-smoke gated — see pending table).
- `5446104` `docs(activity)` — drop the dead `ExportButtons` tombstone comment.

**Step 2 — test-gap fills (2 commits):**
- `ecd5ba9` `test(intents)` — Toggle/Start/Stop `perform()` incl. the 1 & 1440
  minute bounds. AppIntents (Shortcuts/Spotlight) were the only UI-independent
  entry point and had **0 tests**.
- `bbc4448` `test(calendar)` — overlapping-event OFF suppression: when a short
  event ends while a longer one is still active, no OFF vote (guards the
  `&& activeIDs.isEmpty` branch; back-to-back meetings must not sleep the Mac).

**Step 3 — architecture prep for iCloud (2 commits):**
- `21db227` `refactor(core)` — moved `ActivityChartPalette`'s `Color` rendering
  out of `Sources/Core` (Core's *only* `import SwiftUI`, violating 02-arch §3.2
  and blocking the OQ-04 SwiftData lift). Pure data/JSON stays in Core; the
  `Color` extension + `color(for:)` move to a UI-layer file. Same module →
  behaviour and tests unchanged.
- `d2693e2` `ci(drift)` — guard `Sources/Core` against `import SwiftUI` in
  `check_doc_drift.sh --strict` so the layering can't silently re-regress.

**Export-claim correction (docs/memory):** git shows CSV/JSON export was added
S15 (`86bc5b1`) and **removed S24 (`0e13546`, non-functional)**. Memory v1.3.1
+ 09-c3 changelog had recorded it as shipped; both corrected. No exporter
exists in current code (so there is *no* path-traversal export surface — a
security non-issue). README counts refreshed (610→619 tests, 22→23 smoke).

**Deliberately deferred — each deserves a dedicated full-budget session
(rushing risks regressions in delicate code):**
- **Step 4 — Swift 6 strict-concurrency migration.** 13 build warnings ("error
  in Swift 6 language mode"), concentrated in **nonisolated-deinit teardown**
  (TriggerCoordinator observers, ExternalDisplayTrigger observer, AwakeManager
  `powerObservation`) and **`@Sendable` closures capturing `@MainActor`
  closures** (FocusTrigger:74-75, AppTrigger:193,204). This is the exact
  concurrency code prior sessions tuned (phantom-count, FIFO) — do it as a
  focused session, ideally by flipping `SWIFT_STRICT_CONCURRENCY`/Swift 6 mode
  and fixing everything that surfaces, not 13 spot-patches.
- **Step 5 — iCloud Phase 1** (the major deliverable; see entry points).

**S39 NEW patterns (4):**
a. **Whole-app audit = fan out non-overlapping split-role agents, then
   self-verify the top findings by direct read.** Re-reading caught that
   "no export code" was a genuinely *removed* feature (not an agent oversight),
   and downgraded a reported "HIGH silent-data-loss" to LOW once the reality
   that `[String]` JSON-encode can't fail was confirmed.
b. **A permission/entitlement change that can't be unit-verified is
   owner-device-smoke-gated, not an autonomous edit.** Applied the safe WiFi
   continuation-guard; deferred the `requestAlways→WhenInUse` downgrade because
   CoreWLAN `ssid()` resolution under When-In-Use needs a real Mac
   (mock/production parity).
c. **Stop at a clean, fully-committed, fully-green boundary rather than start a
   large risky item with too little budget to finish.** A half-done concurrency
   refactor is worse than a clean handoff; "use context fully" ≠ "begin work
   you can't land cleanly."
d. **post-after-await converts an *accidental* ordering guarantee into a real
   one** — leaning on a downstream debounce to mask an unstructured-Task race
   is the kind of invariant a future eager consumer silently breaks.

Cumulative NEW S20→S39 ≈ 61.

---

## Next-session entry points (priority order)

**1. (AUTONOMOUS, large) — iCloud-sync Phase 1.** RFC §12 is decided (S38);
unblocked, needs **no Apple prerequisite**. S39 already cleared the §3.2
Core/SwiftUI blocker the Phase 2 SwiftData lift depends on. Scope (RFC §11
row 1): `CloudSyncEngine` protocol + `MockCloudSyncEngine` + entitlement file +
`cloudKitDatabase` wiring **behind the compile-time kill-switch — ships dark,
zero behaviour change**, 100% pure-unit-testable per RFC §10. Container id
`iCloud.com.parkbyeongjun.latte` (Q4, non-gating) injected via the seam. **Read
[docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md) §10+§11
before starting.**

**2. (AUTONOMOUS, medium — alternative / recommended-before-Phase-1) — Swift 6
strict-concurrency migration.** Clears the 13 warnings (Step 4 above) so Phase 1
adds concurrency code onto a clean base. Higher care required (delicate
teardown code). Either #1 or #2 is a valid next move — owner's call.

**3. (BLOCKER, owner-side) S8.5 Apple Developer Program** — gates S9 *and* iCloud
Phase ≥ 2 (live CloudKit). Does **not** gate Phase 1 (#1).

**4. (BLOCKER, owner-side) S9 App Store Connect metadata** — depends on S8.5.

The autonomous-OPTIONAL i18n queue is empty and verified empty (S37 catalog sweep).

---

## Cold-start (다음 세션 진입)

S31's one-command ritual still applies: `latte` (zsh alias) or
`bash ~/Documents/Claude/Projects/Latte/scripts/latte-resume.sh`.

```bash
# PRE-FLIGHT (MANDATORY before any xcodebuild test / Cmd-R) — kill stale Latte.
# A surviving Latte.app + LSMultipleInstancesProhibited makes the test host
# launch fail "Could not launch LatteTests" (LaunchServices) — NOT a code
# regression. See feedback_smoke_iteration.md §5.
pkill -9 -f "Latte.app" 2>/dev/null; sleep 1

# A FRESH WORKTREE HAS NO .xcodeproj — generate it first (xcodegen project):
xcodegen generate

# IMPORTANT in a git worktree: edit + test the worktree path, NOT the repo
# root. Absolute repo-root paths resolve to the main checkout (S36 footgun;
# feedback_smoke_iteration.md §7). Verify: git -C <worktree-path> status

# Tests (~12s, expect 619 PASS)
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed"

# Catalog summary (expect 172 keys; ru 3 plural keys each one/few/many/other)
python3 -c "
import json
d=json.load(open('Resources/Localizable.xcstrings'))
print('keys:',len(d['strings']))
ru=d['strings']['%lld minutes']['localizations']['ru']['variations']['plural']
print('ru %lld minutes forms:',sorted(ru.keys()))  # [few, many, one, other]
"

# Doc drift (now also checks Sources/Core is SwiftUI-free)
scripts/check_doc_drift.sh
```

**Expect**: 619/619 PASS; doc-drift clean (incl. Core-layering ✓); 172 keys × 11
langs; ru 4 CLDR forms.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.31 → 1.39 (S31–S39) for the i18n + infra + iCloud-RFC +
   decision-lock + audit-stabilization lineage.
3. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)**
   before any iCloud-sync work — §12 is a decision log (Q1/Q2/Q5 locked
   2026-05-18); §10/§11 define the Phase 1 test surface and scope.
4. Memory: `MEMORY.md` → `project_latte_v1_9.md` S20→S39 section.
5. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S39 update)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8.5 | Apple Developer Program — applied 2026-05-02 | Apple wait. Check email + portal; if past the typical window, call Developer Support | 1-2 days typical |
| S9 | App Store Connect metadata + screenshots + binary submission | S8.5 depends | 1-3 sessions once unblocked |
| **Push branch** | **`claude/focused-hamilton-417bfc`** — S36 + S37 + S38 + S39 commits. Push the **branch tip** (count via `git rev-list --count origin/main..HEAD`). Standalone `claude/suspicious-kowalevski-4ffca8` redundant — ignore/delete. | none — ready | seconds |
| WiFi WhenInUse | Downgrade `requestAlwaysAuthorization` → `requestWhenInUseAuthorization` (lower privilege, matches usage-string) — needs a real Mac to confirm CoreWLAN `ssid()` still resolves under When-In-Use | owner device smoke | 1 edit + 1 smoke |
| iCloud RFC Q4 | Container-id `iCloud.com.parkbyeongjun.latte` — accept at Phase 1 kickoff (non-gating) | owner, non-gating | 1 answer |
| Smoke 23 re-run | S37/S38/S39 changed no UI; no scenario delta expected | none | 7 min |
| Phase I community PRs | TRANSLATIONS.md; Russian is the worked reference | awaiting community | ongoing |

---

## v1.9 owner-visible behaviour reference (post-S39)

**No owner-visible behaviour change in S39.** All fixes are internal robustness
(signal handling, activity-log ordering, power fan-out, WiFi continuation
guard), an entitlement removal (no functional effect — the capability was
unused), an internal refactor (ActivityChartPalette Core/UI split, same
behaviour), and test additions. The cup, menu bar, triggers, Settings, Activity,
and ⌘⇧L all behave exactly as the S35/S36 reference.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` already implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S38. Pages live at https://spespark.github.io/latte/ +
/privacy.html. Cross-project helper
`~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario
`.smoke/scenarios/00-bundle-integrity.sh` (S35).
