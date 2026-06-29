# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S56 (2026-06-29) — **App Store rejection FIXED, ready to resubmit (build 1.0.0 (2)).** The first submission (dc78a591) was **rejected 2026-06-23** on four guidelines. All four are addressed and verified: two real code bugs fixed + tested, two metadata/answer items prepared. Nothing left to code — the remaining path is the owner's ASC resubmit (see entry point A + `docs/store/review-response-1.md`).
**v1.x release line:** v1.9 (unchanged). **Public App Store version = 1.0.0**, **build bumped 1 → 2** (required for re-upload). **Bundle ID `com.araforge.latte` (permanent).**
**Branch:** `claude/focused-hamilton-417bfc`. S56 = `5bea1d3` (13 files, the 4 fixes) + `8a9f8d0` (doc wrap) + a **popover-rework commit** (3 files, after owner UI smoke found the Guideline-4 fix regressed the popover — see below), all **pushed**. PR #1 still OPEN, not merged.
**Test count:** **732/732 GREEN** (attempt 1, no stall) — 725 + 7 (`MenuBarLayoutTests`). README says 732.
**Builds:** default + flag-on (`-D LATTE_ICLOUD_SYNC`) **0 warnings**; full suite green. **Doc-drift + store-limits `--strict`:** clean. **rebrand.sh --check:** clean. Built app: `CFBundleVersion = 2`, `CFBundleIdentifier = com.araforge.latte`, `CFBundleDisplayName = Latte`.
**Toolchain:** Xcode 26.5 / Swift 6.3.2 / macOS 13 target. **Catalog:** 172 keys × 11 languages (unchanged).

---

## S56 what landed — the 4 rejection fixes

Rejection: Submission **dc78a591-c4b8-46b3-b7ef-001f37fcb244**, reviewed **2026-06-23** on a MacBook Pro 14" / macOS 26.5.1, version 1.0 (1).

**1. Guideline 5.2.5 (IP) — "Mac" in name/subtitle.** App name "Latte - Keep Mac Awake" → **"Latte - Keep Awake"** (`docs/store/app-name.txt`); subtitle "Auto keep-awake for your Mac" → **"Automatic keep-awake utility"** (`subtitle-en.txt`). `subtitle-ko.txt` also de-"맥"-ed for the eventual KO add. Keywords had no "Mac"; the description **body**'s descriptive "Mac" is allowed (the reviewer cited only name + subtitle) — left intact. Owner must re-enter Name/Subtitle in ASC.

**2. Guideline 4 (Design) — popover truncated at bottom (Settings/Quit unreachable).** `MenuBarRoot` was fixed-width / unbounded-height; on a small/notched screen the content overflowed and `MenuBarExtra(.window)` doesn't clamp or scroll. **Final fix (after owner UI smoke — see "post-commit popover rework" below):** `MenuBarRoot` renders the middle section (pause + durations + Custom + recurring presets + Turn off) extracted as `middleContent`; the header and Settings/Quit footer are pinned outside it. When the content fits the screen it renders at **natural size** (window hugs it, grows/shrinks with the Custom row, no scrollbar, every row shown); only when it's taller than the screen does it fall back to a `ScrollView` capped at `MenuBarLayout.maxScrollHeight` so the footer stays reachable. A hidden, `fixedSize` copy of `middleContent` measures its natural height; that measurement feeds **only** `MenuBarLayout.needsScroll(...)` (the scroll decision) — never the displayed height. Screen height = **min across all `NSScreen.screens`** (LSUIElement ⇒ `NSScreen.main` unreliable; smallest display = safe on any multi-monitor config). Content layout animates 0.18s on Custom expand/collapse (the window itself resizes in one AppKit step — see rework note). `Sources/UI/MenuBar/MenuBarLayout.swift` + `MenuBarLayoutTests` ×7.

