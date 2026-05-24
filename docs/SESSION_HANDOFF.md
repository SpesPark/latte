# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S44 (2026-05-25) — **trap #8 root-cause**: a *second* trigger-task self-retain leak found + fixed (RED→GREEN); residual full-suite stall characterized as **harness-level / load-dependent** (not closed); new **pty-exhaustion** gotcha discovered.
**v1.x release line:** v1.9 (unchanged — S44 fixes a leak + adds tests, no version bump, no owner-visible behaviour change)
**Branch:** `claude/focused-hamilton-417bfc` — ahead of `origin/main` by S36 … + **S44**. Push = owner action; push the **branch tip**. *(Exact count: `git rev-list --count origin/main..HEAD`.)*
**Latest commit:** `a03efff` `fix(triggers): break self-retain cycles in poll/observe tasks (trap #8 residual)` (+ a docs-wrap commit on top).
**Test count:** **681** static (676 → 681: +5 deterministic leak regression tests). **⚠ Final single clean 681-green full-suite run is PENDING pty recovery** — see "Verification gap" below. The fix is verified independently: 5 leak tests RED→GREEN, default + flag-on builds 0 warnings, doc-drift clean, and partial full runs showed **0 assertion failures** up to 423 tests.
**Smoke:** 23 scenarios (not re-run — S44 changes only task teardown/lifetime, no runtime behaviour)
**Doc-drift:** clean (Core SwiftUI-free + CloudKit-isolation both green)
**Catalog:** 172 keys × 11 languages — unchanged
**Toolchain:** Xcode 26.5 / Swift 6.3.2 (Swift 6 language mode)
**Deployment target:** macOS 13.0

**🟢 BIG CHANGE this session: Apple Developer Program (S8.5) is now HANDLED** (owner-confirmed). The autonomous backlog that was "exhausted until S8.5" since S41 is **reopened** — every iCloud *activation* path is now unblockable in principle (caveats below).

---

## Last session (S44)

Owner: "Apple Dev는 처리됨. trap #8 근본원인 먼저." Then make a work list + recommended order, execute the recommendation, and keep going (context-budget-aware) until well-used, then wrap. Recommended order put **trap #8 first** because a flaky suite makes every later iCloud-activation verification untrustworthy — close the reliability foundation before building on it.

### Root cause (the residual S41 did not cover)

S41 closed the *coordinator → consumer-task → trigger* retention. A **second** retention path remained: **each trigger retains itself** through its own poll/observe task.

```swift
// LEAK shape (5 sites):
pollTask = Task { @MainActor [weak self] in
    guard let self else { return }        // ← strong self bound for the WHOLE closure…
    while !Task.isCancelled {
        try? await Task.sleep(…)           // …including across this suspension → cycle
        await self.pollOnce()
    }
}
```

`trigger → pollTask → (strong self) → trigger` is an effective cycle: the trigger never deallocates, so its `deinit` never runs and the recurring poll/observe task lingers, accumulating across the suite. **Control case** `TriggerCoordinator` (line 146) is correct — its `guard let self` is *inside* the `for await` body (transient per-iteration), not ahead of the loop.

**5 sites fixed:** `ScheduleTrigger` / `WiFiTrigger` / `CalendarTrigger` `pollTask` (these three also had **no `deinit`**), and `ExternalDisplayTrigger` / `DebouncingDisplaySource` `observeTask` (their `deinit` cancels, but the cycle blocked the deinit from running).

### Fix (`a03efff`, 8 files, +207/−16)

- Break every cycle: capture the `interval`/`source` by value and re-acquire `self` **weakly** each iteration so a strong `self` is **never** held across the suspension.
- Add `isolated deinit { pollTask?.cancel() }` to the 3 polling triggers (the 2 ExternalDisplay classes already cancel in `deinit`).
- Add 5 deterministic RED→GREEN leak regression tests (weak-ref deallocation after `start()` *without* `stop()`), one per affected type, in the existing trigger test files (no new file → no xcodegen regen).

### TDD finding (why RED-first mattered)

The first RED test gave a **false pass**: `await trigger.start()` only *enqueues* the task; if the `do`-block drops the trigger before the task runs its `guard let self`, it early-returns (nil) and no strong self is ever bound. Adding a **50 ms sleep after `start()`** (let the task bind self while still referenced) made the leak reproduce **deterministically** (weak-ref non-nil after scope). RED→GREEN then proved both the diagnosis and the fix.

### ⚠ trap #8 is NOT fully closed (honest result)

