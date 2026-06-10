# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S51 (2026-06-10) — **Fable 5 adversarial re-verification of all prior-model work + 6 fix/hardening commits.** Owner directive: the codebase was built and audited by earlier models — re-verify with the new model, critical-eyes-on, fix-first, gates between every fix. Ran 6 read-only adversarial agents in two waves (A: prior-conclusion re-audit ×2, B: test quality + coverage gaps ×2, C: App-Review rejection hunt, D: CRDT counterexample search), then fixed everything MEDIUM+ that survived verification. **691 → 713 tests.**
**v1.x release line:** v1.9 (unchanged). **Public App Store version = 1.0.0.**
**Branch:** `claude/focused-hamilton-417bfc` — S51 adds 6 commits (`c4368a5` F1, `5bf04a7` F2, `6b67d7d` F3, `ed1e381` F4, `b142c72` C, `d397119` D) + this wrap. **PR #1 OPEN** (`https://github.com/SpesPark/latte/pull/1`) — not merged (owner decides). Pushed; PR auto-updates.
**Test count:** **713** (691 + F2×7 + F3×5 + F4×8 + D×2). One mid-session trap-#8 stall absorbed by `run_tests.sh` (attempt 2) — working as designed.
**Builds:** default + flag-on both **0 warnings**. **Doc-drift + store-limits:** clean. **README** test count 681→713.
**Catalog:** 172 keys × 11 languages — unchanged. **Toolchain:** Xcode 26.5 / Swift 6.3.2 / macOS 13 target.

---

## S51 verdicts on prior-model work (the point of the session)

**SURVIVED adversarial re-audit:** S46's FALSE-POSITIVE dismissal of the DebouncingDisplaySource/ExternalDisplayTrigger plain-deinit race (members are Sendable; legal under Swift 6 — though the "0-warning build proves it" reasoning was loose); S50-T3's guard (sufficient under main-actor serial execution); all deferred-LOW risk ratings (signal-handler `Task{}` UB, IOPowerSource `passUnretained`, CoreWLANSource CLLocationManager↔delegate cycle — cycle is real, naive `deinit{delegate=nil}` is indeed unreachable, bounded impact); CRDT pure layer (**zero counterexamples** — merge commutativity/associativity/idempotence hold by trace, canonical order total, LWW per-key, migration switch compiler-exhaustive over all 34 keys); test suite graded **B+**.

**REFUTED / gaps the old audits missed (all fixed in S51):**
1. **F1 `c4368a5`** — `scheduleTriggerEntries` setter had the exact delete-on-encode-failure pattern S50-T4 fixed in `encodeStringArray`, same review scope, missed peer. Preserve + `.fault` (defensive).
2. **F2 `5bf04a7`** — `.authorizedWhenInUse` is `API_UNAVAILABLE(macos)` → CoreWLANSource mapped it (raw 4) to not-determined/false, but S50-T5 *requests* When-In-Use. Future-macOS forward-compat: matched by raw value in `permissionStatus` + delegate. +7 tests (stubbed CLLocationManager, RED→GREEN).
3. **F3 `6b67d7d`** — **worst silent failure:** `applyEffects` discarded `activate()`'s Bool; on IOPM acquisition failure the app showed the full cup (`isAwake=true`) while holding NO assertion. `MockPowerAssertion` hardcoded success so this was untestable. New `activateAssertionOrForceAsleep`: `.fault` + deferred `.constraintDeactivate` (next main-actor turn; skips if recovered). Mock gains `failNextActivate`. +5 tests; RED verified via stash A/B.
4. **F4 `ed1e381`** — coverage gaps closed (+8 tests): **first DST coverage in the suite** (spring-forward 420-min real duration, fall-back 570, nonexistent 02:30→03:30, wall-clock repeated/vanished hours — **all pass: no production DST bug, the gap was coverage only**); the actual T3 enqueue→stop→execute race; onboarding `show()` delegate-wiring assertion (the load-bearing line was deletable with all tests green; `window` → internal seam); GC cutoff ±10 s.
5. **Track C `b142c72`** — **S45's metadata reconciliation claimed features the binary doesn't ship** (2 would-be 2.3.1 rejections): described **SIX triggers incl. Focus**, but `registerDefaultTriggers` intentionally never registers FocusTrigger for v1.0 (sandboxed `INFocusStatusCenter` needs the communication entitlement — **V2-03b**; binary ships **FIVE**); and **CSV/JSON export was removed in S24** (`0e13546`) yet still claimed. Fixed en+ko descriptions/whats-new/review-notes/promos/privacy-data/screenshot-guide; whats-new "Korean and English" → 11 languages; review-notes competitor names (2.3.7) neutralized; keywords `zoom`→`meeting`, `포커스`→`일정`; Info.plist `NSFocusStatusUsageDescription` removed (unused-API usage string — re-add with V2-03b). All fields within limits.
6. **Track D `d397119`** — activation-contract hardenings so RFC checklist items can't fail silently: **M2** doc-contract on `contentAddressedID` (NEVER re-hash a CloudKit-downloaded entry — CK Date precision → duplicate explosion; dedup on stored `recordName`); **L1** doc-contract on `SettingsMigration.snapshot` (run once + write `schemaVersion=2` back to the UserDefaults store, else re-runs every launch and clobbers LWW provenance); **§7 L4 structural** — `ChordSyncResolver.apply` gains `featureEnabled` (default true; OFF ⇒ unregister, never register) +2 tests.

