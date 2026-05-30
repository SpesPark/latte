# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S50 (2026-05-30) — **whole-app audit (Opus 4.8) + 5 correctness/privacy/App-Review fixes.** Owner upgraded to Opus 4.8 and asked for a full app review before resuming the App Store push. Ran 4 parallel review agents (Triggers / Core+iCloud-dark+CRDT / UI+lifecycle+Intents / security+privacy) over ~11k LOC → **0 CRITICAL**; fixed every MEDIUM+ finding (T1–T5), TDD per fix, full gates between each. **681 → 691 tests.**
**v1.x release line:** v1.9 (unchanged). **Public App Store version = 1.0.0** (owner decision S45).
**Branch:** `claude/focused-hamilton-417bfc` — ahead of `origin/main` by S36 … + S49 + T1…T5 (count: `git rev-list --count origin/main..HEAD`). **PR #1 is OPEN** (`https://github.com/SpesPark/latte/pull/1`) — **not merged** (owner decides; see Owner-side pending #1). Pushed; PR auto-updates.
**Latest commits:** `a7a0ad4` (T1 onboarding), `e621139` (T2 privacy), `42949cb` (T3 triggers), `676ec3b` (T4 settings), `acd2394` (T5 wifi), + this S50 docs wrap.
**Test count:** **691** (681 + T1×2 + T2×4 + T3×4). Final full run green on attempt 1, no trap #8 stall.
**Builds:** default + flag-on both **0 warnings**.
**Doc-drift:** clean. **Store-limits:** clean. **Smoke:** 23 scenarios (not re-run — fixes are unit-covered; owner re-smoke before submit).
**Catalog:** 172 keys × 11 languages — unchanged.
**Toolchain:** Xcode 26.5 / Swift 6.3.2 (Swift 6 language mode). **Deployment target:** macOS 13.0.

**🟢 The autonomous engineering backlog is exhausted again.** S50 cleared every MEDIUM+ audit finding; the remaining items are documented LOW cosmetics/hygiene (see "Deferred LOW backlog") deliberately NOT churned to keep verification error-free. Every iCloud activation step stays S8.5-gated. **🟡 The next track is the owner-driven App Store upload** (the originally-planned work).

---

## Last session (S50)

Owner intent: after the Opus 4.8 upgrade, audit the whole app for problems before the App Store push, then fix in a recommended order that stacks safely and minimizes verification errors. Worked in the worktree; `git -C <worktree>` for all git ops (the repo root is on `main`/S35 and the Bash cwd drifts there — caught at S48).

### Audit (4 parallel agents, read-only)
- **Triggers**: S41/S44 retain-cycle/Task-leak fixes verified correct & complete. 1 MEDIUM (post-stop spurious vote → T3), 2 LOW (deferred).
- **Core + iCloud-dark + CRDT**: H1 migration default (absent schemaVersion → 1 → migrate) verified correct in code; CRDT commutativity/idempotence/associativity + content-addressed-id stability + GC parity all hold. 3 MEDIUM (T4 + 2 deferred), 2 LOW.
- **UI + lifecycle + Intents**: 1 MEDIUM (onboarding lockout → T1) + 1 MEDIUM (activation policy, deferred) + 4 LOW.
- **Security + privacy**: entitlements/sandbox/secrets/`latte://` clean; `LATTE_ICLOUD_SYNC` OFF both configs; "No Data Collected" supported. 1 HIGH (Wi-Fi auth mismatch → T5, a known owner item) + 1 MEDIUM (os_log PII → T2).

### Fixes (TDD per fix, gates between each)
- **T1 `a7a0ad4`** — onboarding X-button lockout. Window was `.closable` but only Skip/Finish marked complete; closing with X left a first-run user with no menu bar for the session. `OnboardingWindowController` is now the window's `NSWindowDelegate`; user close finalizes onboarding like Skip. +OnboardingWindowControllerTests.
- **T2 `e621139`** — os_log PII. `String(describing: AwakeState)` at `privacy: .public` leaked `TriggerVote.reason` (SSID / event title / app names). Added `AwakeState: CustomStringConvertible` emitting only static trigger IDs. +AwakeStateDescriptionTests.
- **T3 `42949cb`** — post-stop spurious ON vote. Deferred `Task` in `reevaluateWatched`/`reemitCurrentVote` could emit after `stop()`. Routed through `pollOnceIfRunning()` (re-checks `pollTask` at exec time, `[weak self]`). **`pollOnce()` itself left unguarded** — many tests call it directly without `start()`, so guarding it (the obvious fix) would have broken them. +DeferredPollStopGuardTests.
- **T4 `676ec3b`** — `encodeStringArray` deleted the key on encode failure (silent data loss); now preserves + `.fault` logs, matching `setKeyChord`. Defensive (branch unreachable via `[String]`); existing contract tests cover the reachable path.
- **T5 `acd2394`** — Wi-Fi `requestAlwaysAuthorization()` → `requestWhenInUseAuthorization()` to match the only shipped usage string (least-privilege; removes an App-Review mismatch). **Code-only; owner must device-verify CoreWLAN `ssid()` still resolves under When-In-Use before relying on the Wi-Fi trigger.**

