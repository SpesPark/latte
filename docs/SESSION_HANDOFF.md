# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S45 (2026-05-25) — **S44 verification gap CLOSED + branch pushed + App Store metadata reconciled to the shipping 6-trigger feature set.** Docs/metadata only; no code, no version bump, no owner-visible behaviour change.
**v1.x release line:** v1.9 (unchanged). **Public App Store version = 1.0.0** (owner decision S45): the internal "v1.x" are dev milestones that never shipped; `MARKETING_VERSION` is still `1.0.0`, so the first store release is 1.0.0 with metadata describing the *full current* feature set.
**Branch:** `claude/focused-hamilton-417bfc` — **pushed to `origin`** (the S35-pending push is done). Ahead of `origin/main` by S36 … + S44 + **S45** (count: `git rev-list --count origin/main..HEAD`). Not yet merged to `main` (owner deferred).
**Latest commit:** the S45 docs-wrap commit, on top of `6dcf108` `docs(store): reconcile App Store metadata with shipping 6-trigger feature set`.
**Test count:** **681** static — **VERIFIED GREEN this session** (681/681, 0 failures, `** TEST SUCCEEDED **` on the *first* run, no trap #8 stall). Default + `LATTE_ICLOUD_SYNC` flag-on builds both **0 warnings**. doc-drift clean. **S44's only open verification item is now closed.**
**Smoke:** 23 scenarios (not re-run — no runtime change since S40).
**Doc-drift:** clean (Core SwiftUI-free + CloudKit-isolation both green).
**Catalog:** 172 keys × 11 languages — unchanged.
**Toolchain:** Xcode 26.5 / Swift 6.3.2 (Swift 6 language mode).
**Deployment target:** macOS 13.0.

**🟢 Apple Developer Program (S8.5) is handled.** **🟡 Next phase = App Store upload** — the owner is driving the upload steps (see "Owner-side pending"); they deferred those to the next session.

---

## Last session (S45)

Owner intent: prep for App Store upload — "하기 전까지 진행해야 하는 작업" then execute what's doable autonomously. Three outcomes:

### 1. S44 verification gap CLOSED
- **trap #9 (pty exhaustion) self-recovered** on a fresh terminal login: `/dev/ttys*` nodes 527→32, `os.openpty()` 8/8 OK, stale `testmanagerd` gone. **The `sudo sysctl -w kern.tty.ptmx_max=2048` workaround is REJECTED by macOS** (`Invalid argument`; 511 is at/above the kernel cap) — so **reboot (or letting the pty-holding processes exit) is the reliable recovery, not the sysctl raise.** trap #9 updated in `project_latte_status.md`.
- With ptys free: **681/681 green, first run, 0 failures, no stall**; default + flag-on builds 0 warnings; doc-drift clean.

### 2. Branch pushed
`git push -u origin claude/focused-hamilton-417bfc` → new remote branch (was unpushed since S35). GitHub offered a PR link (`https://github.com/SpesPark/latte/pull/new/claude/focused-hamilton-417bfc`). **Not merged to main** — owner deferred the merge/PR decision.

### 3. App Store metadata reconciliation (`6dcf108`, 7 files in `docs/store/`)
The listing copy was all written at the early v1.0 **3-/4-trigger** stage; the shipping binary has **6 triggers** (App, Focus, External Display, Calendar, Wi-Fi, Schedule) + Activity history + the ⌘⇧L global shortcut. Owner chose **1.0.0 as the public first release**, metadata describing the full current set. Fixes:
- `review-notes.md`: dropped the **stale `com.apple.security.network.client` entitlement** (removed in S39; not in `Latte.entitlements` — a reviewer-visible mismatch), 4→6 triggers, removed the now-implemented per-calendar "planned" note, added a Schedule/External-Display reviewer smoke step.
- `description-en/ko.md`: added Focus / Schedule / External Display triggers + Activity-history & shortcut differentiators + Focus to requirements. **Discovered `description-en` was already ~690 chars OVER Apple's 4000 limit (pre-existing)** → fit to **3995** by removing the decorative `━` bars + the redundant "ONE-TIME PURCHASE" section (which duplicates the "no subscription" bullet). KO restructured to match (2421).
- `whats-new-en/ko.md`: 4→6 triggers; **5→6 accent tones** (whats-new was wrong — `CoffeeAccent` enum is 6: espresso/caramel/mocha/latte/matcha/noir); added Activity history + shortcut.
- `promotional-text-en.txt`: trimmed 184→160 (was over the 170 cap); `promotional-text-ko.txt`: trigger list made non-exhaustive for accuracy.
- **All 11 store fields verified under Apple limits.**

### S45 NEW patterns (3)
a. **Char-limit audit metadata against the *binary*, not the doc's self-label** — the copy said v1.0/"3 triggers" while shipping 6; `description-en` had silently been ~690 chars over the 4000 cap for sessions. Always (i) count chars per locale against Apple's limits before submit, (ii) cross-check feature counts (triggers, tones) against the actual enums.
b. **Reviewer-facing entitlement lists drift** — `review-notes` claimed `network.client` that S39 had removed; a reviewer cross-checking entitlements would see a mismatch. Re-derive the entitlement list from `Configuration/Latte.entitlements` at submit time.
c. **`kern.tty.ptmx_max` cannot be raised past the kernel cap on this Mac** (`=2048` → `Invalid argument`); pty exhaustion clears on reboot or when the leaking processes exit — don't rely on the sysctl workaround.

Cumulative NEW S20→S45 ≈ 86.

---

## Next-session entry points (priority order)

**A. (OWNER-driven, deferred to this session) App Store upload** — the owner is doing the account/Xcode/ASC steps; see "Owner-side pending". Claude can assist with: opening the PR, wiring `DEVELOPMENT_TEAM` once the owner supplies the Team ID (+ `xcodegen generate`), and any further metadata edits. **Screenshots and signing are owner/GUI-gated.**

**B. (AUTONOMOUS) iCloud Phase 1 *activation*** — unchanged from S44. Flip `LATTE_ICLOUD_SYNC` on + activate the staged `Configuration/Latte.icloud.entitlements`. A *signed* build + real two-Mac sync test stays owner/Xcode-signing-gated; the code-side flip + compile + account-gate check is autonomous. Read `docs/design/10-c3-icloud-sync-rfc.md` §11/§12 first.

**C. (AUTONOMOUS, reliability) trap #8 harness-level work** — the residual stall is harness/load, not a product leak. A dedicated effort could add per-test teardown that cancels spawned tasks, or reduce test concurrency, to eliminate it rather than re-run-on-FAILED. (S45 data point: a single low-load full run was clean first-try — consistent with load-dependence.)

All three iCloud phases' pure CloudKit-free logic is already pre-built (P1 seam S41, P2 LWW/migration/chord S42, P3 union-merge S43). i18n queue empty (S37 sweep).

---

## Cold-start (다음 세션 진입)

```bash
# PRE-FLIGHT (MANDATORY) — kill stale Latte before any test/Cmd-R.
pkill -9 -f "Latte.app" 2>/dev/null; sleep 1

# A FRESH WORKTREE HAS NO .xcodeproj — generate it first (this worktree already has one):
xcodegen generate

# In a git worktree: edit + test the worktree path, NOT the repo root (S36 footgun).

# ⚠ trap #9 (pty): if `xcodebuild test` → "Pseudo Terminal Setup Error / Device not
# configured" (0 tests run, no "Executed N"), ptys are exhausted.
#   FIX = REBOOT (or close stale test processes). `sudo sysctl -w kern.tty.ptmx_max=2048`
#   is REJECTED by macOS (Invalid argument) — do NOT rely on it. Probe with:
#   python3 -c "import os;[os.close(x) for x in os.openpty()]" && echo pty-ok
# Don't hammer back-to-back full runs without a cooldown (inflates flake + leaks ptys).

# Tests (~11s, expect 681 PASS). trap #8 stall MITIGATED, NOT CLOSED:
# a full run can stall with NO assertion text + 0 failures → ** TEST FAILED **.
# That is trap #8, not your code — RE-RUN. Read the ** TEST SUCCEEDED/FAILED ** line,
# NOT the exit code of a `… | grep` pipe.
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
2. `ROADMAP.md` rows 1.40 → 1.45 for the Swift-6 → Phase-1-dark → Phase-2/3-pure-logic → trap-#8-leak-fix → **verify+push+store-metadata** lineage.
3. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)** before any iCloud work — §12 decision log, §11 Phase 1/2/3 pre-built-dark notes.
4. For App Store work, the source-of-truth is **`docs/store/`** (README maps every field; `screenshot-guide.md` for captures).
5. Memory: `MEMORY.md` → `project_latte_v1_9.md` S20→S45 section; cross-cutting traps in `project_latte_status.md` (**trap #8 = mitigated**, **trap #9 = pty, fixed by reboot not sysctl**, both updated S45).
6. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (App Store upload — S45 update)

Order matters (later steps depend on earlier).

| # | What | Notes | Owner/Claude |
|---|---|---|---|
| 1 | **(optional) merge branch to `main`** | release build best built from main; GitHub PR link printed at push. Claude can open the PR. | owner decides; Claude can open PR |
| 2 | **Apple Small Business Program** opt-in (15%) | App Store Connect → Agreements, Tax, and Banking. Do early (lead time). | owner |
| 3 | **Register App ID** `com.parkbyeongjun.latte` | developer.apple.com → Identifiers → + | owner |
| 4 | **Team ID** → set `DEVELOPMENT_TEAM` (currently EMPTY in `project.yml`) + `xcodegen generate` | give Claude the Team ID and Claude wires it | owner→Claude |
| 5 | **Create app record** in App Store Connect (macOS, "Latte", bundle id, SKU) | | owner |
| 6 | **Screenshots** 2880×1800 per `docs/store/screenshot-guide.md` | `docs/store/screenshots/` is EMPTY (.gitkeep) — **hard blocker**; needs a running build | owner |
| 7 | **Fill ASC listing** from `docs/store/*` + pricing **$2.99** + App Privacy "No Data Collected" (`privacy-data.md`) + age rating (`age-rating.md`) + URLs | privacy URL already live (spespark.github.io/latte/privacy.html) | owner |
| 8 | **Archive → Validate → Upload → Submit for Review** (Xcode Organizer) | Release, signed with the team from #4 | owner |
| — | **WiFi WhenInUse downgrade** (review-risk) | code calls `requestAlwaysAuthorization` but Info.plist has only the WhenInUse string; "Always" location on a menu-bar utility may draw scrutiny. Needs a real Mac to confirm CoreWLAN `ssid()` still resolves after downgrade. | owner device smoke |

Other long-standing owner items (non-blocking for this ship): RFC Q4 container-id (Phase ≥2), macOS-14 bump (Phase 2 activation only), Phase I community translation PRs.

---

## v1.9 owner-visible behaviour reference (post-S45)

**No owner-visible behaviour change in S45** (docs/metadata only). The app behaves exactly as the S40–S44 reference: `cloudSync` nil, no CloudKit compiled, cup / menu bar / 6 triggers / Settings / Activity / ⌘⇧L all unchanged.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S44. Pages live at https://spespark.github.io/latte/ + /privacy.html.
Cross-project helper `~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario `.smoke/scenarios/00-bundle-integrity.sh` (S35).