An A/B under identical **adversarial back-to-back** runs (no cooldown): **S43 baseline = 5/5 FAIL** vs **the fix = 3/5 FAIL**. So the residual full-suite stall is **pre-existing and NOT caused by this change** (the fix is directionally better via reduced task accumulation). The captured log confirms the mechanism: a random test hangs ~18–23 s → timeout → bundle restart → retry passes → overall verdict FAILED, **no assertion error**. This is a **load-dependent, harness-level main-actor scheduling stall**; real-leak fixes (S41 + S44) reduce it but don't eliminate it. **`re-run-on-FAILED` remains the mitigation.** Full elimination likely needs test-harness work (per-test teardown that cancels spawned tasks, or lower test concurrency) — a separate effort. trap #8 stays **mitigated, not closed** in `project_latte_status.md`.

### ⚠ Verification gap — pty exhaustion (new trap #9)

Running ~25 back-to-back `xcodebuild test` + many `pkill -9` this session **exhausted pseudo-terminals** (`kern.tty.ptmx_max` = 511) → the test runner can no longer launch:
`Failed to install or launch the test runner. Pseudo Terminal Setup Error … Device not configured (errno 6)`. This is **distinct** from the trap #8 stall (0 tests execute, no "Executed N" line; killing `testmanagerd` doesn't help). **This is why the final clean 681-green run is pending.** To clear it: **`sudo sysctl -w kern.tty.ptmx_max=2048`** (reversible — resets to 511 on reboot) *or* reboot, then run the full suite once.

### S44 NEW patterns (4)

a. **`guard let self` *ahead of* an `await` loop in a `[weak self]` Task is a retain cycle** — the strong binding spans the suspension. Re-acquire weakly *inside* the loop (or capture the needed value by itself) and cancel the task in `deinit`.
b. **RED-first catches a wrong/weak test, not just wrong code** — the false pass showed an unstructured Task needs a suspension to *bind* its capture before the leak is observable; without the post-`start()` delay the test proved nothing.
c. **A/B a flaky metric against a stashed baseline before attributing it** (reaffirms S40 pattern f) — baseline 5/5-fail proved the residual stall pre-existing and prevented a wrong "my fix regressed it" conclusion.
d. **Heavy test iteration is itself an environmental hazard** — back-to-back suites inflate the flake rate (load) *and* leak ptys; budget cooldowns and cap consecutive full runs.

Cumulative NEW S20→S44 ≈ 83.

---

## Next-session entry points (priority order)