**⚠ cwd-drift trap recurred (3rd time):** the mid-session RESTART reset Bash cwd to the repo root (main/S35). A relative-path `printf > docs/store/keywords-en.txt` contaminated the ROOT tree and a grep read root's pre-S45 files (caught because the copy said "Four triggers"). Root reverted via `git checkout`; worktree re-applied. **Rule: after ANY session restart, re-verify `pwd` before relative paths; prefer absolute paths into the worktree.**

---

## Next-session entry points (priority order)

**A. (queued autonomous) Track F — i18n quality review.** The only S51 track not run (context budget). 172 keys × 11 languages were machine-written by earlier models; S36 proved real CLDR bugs exist (Russian 4-form plural). Per-language adversarial review agents; fix wrong/awkward translations + CLDR plural-rule violations.

**B. (owner-decision) `latte://demo` handler ships in Release.** S51 App-Review audit flagged it MEDIUM (hidden-functionality question risk; window itself benign, inputs clamped). `#if DEBUG` wrap is the fix BUT screenshots `_scripts/` + smoke scenarios drive it — wrapping changes what the Release reviewer build contains vs what smoke exercises. Owner call; do not wrap casually mid-submission.

**C. (optional autonomous, design-touching — confirm with owner) B1's two remaining HIGH test gaps**, both need production seams: (1) injectable clock/scheduler in `AwakeManager.schedule()` so timer-expiry wiring (`.timerExpired` etc.) is testable end-to-end — today a `schedule()` bug = "timed session never ends" ships green; (2) `IOPowerSource.fanOut` production copy untested (mock duplicates the logic; mock fires on change-only vs production every-notification). Plus LOW: `recordActivity` posts notification with `object:` nil if coordinator deallocs mid-flight.

**D. (owner-driven, ON HOLD) App Store upload — unchanged from S50** except metadata is now truthful (5 triggers, no export claim). Still blocked on the **상호 (brand) decision** → bundle-ID rewire → owner GUI chain. See "DECISION PENDING" below.

**E. (gated) iCloud Phase 2/3 activation** — unchanged; S8.5 + container + entitlements switch + macOS-14 `@Model`. NOT autonomous. The S51 D-track hardenings (M2/L1 contracts in source, L4 structural) make the RFC checklist safer to implement.

### 🟠 DECISION PENDING: brand (상호) / bundle ID — owner deciding, blocks first publish
Unchanged from S50. Individual account ⇒ seller shows personal legal name; owner wants a brand ⇒ Org account (개인사업자 + D-U-N-S under the 상호) later via App Transfer (must happen during v1.x, BEFORE iCloud Phase 2 — transfer is blocked for iCloud apps). Bundle ID is permanent post-publish ⇒ hold publishing until the 상호 is chosen, then: rewire `project.yml` bundleIdPrefix/`PRODUCT_BUNDLE_IDENTIFIER`(+`.tests`) + entitlements + Info.plist + `.smoke/config.yml` + `docs/store/*` + screenshots `_scripts` + defaults/container paths (all hardcode `com.parkbyeongjun.latte` — grep-sweep) → regenerate → signed-build verify → owner publishes as Individual.

