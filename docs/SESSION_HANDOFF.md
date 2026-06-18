# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S53 (2026-06-18) — **B1 verification + test-defect fix.** Picked up S52's MUST-DO: run the suite (B1 `872a38a` shipped its 4 wiring tests compile-only because trap #9 hit mid-S52). trap #9 was **already clear** at S53 start (pty 34/511, 0 orphans — owner's reboot/uptime resolved it; no action needed). Ran `scripts/run_tests.sh` → **2 of the 4 new AwakeTimerWiringTests were RED**. Root-caused as a **test defect, product correct**, fixed both, re-verified.
**v1.x release line:** v1.9 (unchanged). **Public App Store version = 1.0.0.**
**Branch:** `claude/focused-hamilton-417bfc`. S53 adds one commit on top of `0289c4e`: the AwakeTimerWiringTests fix + README 713→717. **PR #1 OPEN** (`https://github.com/SpesPark/latte/pull/1`) — not merged (owner decides). Pushed; PR auto-updates.
**Test count:** **717/717 verified GREEN** (attempt 1, no stall). Confirmed twice: `run_tests.sh` `** TEST SUCCEEDED **`, and a direct `xcodebuild test` summary = `Executed 717 tests, with 0 failures`. README now says 717.
**Builds:** default + flag-on **0 warnings** (carried from S52); full suite green. **Doc-drift + store-limits:** clean (carried; re-verify if touching store copy).
**Toolchain:** Xcode 26.5 / Swift 6.3.2 / macOS 13 target. **Catalog:** 172 keys × 11 languages (unchanged since S52).

---

## S53 what landed — the B1 test defect