**0. (do first, ~30 s) clear the pty exhaustion + run the final full suite** — `sudo sysctl -w kern.tty.ptmx_max=2048` (or confirm a reboot happened), then one full `xcodebuild test` to confirm **681 green** (re-run on FAILED — trap #8). This closes S44's only open verification item.

**1. (AUTONOMOUS, now unblocked) iCloud Phase 1 *activation*** — S8.5 is handled, so the dark seam can be turned on: flip `LATTE_ICLOUD_SYNC` on + activate the staged `Configuration/Latte.icloud.entitlements`. **Caveat**: a *signed* build + a real two-Mac sync test still needs Xcode signing config (team, container provisioned in the Apple Developer portal) — that part is owner/Xcode-GUI-gated even with S8.5. The code-side flip + compile + account-gate verification is autonomous. Read `docs/design/10-c3-icloud-sync-rfc.md` §11/§12 first.

**2. (AUTONOMOUS, reliability) trap #8 harness-level work** — the residual stall is now characterized (harness/load, not a product leak). A dedicated effort could add per-test teardown that cancels spawned tasks, or reduce test concurrency, to actually eliminate the stall rather than re-run-on-FAILED.

**3. (AUTONOMOUS, large — needs macOS-14 decision) iCloud Phase 2 activation** — SwiftData `@Model` container + `ModelConfiguration.cloudKitDatabase = .private(...)` + wire the S42 resolvers + add the local-only `shortcutChordDeviceOverride` key. Needs the owner's **macOS-14 target bump** decision (drops macOS 13).

**4. (AUTONOMOUS) iCloud Phase 3 activation** — create the `activity-log` CloudKit custom zone; write each entry as a `CKRecord` named by `contentAddressedID`; feed downloaded records + the local JSON cache through `ActivityLogMergeResolver.mergedAndPruned` on sync-in (no macOS-14 bump needed).

All three iCloud phases' **pure CloudKit-free logic is already pre-built** (P1 seam S41, P2 LWW/migration/chord S42, P3 union-merge S43). The autonomous-OPTIONAL i18n queue is empty (S37 sweep).

---

## Cold-start (다음 세션 진입)

```bash
# PRE-FLIGHT (MANDATORY) — kill stale Latte before any test/Cmd-R.
pkill -9 -f "Latte.app" 2>/dev/null; sleep 1

# A FRESH WORKTREE HAS NO .xcodeproj — generate it first:
xcodegen generate

# In a git worktree: edit + test the worktree path, NOT the repo root (S36 footgun).

# ⚠ trap #9 (S44): if `xcodebuild test` fails with "Pseudo Terminal Setup Error /
# Device not configured" → ptys are exhausted (NOT a code/test problem; 0 tests run).
#   sudo sysctl -w kern.tty.ptmx_max=2048   # reversible; or reboot
# Don't hammer back-to-back full runs without a cooldown (inflates flake + leaks ptys).

# Tests (~10s, expect 681 PASS). trap #8 stall is MITIGATED, NOT CLOSED:
# a full run can still stall with NO assertion text + 0 failures → ** TEST FAILED **.
# That is trap #8, not your code — RE-RUN. Read the ** TEST SUCCEEDED/FAILED ** line,
# NOT the exit code of a `… | grep` pipe (that is grep's exit, not xcodebuild's).
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | tail -3

# Default build clean (0 source warnings, CloudKit-free):
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"

# Verify the dark iCloud code still COMPILES under the flag (won't run it):
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LATTE_ICLOUD_SYNC' 2>&1 | grep -E "warning:|BUILD"

# Doc drift (incl. Core SwiftUI-free + CloudKit-isolation guard):
scripts/check_doc_drift.sh --strict
```

**Expect**: 681/681 PASS; default + flag-on builds 0 source warnings; doc-drift clean; 172 keys × 11 langs; macOS 13 target; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.40 → 1.44 for the Swift-6 → Phase-1-dark → Phase-2/3-pure-logic → **trap #8-leak-fix** lineage.
3. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)** before any iCloud work — §12 is the decision log; §11 carries the Phase 1/2/3 "pre-built dark" notes.
4. Memory: `MEMORY.md` → `project_latte_v1_9.md` S20→S44 section; cross-cutting traps in `project_latte_status.md` (**trap #8 = mitigated-not-closed**, **trap #9 = pty exhaustion**, both updated S44).
5. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S44 update)

| # | What | Why | Effort |
|---|---|---|---|
| **Final verify** | Clear pty (`sudo sysctl -w kern.tty.ptmx_max=2048` or reboot) → 1 full `xcodebuild test` → confirm **681 green** | S44's only open verification item (fix is unit+build verified) | ~30 s + 1 run |
| **Push branch** | **`claude/focused-hamilton-417bfc`** — now S36…+**S44** (count via `git rev-list --count origin/main..HEAD`). Push the **branch tip**. | none — ready | seconds |
| S9 | App Store Connect metadata + screenshots + binary submission | S8.5 now handled → unblocked | 1-3 sessions |
| macOS-14 bump | **Phase 2 activation only** needs the deployment target raised to macOS 14 for SwiftData `@Model` (drops macOS 13 Macs). **Phases 1 & 3 need no bump.** | owner product decision | 1 answer |
| iCloud signing | Phase 1+ *signed* build / live two-Mac sync test needs Xcode team + container provisioned in the Apple Developer portal (container id `iCloud.com.parkbyeongjun.latte`) | owner Xcode/portal | per activation |
| WiFi WhenInUse | Downgrade `requestAlwaysAuthorization` → `requestWhenInUseAuthorization` — needs a real Mac to confirm CoreWLAN `ssid()` still resolves | owner device smoke | 1 edit + 1 smoke |
| Smoke 23 re-run | S36–S44 changed no UI; no scenario delta expected | none | 7 min |
| Phase I community PRs | TRANSLATIONS.md; Russian is the worked reference | awaiting community | ongoing |

---

## v1.9 owner-visible behaviour reference (post-S44)

**No owner-visible behaviour change in S44.** The fix only alters *teardown/lifetime* of trigger poll/observe tasks (they now release promptly instead of leaking) — the live OFF→ON restart path, voting, and all UI behave exactly as the S40–S43 reference. `cloudSync` is still nil, no CloudKit is compiled, the cup / menu bar / triggers / Settings / Activity / ⌘⇧L are unchanged.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` already implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S43. Pages live at https://spespark.github.io/latte/ + /privacy.html.
Cross-project helper `~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario
`.smoke/scenarios/00-bundle-integrity.sh` (S35).