---

## Cold-start (다음 세션 진입)

```bash
# 0. PTY CHECK (trap #9) — only matters for TESTS; doc edits need neither pty nor build.
python3 -c "import os;[os.close(x) for x in os.openpty()]" && echo pty-ok || echo "PTY EXHAUSTED — reboot/relogin"

# 1. ⚠ CWD: a session restart RESETS Bash cwd to the repo root (main/S35) — S51 got bitten.
#    Verify pwd before any relative path; use absolute paths or git -C.
cd /Users/parkbyeongjun/Documents/Claude/Projects/Latte/.claude/worktrees/focused-hamilton-417bfc && pwd

# 2. Doc/metadata gates (no pty, no build):
scripts/check_doc_drift.sh --strict && scripts/check_store_limits.sh --strict

# 3. If you touch Swift (regenerate first if you ADD/REMOVE a source/test file):
xcodegen generate
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"

# 4. Tests — PREFER the runner (absorbs the trap-#8 stall, fails fast on real reds). ~20s, expect 713.
scripts/run_tests.sh
```

**Expect**: pty-ok; 713/713 PASS; both builds 0 warnings; doc-drift + store-limits clean; 172 keys × 11 langs; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.50 → 1.51 (1.51 = this session's full detail).
3. Memory: `MEMORY.md` → `project_latte_v1_9.md` (S51 section at the tail) + `project_latte_status.md` (traps; #8 = harness-absorbed, #9 = pty/reboot, and the cwd-reset-on-restart hazard) + `project_icloud_design_audit.md` (S48/S49 + S51 hardenings).
4. For App Store work: `docs/store/` is source-of-truth — **metadata now says FIVE triggers and no export; do not "fix" it back to six** (FocusTrigger is V2-03b, export was removed S24).
5. For iCloud: `docs/design/10-c3-icloud-sync-rfc.md` §11/§12 + the M1–M3/L1–L5 activation checklist; M2/L1/L4 now also carried as source-level contracts (S51).

---

## Owner-side pending (App Store upload)

Unchanged from S50 except #6/#7 metadata is now truthful (5 triggers, no export claim) — if the owner already pasted S50-era copy anywhere, re-paste from `docs/store/`.

| # | What | Status |
|---|---|---|
| 0 | **상호 결정** → bundle-ID rewire → publish | 🟠 blocks everything below |
| 1 | merge PR #1 (owner call; no blockers in review) | owner |
| 2 | Small Business Program opt-in | owner |
| 3 | App ID register (after 상호/bundle-ID) | owner |
| 4 | Team ID / signing | ✅ DONE S50 (`4BXCVHZANL`) |
| 5 | ASC app record | owner |
| 6 | Screenshots 8 × 2880×1800 | ✅ DONE S50 (owner review framing) |
| 7 | ASC listing paste from `docs/store/*` (**S51-updated copy**) + $2.99 + privacy + age | owner |
| 8 | Archive → Validate → Upload → Submit | owner |
| — | WiFi When-In-Use device-verify (S50 T5; S51 added forward-compat) | owner device smoke |
| — | `latte://demo` `#if DEBUG` wrap — yes/no | owner decision (S51 audit, MEDIUM) |

---

## v1.9 owner-visible behaviour reference (post-S51)

No owner-visible behaviour change in S51 except: (a) on the (rare) IOPM assertion-acquisition failure the cup now correctly returns to asleep instead of lying awake (F3); (b) store metadata now describes 5 triggers and no export. Everything else is internal hardening/tests. `cloudSync` nil, no CloudKit compiled, cup / menu bar / **5 registered triggers** (Focus = V2-03b) / Settings / Activity / ⌘⇧L unchanged.
