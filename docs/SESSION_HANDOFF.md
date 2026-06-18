# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S54 (2026-06-18) — **closed out the autonomous backlog: B3 + B2.** Both shipped TDD-first (RED via missing symbol → impl → green) with pure-helper / DI-seam extraction so the new behaviour is unit-tested without touching production control flow. With these, the v1.x autonomous backlog is **empty** — everything remaining is owner-gated (see entry points A).
**v1.x release line:** v1.9 (unchanged). **Public App Store version = 1.0.0.**
**Branch:** `claude/focused-hamilton-417bfc`. S54 adds two commits on top of `4f9f11c`: `85413b8` (B3) + `13db4a3` (B2). **PR #1 OPEN** (`https://github.com/SpesPark/latte/pull/1`) — not merged (owner decides). Pushed; PR auto-updates.
**Test count:** **725/725 verified GREEN** (attempt 1, no stall) — 717 + 4 (B3 `ChartDateLabelTests`) + 4 (B2 `IOPowerSourceFanOutTests`). README says 725.
**Builds:** default + flag-on (`-D LATTE_ICLOUD_SYNC`) **0 warnings**; full suite green. **Doc-drift + store-limits:** clean.
**Toolchain:** Xcode 26.5 / Swift 6.3.2 / macOS 13 target. **Catalog:** 172 keys × 11 languages (unchanged since S52).

---

## S54 what landed — B3 + B2 (autonomous backlog closed)

**B3 — chart date labels localized (`85413b8`).** `DailyTotalsChart`'s x-axis used `en_US_POSIX` + a hardcoded `"M/d"`, forcing US month-first ordering ("1/15") in all 11 locales. Extracted a pure, locale-injectable `ChartDateLabel.makeFormatter(locale:)` that derives field order/separators via `setLocalizedDateFormatFromTemplate("Md")` — "15/01" en-GB, "1. 15." ko, "15.1." de. `DailyTotalsChart` caches a formatter built from `Locale.current` (same once-built `static let` caching as before — locale is fixed per app session). `ChartDateLabelTests` (4) pin month-first/day-first ordering and ko ≠ en-US; time zone pinned to UTC for CI independence, production uses the current zone.

**B2 — IOPowerSource fan-out seam (`13db4a3`).** `fanOut()` was reachable only from the IOKit run-loop callback → the production observer registry (multi-observer delivery, copy-before-iterate cancel safety, single-shared-notifier lifecycle) had **zero** coverage; only `MockPowerSource`'s parallel reimplementation was tested (free to drift). Applied the S52 sleeper DI pattern: inject `snapshot: () -> Bool` + `notifier: PowerChangeNotifier`, defaults read real IOKit via new `systemIsOnAC` / `systemNotifier` statics. The IOKit run-loop wiring + the C-callback main-actor hop moved into `systemNotifier`; `observe()` installs one shared notifier and tears it down on last-observer-leave — **behaviour identical**, just injectable. `fanOut()` stays private; `IOPowerSourceFanOutTests` (4) drive it through an injected notifier so **no live `CFRunLoopSource`** is created in the test process (avoids aggravating trap #8).

**New patterns.** (1) `setLocalizedDateFormatFromTemplate` is the correct fix for "all locales show US dates" — never hardcode `dateFormat` for user-facing labels. (2) The S52 inject-the-side-effecting-primitive seam generalizes cleanly: box a non-Sendable closure as a C run-loop context and keep it alive in the teardown closure. (3) Swift 6 tests that share mutable state across injected (sendable) closures need a `@MainActor` reference box (`Ref<T>`) — a captured local `var` trips "mutated after capture by sendable closure".

**Verification.** `run_tests.sh` green attempt 1 (no stall) = **725/725, 0 failures**; default + flag-on builds **0 warnings**; doc-drift clean. README 717 → 725.

### S54 post-wrap — pre-upload readiness audit (read-only, all GREEN)

Owner-requested double-check that the binary + store assets are upload-ready so the only thing standing between here and submission is the brand decision. Nothing changed; all findings clean:
- **Screenshots** 8/8 present, all **2880×1800** (valid macOS retina size).
- **Store text fields** all present, non-empty, within Apple char limits (char-counted, confirms the doc-drift store-limits gate): keywords en 95 / ko 58 (≤100); subtitle en 28 / ko 12 (≤30); app-name 5 (≤30); promo en 163 / ko 88 (≤170).
- **Version** `MARKETING_VERSION 1.0.0` / `CURRENT_PROJECT_VERSION 1`.
- **Entitlements** active `Latte.entitlements` = sandbox + calendars + location (no CloudKit — correct for the v1.0 dark-iCloud launch); `Latte.icloud.entitlements` staged but unreferenced.
- **Signing** `DEVELOPMENT_TEAM 4BXCVHZANL`, `CODE_SIGN_STYLE Automatic`.
- **rebrand** `scripts/rebrand.sh --check` fails by design pre-rebrand (the `com.parkbyeongjun` placeholder is consistently present across the 24 target files, ready to swap in one pass).
- **Conclusion:** zero asset/config blockers. The remaining path is owner-only: 상호 → `rebrand.sh` → archive + upload (distribution signing needs the Apple Developer Program / owner's machine).

---

## Next-session entry points (priority order)

**A. (owner-decision queue — unchanged):**
1. 🟠 **상호 (brand) decision** → bundle-ID rewire → publish (see DECISION PENDING below). **Rewire is scripted** (S52 A1): `scripts/rebrand.sh com.<brand> --apply` + manual steps in `docs/rebrand-checklist.md` (TCC re-grants, defaults migration, gh-pages redeploy).
2. `latte://demo` ships in Release — `#if DEBUG` wrap yes/no (screenshots/smoke depend on it; don't wrap casually).
3. PR #1 merge (no blockers in review).
4. WiFi When-In-Use device-verify (S50 T5 + S51 F2).

**B. (autonomous backlog — CLOSED):**
- ✅ **B1 clock seam** — LANDED `872a38a` + VERIFIED S53 (717 green). Done.
- ✅ **B3 chart date-label locale** — LANDED S54 `85413b8`. Done.
- ✅ **B2 `IOPowerSource.fanOut` parity** — LANDED S54 `13db4a3`. Done.
- ❌ **B4 LOW bundle** (dead `?? presets[0]`, `@MainActor` consistency, `recordActivity` object-nil) — still intentionally skipped; S50's "no churn during the App Store push" call stands. Pick up only post-launch as a refinement.

There is **no remaining autonomous work**. Every open item is owner-gated (A) or post-launch refinement (B4).
- ❌ **B4 LOW bundle** (dead `?? presets[0]`, `@MainActor` consistency, `recordActivity` object-nil) — intentionally skipped; S50's "no churn during the App Store push" call stands.

**C. (gated) iCloud Phase 2/3 activation** — unchanged; S8.5 + container + entitlements switch + macOS-14 `@Model`. NOT autonomous. M2/L1/L4 activation contracts carried in source since S51 — read `project_icloud_design_audit.md` before flipping.

**v1.x autonomous backlog:** EXHAUSTED as of S54. The only path to publish now runs through owner decisions (A) — chiefly the 상호/bundle-ID call below. No further code work is required to ship the current binary.

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