**3. Guideline 2.1(a) (Completeness) — app disappeared after onboarding (zombie).** The app is `LSUIElement` (no Dock icon) so its only UI is the `MenuBarExtra`. `LatteApp` bound `MenuBarExtra(isInserted:)` to onboarding state to hide the icon during the wizard then re-insert it on completion; that **false→true re-insertion is unreliable** (esp. macOS 26) → no UI surface, zombie process. **Fix:** `Sources/App/LatteApp.swift` keeps the `MenuBarExtra` **permanently inserted** — removed `menuBarVisible`, the Combine onboarding observation, and `ObservableObject` from `LatteAppDelegate`. The onboarding window simply sits on top of an always-present icon (matches the wizard's "Find Latte in the menu bar" copy). `OnboardingWindowControllerTests` header reframed: persisting completion now only prevents re-showing the wizard; it is **no longer** the load-bearing line that surfaces the menu bar.

**4. Guideline 2.1 (Information Needed) — sleep-prevention API.** Answers (verified against `Sources/Core/PowerAssertion.swift` + `AwakeManager.installSignalHandlers`) written into **`docs/store/review-response-1.md`**: (1) `IOPMAssertionCreateWithName`; (2) `kIOPMAssertionTypeNoDisplaySleep` or `kIOPMAssertionTypeNoIdleSleep` per the user's setting; (3) created on activate (manual duration / enabled trigger), released on off / duration-expire / all-triggers-off — crash cleanup guaranteed (per-process kernel assertion auto-released on terminate, plus SIGINT/SIGTERM handlers + `PowerAssertion.deinit`).

**Build #:** `project.yml` `CURRENT_PROJECT_VERSION` 1 → 2. **Code review:** code-reviewer agent = APPROVE, 0 CRITICAL/HIGH; the one MEDIUM (NSScreen.main on multi-monitor) was fixed (min-across-screens).

### Post-commit popover rework (owner UI smoke, same session)
After `5bea1d3`, the owner launched the build and the Guideline-4 popover fix had **regressed**: clicking the menu bar showed only Settings/Quit — the `ScrollView` middle had collapsed to 0 height inside `MenuBarExtra(.window)`. Reworked the popover live across several owner-verified iterations; the journey is the lesson:
1. `min(measuredContentHeight, maxScroll)` fixed-frame `ScrollView` → **collapsed to 0** (measured read 0 → frame 0). 
2. Deterministic per-row pixel constants → **gap** above the footer (estimates too large; still gapped even expanded).
3. Hidden-copy measured fixed-height `ScrollView` → **fixed window + permanent scrollbar** (owner wanted the window to grow, not scroll).
4. Explicit `.frame(height: measuredContentHeight).clipped()` to animate the window → **clipped the last preset** (measurement under-reports; can't drive displayed height from it).
5. **FINAL (owner-approved):** natural-size render when it fits (window hugs content, no scrollbar, every row shown); `ScrollView` fallback only when content > screen; measurement drives **only** the scroll decision; content animates 0.18s on Custom expand. 

**Lessons (carry forward):** (a) a `ScrollView` inside `MenuBarExtra(.window)` has no intrinsic height and a measured fixed height can collapse to 0 — prefer **natural sizing**, scroll only as an overflow fallback. (b) Runtime height measurement here **under-reports / lags** — safe to gate a boolean (scroll-or-not) on it, NOT to size displayed content. (c) The `MenuBarExtra(.window)` **window resize is not smoothly animatable** — AppKit snaps it to the final content size; SwiftUI animation only smooths inner content. Don't chase window-frame animation (every attempt clipped content). (d) These are SwiftUI scene/layout behaviours the unit suite can't catch — **owner UI smoke is mandatory** for menu-bar popover changes.

### ⚠ Carry-over gotcha (still applies): Xcode rewrites `Localizable.xcstrings` on build
Opening/archiving in Xcode auto-rewrites `Resources/Localizable.xcstrings` (reformat + empty `state:"new"` keys). Churn, not a real change. Revert with `git checkout -- Resources/Localizable.xcstrings` unless you deliberately added a string.

---

## Next-session entry points (priority order)

**A. (owner-gated — RESUBMIT) — this is the active task.** Everything is fixed + verified; the owner finishes in ASC. Full checklist in **`docs/store/review-response-1.md`**:
1. In ASC set **Name** = `Latte - Keep Awake`, **Subtitle** = `Automatic keep-awake utility` (English (US) only).
2. **Archive + upload build 1.0.0 (2)** via local Xcode Archive (Team `4BXCVHZANL`, Automatic signing — NOT Xcode Cloud). Revert any `Localizable.xcstrings` churn first.
3. Select the new build, **paste the Reply block** (review-response-1.md) into Resolution Center, **resubmit**.
- (Optional, recommended before resubmit:) the owner does a quick local UI smoke of the two code fixes — first-run onboarding then confirm the menu-bar icon is present throughout, and open the popover to confirm Settings/Quit are reachable. These are SwiftUI scene/layout behaviours not coverable by the unit suite (UI smoke is owner-only).

**B. (deferred, post-approval — unchanged from S55):**
1. **Korean localization** — paste `docs/store/*-ko` into a KO localization in ASC (files ready; KO subtitle now Mac-free).
2. **Org App-Transfer** (Araforge seller name) — MUST be during v1.x and **BEFORE iCloud Phase-2** (transfer blocked for iCloud apps).
3. PR #1 merge.
4. WiFi When-In-Use device-verify (S50 T5 + S51 F2).

**C. (gated) iCloud Phase 2/3 activation** — unchanged; read `project_icloud_design_audit.md` before flipping. NOT autonomous.

**Autonomous backlog:** still exhausted (B4 LOW only, intentionally skipped). The S56 work was reactive (rejection), not from the backlog.

---

## Cold-start (다음 세션 진입)

```bash
# 0. PTY check (trap #9) — only matters for TESTS.
python3 -c "import os;[os.close(x) for x in os.openpty()]" && echo pty-ok || echo "PTY EXHAUSTED — reboot/relogin"

# 1. ⚠ CWD: a session restart RESETS Bash cwd to the repo root (main = stale S35!).
#    ALL work happens in this worktree. Verify pwd; prefer absolute paths.
cd /Users/parkbyeongjun/Documents/Claude/Projects/Latte/.claude/worktrees/focused-hamilton-417bfc && pwd

# 2. Doc/metadata gates (no pty, no build):
scripts/check_doc_drift.sh --strict && scripts/check_store_limits.sh --strict

# 3. If you touch Swift (regenerate first if you ADD/REMOVE a source/test file):
xcodegen generate
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"

# 4. Tests — PREFER the runner (absorbs the trap-#8 stall). ~9-11s, expect 732.
scripts/run_tests.sh
```

**Expect**: pty-ok; **732/732 PASS**; doc-drift + store-limits clean; bundle ID `com.araforge.latte`; build # 2; name "Latte - Keep Awake".

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` row 1.56 (this session) → 1.55 (S55 submission) → 1.54 (S54).
3. `docs/store/review-response-1.md` is the owner's resubmit playbook (Reply block + checklist).
4. Memory: `MEMORY.md` → `project_latte_v1_9.md` (S55/S56 at the tail) + `project_latte_status.md` (traps; cwd-reset hazard).
5. S56 code is committed (`5bea1d3` fixes + popover-rework commit) + pushed; `git status` should be clean. PR #1 still OPEN.
6. **Menu-bar popover changes need owner UI smoke** — the unit suite can't see SwiftUI scene/layout regressions (a fix that passed 729 tests still shipped a collapsed popover; see "Post-commit popover rework").
6. Test-seam gotchas from prior sessions still apply (instant sleeper in `AwakeTimerWiringTests`; `MenuBarExtra(isInserted:)` re-insertion is unreliable — keep the extra always-inserted).
