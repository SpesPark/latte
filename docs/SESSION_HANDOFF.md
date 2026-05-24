# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S40 (2026-05-24) — Swift 6 strict-concurrency migration (S39's deferred Step 4)
**v1.x release line:** v1.9 (unchanged — S40 is a language-mode migration, no version bump, no owner-visible behaviour change)
**Branch:** `claude/focused-hamilton-417bfc` — ahead of `origin/main` by S36 + S37 + S38 + S39 + **S40**. Push = owner action; push the **branch tip**. *(Exact count: `git rev-list --count origin/main..HEAD`.)*
**Test count:** 619/619 PASS (unchanged — S40 fixed test *code* under Swift 6, added no tests)
**Smoke:** 23 scenarios (not re-run — S40 changes no runtime behaviour; internal/compile-time only)
**Doc-drift:** clean (incl. Core SwiftUI-free)
**Catalog:** 172 keys × 11 languages — unchanged
**Toolchain:** Xcode 26.5 / Swift 6.3.2 (drifted up from the memory's recorded 26.4.1 — corrected in `project_latte_status.md`)

---

## Last session (S40)

Owner picked the **Swift 6 migration first** (vs. iCloud Phase 1) so Phase 1 lands on a
clean concurrency base. Approach per S39's recommendation: **flip the language mode and
fix everything that surfaces, not 13 spot-patches.** `project.yml` `SWIFT_VERSION` 5.10 →
**6.0**.

**App-side (the 13 S39-flagged warnings → 0):**
- **Category A — `isolated deinit` (SE-0371) ×4 sites.** A `@MainActor` class's `deinit`
  is `nonisolated` by default, so it can't touch a non-Sendable `@MainActor`-isolated
  stored property. `isolated deinit` runs teardown on the main actor:
  `AwakeManager` (`powerObservation`), `NSScreenSource`/ExternalDisplayTrigger (`observer`),
  `TriggerCoordinator` (`pauseLiftObserver` + `userDeactivateObserver`). All these objects
  are released on the main actor in practice → deinit runs synchronously → **no behaviour
  change.**
- **Category B — only `FocusTrigger.observe` needed a real edit:** moved the
  `self.isFocusActive` read *inside* the `Task { @MainActor }` hop instead of the
  `@Sendable` KVO block. The `AppTrigger` `onLaunch`/`onTerminate` and the FocusTrigger
  `onChange` *captures* the S39 audit flagged **resolved on their own** under Swift 6 —
  **SE-0434 makes `@MainActor` closures `Sendable`**, so capturing them in a `@Sendable`
  NotificationCenter/KVO block is fine.
- **Category C — the 2 ObjectiveC `@preconcurrency` hints cleared as a side-effect** of
  fixing the deinit isolation (no `@preconcurrency` import needed).

**Test-target (flipping the *whole* project surfaced test-only concurrency issues; fixed
for a genuinely clean base):**
- **`@unchecked Sendable` class box** for counters/clocks captured in `@Sendable` closures —
  `OnboardingStateTests` (`CallCounter`), `TriggerCoordinatorActivityLogTests` (`Counter`),
  `CalendarTriggerTests` (`Clock`). Reapplies the existing `ScheduleTriggerTests.Clock`
  pattern.
- **Fresh-iterator-inside-Task ×10** — replaced "capture an outer non-Sendable
  `AsyncStream.Iterator` into a `@Sendable` Task" (error: *sending 'iterator' risks data
  races*) with a fresh `makeAsyncIterator()` inside the Task. All 10 are **nil-probe**
  tests (assert no further vote within 50 ms), for which a fresh iterator is semantically
  identical (shared AsyncStream buffer) — the pattern several sibling tests already used.
  Sites: AppTrigger ×4, WiFi ×2, Calendar ×1, Focus ×1, Schedule ×2, ExternalDisplay ×2,
  ReevaluateWatched ×1 (13 edits across the probe blocks).
- **`MainActor.assumeIsolated`** in `setUp`/`tearDown` (AppEnvironmentTests,
  AwakeIntentsTests) — those override *nonisolated* XCTestCase methods so they stay
  nonisolated even in a `@MainActor` class; XCTest runs them on main, so assumeIsolated is
  safe.