**Net:** 0 CRITICAL found; all MEDIUM+ fixed. **No NEW patterns** (audit + targeted fixes). Cumulative NEW S20→S47 ≈ 92 unchanged.

### Deferred LOW backlog (intentionally not done — keep verification clean)
Documented here so they're not lost. None is a blocker; each has "no functional consequence" or a sharp risk/benefit ratio:
1. **Signal-handler `Task{}` async-signal-safety** (`AwakeManager` ~L788) — UB per POSIX; works empirically on macOS; the comment acknowledges it. A real fix (`DispatchQueue.main.async` or a pipe) touches the shutdown path — do NOT change casually.
2. **`IOPowerSource` `Unmanaged.passUnretained`** (`PowerSource.swift` ~L88) — no `deinit` removing the run-loop source; safe only because the singleton lives process-long.
3. **CoreWLANSource CLLocationManager↔delegate retain cycle** (`WiFiTrigger.swift` ~L34) — REAL cycle. ⚠ The naive `deinit { locationManager.delegate = nil }` is **WRONG**: a retain cycle means `deinit` never runs. A correct fix needs an explicit teardown method called from `WiFiTrigger`'s `isolated deinit`; benefit is one freed allocation in an app-lifetime object → very low priority.
4. **AppTrigger / FocusTrigger missing `deinit`** — observation not auto-cancelled on release-without-stop; app-lifetime + tests call stop(), so no functional consequence. Safe `isolated deinit { observation?.cancel() }` additions if ever wanted (mirror Schedule/Calendar).
5. **Activation-policy coordination** across Demo + Settings windows (each independently sets `.accessory` on close) — wrong Dock-icon state if both open; Demo is a marketing-only harness, low probability.
6. **Chart date formatter** hardcodes `en_US_POSIX` "M/d" (`ActivityTab` ~L302) — i18n cosmetic for an 11-language app.
7. **Dead `?? presets[0]`** (`ActivityTab` ~L232, unreachable) + **ActivityTab `Task` `@MainActor` annotation inconsistency** (~L93) — pure tidy.

---

## Next-session entry points (priority order)

**The autonomous engineering backlog is exhausted again** (S50 cleared all MEDIUM+; the rest is the deferred LOW list, mostly cosmetic/sharp-edged).

**A. (OWNER-driven, the originally-planned work) App Store upload** — see "Owner-side pending". Claude can assist autonomously where possible: wire `DEVELOPMENT_TEAM` once the owner gives the Team ID (+ `xcodegen generate`); further `docs/store/` metadata edits (guarded by `check_store_limits.sh`). **Screenshots are DONE (S50)** — 5 ASC-ready 2880×1800 shots in `docs/store/screenshots/` (Claude can capture more via `screenshots/_scripts/` since Screen Recording is granted). Signing + ASC paste remain owner/GUI-gated.

**B. (optional, if owner wants) clear deferred LOW backlog** — items 4–7 above are safe; items 1–3 are sharp (read their warnings first, especially the CoreWLANSource deinit trap). Do NOT do these "for completeness" mid-App-Store-push unless owner asks — they add churn for near-zero functional gain.

**C. (gated) iCloud Phase 2/3 activation** — needs S8.5 + a provisioned container + switching `CODE_SIGN_ENTITLEMENTS` to `Latte.icloud.entitlements` + (Phase 2) a macOS-14 bump for the `@Model` write. **NOT autonomous** — a future session must NOT flip `LATTE_ICLOUD_SYNC` (breaks signing without a container). The S49 RFC carries the activation checklist (M2 dedup on `recordName`, M3 server `modificationDate`, L1 migration gate, M1 owner bounded-vs-append-only). See `docs/design/10` §3/§4/§6/§7/§11.