**Symptom.** `run_tests.sh` (full suite) failed, real-failure classified (not the trap-#8 stall): `testDeactivateCancelsPendingDurationTimer` + `testReactivationReplacesPendingDurationTimer`. Run in isolation (`-only-testing:LatteTests/AwakeTimerWiringTests`), only `testReactivation…` failed deterministically (line 113 "superseded timer fired into the new session — got asleep"); `testDeactivate…` **passed alone** → it was order-dependent/flaky in the full suite.

**Root cause (TEST defect — product code is correct).** The S52 seam injects an **instant sleeper** `{ _ in }` that **ignores the requested interval**. So there is no such thing as a timer that stays *pending* across an `await`: the moment the main actor yields (any `await task.value`), EVERY enqueued `@MainActor` timer task fires its expiry.
- `testReactivation…` did `await first.value` then expected the session to still be awake — but draining the superseded task also ran the **live 1h replacement** to completion → `.asleep` → guard failed. Hard fail, reproducible in isolation.
- `testDeactivate…` drained a single cancelled task; alone that's fine, but in the full suite a **sibling test's enqueued timer** could run during the drain → flaky.

The product contracts they meant to check are genuinely upheld by `AwakeManager`: `cancelTimer` does `durationTask?.cancel(); durationTask = nil`; the task body guards `if Task.isCancelled { return }` (no late expiry); `enter()` emits `cancelTimer(.duration)` before `scheduleTimer(.duration)` on re-activation. No product change was needed or made.

**Fix (`Tests/AwakeTimerWiringTests.swift` only).** Rewrote both tests to pin the cancel/replace contract **synchronously** — `XCTAssertTrue(task.isCancelled)`, the timer-slot is nil, and the FSM state is read right after the public call (before any `await`). This is deterministic regardless of the instant sleeper and immune to suite ordering, and still catches real regressions (drop the cancel → `isCancelled` false; drop the replace's cancel → superseded task not cancelled). The expiry **wiring** itself stays covered by the two expiry tests (each holds a single timer, no pending-race). Added a `NOTE` comment in the file explaining why draining-to-observe is the wrong model under this seam.

**Verification.** `run_tests.sh` green attempt 1 (no stall); direct `xcodebuild test` = **717/717, 0 failures**. README bumped 713 → 717.

---

## Next-session entry points (priority order)

**A. (owner-decision queue — unchanged):**
1. 🟠 **상호 (brand) decision** → bundle-ID rewire → publish (see DECISION PENDING below). **Rewire is scripted** (S52 A1): `scripts/rebrand.sh com.<brand> --apply` + manual steps in `docs/rebrand-checklist.md` (TCC re-grants, defaults migration, gh-pages redeploy).
2. `latte://demo` ships in Release — `#if DEBUG` wrap yes/no (screenshots/smoke depend on it; don't wrap casually).
3. PR #1 merge (no blockers in review).
4. WiFi When-In-Use device-verify (S50 T5 + S51 F2).

**B. (autonomous, now unblocked — the suite runs again):**
- ✅ **B1 clock seam — LANDED `872a38a` + VERIFIED S53** (tests fixed; 717 green). Done.
- ⏳ **B3 chart POSIX locale** ([ActivityTab.swift:302](../Sources/UI/Settings/ActivityTab.swift) `en_US_POSIX`) — i18n cosmetic: charts show English dates in all 11 locales. Safe to pick up now (suite is green again). Small, self-contained.
- ⏳ **B2 `IOPowerSource.fanOut` parity** — needs a seam design (same DI pattern as the S52 sleeper). Design-touching but low-risk now that the suite is unblocked.
- ❌ **B4 LOW bundle** (dead `?? presets[0]`, `@MainActor` consistency, `recordActivity` object-nil) — intentionally skipped; S50's "no churn during the App Store push" call stands.

**C. (gated) iCloud Phase 2/3 activation** — unchanged; S8.5 + container + entitlements switch + macOS-14 `@Model`. NOT autonomous. M2/L1/L4 activation contracts carried in source since S51 — read `project_icloud_design_audit.md` before flipping.

**v1.x autonomous backlog:** B3 + B2 are the only remaining autonomous items; everything else is owner-gated or community-PR refinement.

### 🟠 DECISION PENDING: brand (상호) / bundle ID — owner deciding, blocks first publish
Individual account ⇒ seller shows personal legal name; owner wants a brand ⇒ Org account (개인사업자 + D-U-N-S) later via App Transfer (must happen during v1.x, BEFORE iCloud Phase 2). Bundle ID is permanent post-publish ⇒ hold publishing until the 상호 is chosen, then `scripts/rebrand.sh` rewire (`project.yml` / entitlements / Info.plist / `.smoke/config.yml` / `docs/store/*` / screenshots `_scripts` / defaults+container paths all hardcode `com.parkbyeongjun.latte`) → regenerate → signed-build verify → publish as Individual.

---

## Cold-start (다음 세션 진입)

```bash
# 0. PTY CHECK (trap #9) — only matters for TESTS. S53 START was already pty-ok
#    (reboot/uptime cleared S52's exhaustion). If this fails, owner must reboot/relogin.
python3 -c "import os;[os.close(x) for x in os.openpty()]" && echo pty-ok || echo "PTY EXHAUSTED — reboot/relogin"

# 1. ⚠ CWD: a session restart RESETS Bash cwd to the repo root (main/S35 state!) — bit S51.
#    The ROOT checkout is stale (main = S35); ALL work happens in this worktree. Verify pwd; prefer absolute paths.
cd /Users/parkbyeongjun/Documents/Claude/Projects/Latte/.claude/worktrees/focused-hamilton-417bfc && pwd

# 2. Doc/metadata gates (no pty, no build):
scripts/check_doc_drift.sh --strict && scripts/check_store_limits.sh --strict

# 3. If you touch Swift (regenerate first if you ADD/REMOVE a source/test file):
xcodegen generate
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"

# 4. Tests — PREFER the runner (absorbs the trap-#8 stall). ~9s suite, expect 717.
scripts/run_tests.sh
```

**Expect**: pty-ok; **717/717 PASS**; doc-drift + store-limits clean; 172 keys × 11 langs; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.51 → 1.52 → 1.53 (1.53 = this session; 1.52 = S52 i18n detail incl. the rejected-false-positive list).
3. Memory: `MEMORY.md` → `project_latte_v1_9.md` (S51–S53 at the tail) + `project_latte_status.md` (traps; #8 = harness-absorbed, #9 = pty/reboot, cwd-reset-on-restart hazard) + `project_icloud_design_audit.md`.
4. For App Store work: `docs/store/` **in this worktree** is source-of-truth (root's copy is stale S35). Metadata says FIVE triggers and no export — do not "fix" it back (Focus = V2-03b, export removed S24).
5. For any future i18n agent pass: read the S52 "Rejected as FALSE POSITIVES" list in ROADMAP row 1.52 first — especially the ru paucal genitive-singular point.
6. **Test-seam gotcha (S53):** the `AwakeManager` `sleeper` seam is an *instant* sleeper in tests — it ignores the interval, so EVERY scheduled timer fires the instant the main actor yields. Never write a wiring test that assumes a timer stays "pending" across an `await`; assert cancel/replace contracts synchronously (`Task.isCancelled` + FSM state). See the NOTE in `Tests/AwakeTimerWiringTests.swift`.

---