- **`@MainActor`** on `RetentionPickerTests` (calls main-actor statics); `var c` → `let c`
  (RecurringQuickPresetTests).

**Result:** app + test target both build with **0 warnings / 0 errors** under Swift 6;
**619/619 PASS.** (The only residual build warning is a toolchain `ld` note — the test
bundle targets macOS 13 but Xcode 26's XCTest dylib is built for 14 — pre-existing,
deployment-target artifact, unrelated to Swift 6.)

### IMPORTANT finding — a PRE-EXISTING full-suite test flake (NOT introduced by S40)

While verifying, the full `xcodebuild test` sweep **intermittently hangs (~12%)**: a random
async test (test82 / ReevaluateWatched / ActivityLog — *different each time*) stalls the
main actor ~18 s → *"Restarting after unexpected exit, crash, or test timeout"* → TEST
FAILED. **No assertion failure, no signal** = an environmental/scheduling stall, not a bug.

Classified rigorously before concluding:
- The hung test is **0/15 when run in isolation** — not its own logic.
- **S39 baseline (Swift 5.10, my changes stashed): 3/25 runs failed (~12%)** — the same
  rate, stalling at *different* async tests. **Swift-version-independent; S40 did not cause
  it.** (A first 0/10 baseline sample was just the lucky-clean side of a ~12% rate.)
- Same family as the documented "phantom rc=137" full-suite flake. Suspected mechanism:
  `TriggerCoordinator.start` consumer Tasks `for await trigger.voteStream` are intentionally
  never cancelled (S8b lesson) and strongly retain the trigger, so ~600 suspended tasks
  accumulate across the suite. Logged as cross-cutting trap #8 in `project_latte_status.md`.