**D. (only if trap #8 ever exceeds the runner's retries)** — `run_tests.sh` absorbs the stall; if a run ever fails all 3 attempts with no assertion, investigate harness/load, do NOT just bump the retry count.

---

## Cold-start (다음 세션 진입)

```bash
# 0. PTY CHECK (trap #9). Only matters if you run TESTS. Doc/metadata edits need
#    neither pty nor a build. If you do test and this fails, REBOOT or log out/in
#    — killing testmanagerd / sysctl does NOT help (orphaned /dev/ttys nodes).
python3 -c "import os;[os.close(x) for x in os.openpty()]" && echo pty-ok || echo "PTY EXHAUSTED — reboot/relogin"

# 1. Work in the WORKTREE, not the repo root (repo root is on `main`/S35).
#    Use `git -C` for git ops if the Bash cwd ever drifts back to the root.
cd .claude/worktrees/focused-hamilton-417bfc   # branch claude/focused-hamilton-417bfc, has its .xcodeproj

# 2. Doc/metadata gates (no pty, no build):
scripts/check_doc_drift.sh --strict
scripts/check_store_limits.sh --strict

# 3. If you touch Swift: builds need no pty (regenerate the project first if you
#    ADD/REMOVE a source or test file — `Tests`/`Sources` are directory refs):
xcodegen generate
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LATTE_ICLOUD_SYNC' 2>&1 | grep -E "warning:|BUILD"

# 4. Tests (only if Swift changed) — PREFER the runner (auto-retries the trap #8
#    no-assertion stall, fails fast on real failures). ~12s, expect 691.
scripts/run_tests.sh
```

**Expect**: pty-ok; (if tests run) 691/691 PASS; default + flag-on builds 0 warnings; doc-drift clean (incl. store char limits + the widened CloudKit guard); 172 keys × 11 langs; macOS 13 target; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.48 → 1.50 (1.50 = this session's full detail).
3. **Read `project_latte_v1_9.md`** (S20→S47 section) + `project_icloud_design_audit.md` (S48/S49 iCloud findings + activation checklist).
4. For iCloud, **read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)** (v0.3) — §11 phasing, §12 decision log, S49 audit notes in §3/§4/§6/§7.
5. For App Store work, source-of-truth is **`docs/store/`** (README maps every field; char limits enforced by `scripts/check_store_limits.sh`; `screenshot-guide.md` for captures).
6. Memory: `MEMORY.md` → `project_latte_status.md` (cross-cutting traps: **trap #8 = harness-level, auto-absorbed by `run_tests.sh`**; **trap #9 = pty, fixed by reboot/relogin not kill/sysctl**).
7. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (App Store upload)

Order matters (later steps depend on earlier).

| # | What | Notes | Owner/Claude |
|---|---|---|---|
| 1 | **(decide) merge PR #1 to `main`** | PR is OPEN at `https://github.com/SpesPark/latte/pull/1`; pre-merge review posted (no blockers). Release build best built from main. | owner decides; Claude can merge if told |
| 2 | **Apple Small Business Program** opt-in (15%) | ASC → Agreements, Tax, and Banking. Do early (lead time). | owner |
| 3 | **Register App ID** `com.parkbyeongjun.latte` | developer.apple.com → Identifiers | owner |
| 4 | **Team ID** → set `DEVELOPMENT_TEAM` (EMPTY in `project.yml`, currently `""`) + `xcodegen generate` | give Claude the Team ID and Claude wires it | owner→Claude |
| 5 | **Create app record** in App Store Connect (macOS, "Latte", bundle id, SKU) | | owner |
| 6 | **Screenshots** 2880×1800 | ✅ **DONE (S50)** — **8** ASC-ready shots in `docs/store/screenshots/`: cup hero / **menu-bar popover in the ACTIVE/awake state (CORE keep-awake feature)** / triggers / general / **Activity charts** / **6-accent "coffee tones" grid** / first-run language picker / about (English UI, sRGB, no-alpha). Owner asked for the core menu-bar feature, the awake state, and a multi-accent combined tile — all done. Owner: **review framing** before upload; reorder in ASC. Regenerate via `screenshots/_scripts/`. | owner review |
| 7 | **Fill ASC listing** from `docs/store/*` + pricing **$2.99** + App Privacy "No Data Collected" + age rating + URLs | privacy URL live (spespark.github.io/latte/privacy.html) | owner |
| 8 | **Archive → Validate → Upload → Submit** (Xcode Organizer) | Release, signed with the team from #4 | owner |
| — | **WiFi When-In-Use device-verify** (S50 T5) | code now calls `requestWhenInUseAuthorization()` matching the Info.plist string; confirm on a real Mac that CoreWLAN `ssid()` still resolves under When-In-Use before relying on the Wi-Fi trigger in the shipped build | owner device smoke |

Other long-standing non-blocking items: RFC Q4 container-id (Phase ≥2), macOS-14 bump (Phase 2 activation only), Phase I community translation PRs, the S50 deferred LOW backlog.

---

## v1.9 owner-visible behaviour reference (post-S50)

**Owner-visible behaviour change in S50: one fix is user-facing** — closing the first-run onboarding window with the title-bar X now dismisses onboarding and reveals the menu bar (previously left the app with no UI until relaunch). Everything else is invisible: privacy log hygiene (T2), an internal trigger-timing guard (T3), a settings-store defensive guard (T4), and a Wi-Fi permission-level change that resolves identically on macOS (T5). `cloudSync` nil, no CloudKit compiled, cup / menu bar / 6 triggers / Settings / Activity / ⌘⇧L otherwise unchanged from the S40–S47 reference.

---