- **Mitigation today:** if a full-suite run reports FAILED, re-run (usually green). A real
  fix is a separate session (see entry point #2).

### S40 NEW patterns (6)

a. **`isolated deinit` (SE-0371, Swift 6.1+) is the clean fix** for "`@MainActor` class must
   touch a non-Sendable isolated stored property in `deinit`". Objects released on the
   isolating actor → deinit runs synchronously, zero behaviour change.
b. **SE-0434: `@MainActor` closures are `Sendable` in Swift 6 language mode** — capturing a
   `@MainActor` closure in a `@Sendable` NotificationCenter/KVO block is *not* an error; the
   only residual fix is to move main-actor-isolated property **reads** inside the actor hop,
   out of the `@Sendable` scope.
c. **Fresh-iterator-inside-Task** beats capturing an outer `AsyncStream.Iterator` into a
   `@Sendable` Task; for nil-probe tests it's semantically identical (one shared buffer).
d. **`@unchecked Sendable` class box** for a test counter/clock mutated inside a `@Sendable`
   closure — only ever touched on one thread, so `@unchecked` is honest.
e. **`MainActor.assumeIsolated`** for `@MainActor` test classes' `setUp`/`tearDown`
   (nonisolated overrides) — XCTest runs them on the main thread.
f. **Characterize a flaky failure before "fixing" it** — isolate the test (0/15) *and*
   diff against the unmodified baseline (3/25) before attributing it to your change. Saved
   a wrong fix here: the flake was pre-existing.

Cumulative NEW S20→S40 ≈ 67.

---

## Next-session entry points (priority order)

**1. (AUTONOMOUS, large) — iCloud-sync Phase 1.** Now on a **clean Swift 6 base** (this
session's whole point). RFC §12 decided (S38); no Apple prerequisite. Scope (RFC §11 row 1):
`CloudSyncEngine` protocol + `MockCloudSyncEngine` + entitlement file + `cloudKitDatabase`
wiring **behind the compile-time kill-switch — ships dark, zero behaviour change**, 100%
pure-unit-testable per RFC §10. Container id `iCloud.com.parkbyeongjun.latte` (Q4,
non-gating) injected via the seam. **Read
[docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md) §10+§11 first.**

**2. (AUTONOMOUS, medium — optional, CI reliability) — pre-existing full-suite test hang.**
The ~12% intermittent main-actor stall (see above + trap #8). Suspect: uncancelled
consumer Tasks in `TriggerCoordinator` accumulating across the suite. NOT a production bug
(prod never makes 600 coordinators) and NOT Swift-6-related — a test-infra reliability
improvement. Mind the S8b lesson (don't break the OFF→ON restart path) — cancelling in
`deinit` only is likely safe since the coordinator is gone.

**3. (BLOCKER, owner-side) S8.5 Apple Developer Program** — gates S9 *and* iCloud Phase ≥ 2
(live CloudKit). Does **not** gate Phase 1 (#1).

**4. (BLOCKER, owner-side) S9 App Store Connect metadata** — depends on S8.5.

The autonomous-OPTIONAL i18n queue is empty and verified empty (S37 catalog sweep).

---

## Cold-start (다음 세션 진입)

S31's one-command ritual still applies: `latte` (zsh alias) or
`bash ~/Documents/Claude/Projects/Latte/scripts/latte-resume.sh`.

```bash
# PRE-FLIGHT (MANDATORY) — kill stale Latte before any test/Cmd-R.
pkill -9 -f "Latte.app" 2>/dev/null; sleep 1

# A FRESH WORKTREE HAS NO .xcodeproj — generate it first:
xcodegen generate

# In a git worktree: edit + test the worktree path, NOT the repo root (S36 footgun).

# Tests (~12s, expect 619 PASS). NOTE: full-suite hangs ~12% (pre-existing, trap #8) —
# if it reports FAILED with no assertion text, just re-run.
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed"

# Build clean under Swift 6 (expect 0 warnings):
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"

# Doc drift (incl. Core SwiftUI-free):
scripts/check_doc_drift.sh
```

**Expect**: 619/619 PASS; build 0 warnings under Swift 6 mode; doc-drift clean; 172 keys ×
11 langs.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.31 → 1.40 (S31–S40) for the i18n + infra + iCloud-RFC + decision-lock
   + audit-stabilization + Swift-6-migration lineage.
3. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)** before any
   iCloud-sync work — §12 is the decision log; §10/§11 define the Phase 1 test surface/scope.
4. Memory: `MEMORY.md` → `project_latte_v1_9.md` S20→S40 section; cross-cutting traps in
   `project_latte_status.md` (NEW trap #8 = the full-suite flake).
5. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S40 update)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8.5 | Apple Developer Program — applied 2026-05-02 | Apple wait. Check email + portal; if past the typical window, call Developer Support | 1-2 days typical |
| S9 | App Store Connect metadata + screenshots + binary submission | S8.5 depends | 1-3 sessions once unblocked |
| **Push branch** | **`claude/focused-hamilton-417bfc`** — now S36 + S37 + S38 + S39 + S40. Push the **branch tip** (count via `git rev-list --count origin/main..HEAD`). | none — ready | seconds |
| WiFi WhenInUse | Downgrade `requestAlwaysAuthorization` → `requestWhenInUseAuthorization` — needs a real Mac to confirm CoreWLAN `ssid()` still resolves under When-In-Use | owner device smoke | 1 edit + 1 smoke |
| iCloud RFC Q4 | Container-id `iCloud.com.parkbyeongjun.latte` — accept at Phase 1 kickoff (non-gating) | owner, non-gating | 1 answer |
| Smoke 23 re-run | S37–S40 changed no UI; no scenario delta expected | none | 7 min |
| Phase I community PRs | TRANSLATIONS.md; Russian is the worked reference | awaiting community | ongoing |

---

## v1.9 owner-visible behaviour reference (post-S40)

**No owner-visible behaviour change in S40.** It is a Swift 6 *language-mode* migration:
`isolated deinit` (teardown runs on main, synchronous in practice), one KVO read moved
inside its actor hop, and test-only concurrency fixes. The cup, menu bar, triggers,
Settings, Activity, ⌘⇧L all behave exactly as the S35/S36/S39 reference.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` already implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S39. Pages live at https://spespark.github.io/latte/ + /privacy.html.
Cross-project helper `~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario
`.smoke/scenarios/00-bundle-integrity.sh` (S35).
