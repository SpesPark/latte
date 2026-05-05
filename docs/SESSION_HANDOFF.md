# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S26** — Autonomous v1.x backlog drain (2026-05-05). First session entered with the v1.x P-issue queue empty after S25. Owner-approved "进行 in priority order until context fills" pacing. Four code/scripts commits + this docs commit. |
| **Theme** | "With v1.x P-issue queue empty after S25, the highest-value autonomous candidates were small polish items + owner-blocked-task prep work — not the multi-session iCloud-sync / per-action-chords surfaces. Phase 1 closed S22 P-issue-4 deferred (popover ⌘, / ⌘Q via NSEvent.addLocalMonitor — `.keyboardShortcut(...)` doesn't fire inside `MenuBarExtra(.window)` popovers). Phase 2 added `scripts/{deploy_pages,validate_pages}.sh` so the owner-side S8d step shrinks to a single command after one-time `git remote add origin ...`. Phase 3 ran the 14th simplify-pass on the new code. Phase 4 refreshed README (stale v1.0 / 309-test claims → v1.9 / 586) + added `.github/ISSUE_TEMPLATE/` + `PULL_REQUEST_TEMPLATE.md` so V2-22 (GitHub repo push) lands a clean public face. The pacing worked: each phase was self-contained, committed before moving on, and verified with `xcodebuild test` (Phase 1) or shell syntax check (Phase 2)." |
| **Status** | ✅ **4 commits** (`cb1c054` → `5cd884a`) + this docs commit. **Tests 574 → 586** (+12 PopoverKeyHandler unit tests). **Smoke 22/22 PASS** (verified post-Phase 1). Working tree clean (excluding `.claude/`). |
| **Tail commit** | `5cd884a` (docs: V2-22 prep — refresh README + add issue/PR templates) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S26 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF + ROADMAP wrap for S26                          (S26 #5)
5cd884a        docs: V2-22 prep — refresh README + add issue/PR templates             (S26 #4)
4527ed0        refactor: 14th simplify-pass — collapse PopoverKeyHandler.decide       (S26 #3)
efb04d5        chore: Pages deploy scripts + S8d README update                        (S26 #2)
cb1c054        feat: popover ⌘, / ⌘Q via NSEvent.addLocalMonitor                      (S26 #1)
               (S22 P-issue-4 close-out)
```

### What landed this session

| Phase | Resolution path | Tests Δ |
|---|---|---|
| 1 — B6 popover key handler | `.keyboardShortcut(",", modifiers: .command)` / `.keyboardShortcut("q", modifiers: .command)` don't fire inside `MenuBarExtra(.window)` popovers (LSUIElement / .accessory NSStatusItem context — popover window doesn't enter the SwiftUI keyEquivalent dispatch chain). New pure-logic `PopoverKeyHandler.decide(modifiers:character:) -> PopoverKeyAction` enum (`.openSettings` / `.quit` / `.passthrough`). Strict matching: only `.command` participates in chord mask check (.shift / .option / .control admixtures fall through). `.capsLock` / `.numericPad` / `.function` / `.help` are OS state bits ignored — numpad-comma + capslock-on still trigger ⌘, correctly. `MenuBarRoot` installs `NSEvent.addLocalMonitorForEvents(.keyDown)` in `.onAppear` (popover open) and tears it down in `.onDisappear`; while open, ⌘, → openSettings() + consume, ⌘Q → NSApp.terminate(nil) + consume; ⌘⇧Q logout / ⌘⇧L Carbon awake-toggle / any other combination passes through. PopoverKeyHandler is a value-API layer (no NSEvent in the API) — 12 new XCTest cases cover all branches without spinning up real key events. NSEvent.addLocalMonitor wiring itself is owner-side manual smoke (Step 6 region 7 — owner has yet to verify ⌘, / ⌘Q actually fire in the popover). | +12 |
| 2 — S8d Pages scripts | New `scripts/deploy_pages.sh`: diffs `docs/site/{index,privacy}.html` against the pre-staged `../latte-gh-pages-staging/` worktree, `--dry-run` mode for preview, commits only changed files, pushes to `origin/gh-pages` if remote is set (else stops at local commit and prints one-time setup steps), guesses the live URL from origin remote and prints the validate command. New `scripts/validate_pages.sh`: curl-based App-Store-readiness check on landing + privacy.html (HTTP 2xx + content-type=text/html + non-empty `<title>`); auto-derives base URL from gh-pages origin if not passed. `docs/site/README.md` updated to point at the new scripts as preferred path. | 0 |
| 3 — 14th simplify-pass | `PopoverKeyHandler.decide` redundant-guard cleanup. Dropped the `!character.isEmpty` clause (empty string falls through `default: .passthrough` because no string literal case matches ""). Collapsed `let pressed = modifiers.intersection(chordMask); guard pressed == .command` into a single guard with the intersection inline. 22-line body → 14-line body, 12/12 tests still GREEN. | 0 |
| 4 — V2-22 prep | `README.md`: v1.0 / 309 tests → v1.9 / 586 tests + 22/22 smoke. Trigger list expanded to reflect ExternalDisplay + Schedule + custom recurring presets + Activity log + custom global hotkey shipped in v1.1~v1.9. Tech stack: Swift 5.10 → Swift 6 + Xcode 26+. Smoke harness: 12 / ~2:30 → 22 / ~6:14. Directory layout reflects Sources/Core/ActivityLog + scripts/ + UI/Settings/Activity tab + MenuBar key handler. New `.github/ISSUE_TEMPLATE/{bug_report,feature_request}.md` + `config.yml` (blank issues disabled, App Store reviews + privacy URL as contact links). New `.github/PULL_REQUEST_TEMPLATE.md` with conventional-commit type hint + test-plan checklist + risk/blast-radius section. | 0 |

### Patterns reinforced this session

- **`MenuBarExtra(.window)` popover blocks SwiftUI keyEquivalent dispatch** (Phase 1) — confirmed empirically over S22→S26: `.keyboardShortcut(...)` modifiers attached to a Button inside the popover body do not fire while the popover is the visible/key window in an LSUIElement / .accessory app. The structural fix is to install an `NSEvent.addLocalMonitorForEvents(.keyDown)` in the popover root's `.onAppear` and tear it down in `.onDisappear` so the keys map only while the popover is on-screen.
- **`NSEvent.ModifierFlags.deviceIndependentFlagsMask` ≠ "user-pressed chord modifiers"** (Phase 1) — the device-independent mask includes `.capsLock` / `.numericPad` / `.function` / `.help`, which are OS state bits set independently of user intent. Match against an explicit `[.command, .shift, .option, .control]` mask instead so numpad-comma / capslock-on still trigger ⌘, correctly. The S26 first attempt used `.deviceIndependentFlagsMask` and the `testNumPadModifierIgnored` regression caught it before the wire-up landed.
- **Pure-logic value-API for NSEvent-driven handlers** (Phase 1) — extract the modifier+character → action decision into a value-API function (`decide(modifiers: NSEvent.ModifierFlags, character: String?) -> Action` enum). The NSEvent.addLocalMonitor wiring becomes a thin forwarder; all branch coverage is unit-testable without spinning up real key events. NSEvent itself is unmockable in tests; pulling logic out of the closure is the only way to TDD the matcher.

### What was checked but not changed

- General / Triggers / Activity / About tabs — unchanged from S25 ship state. No regression observed during smoke run.
- Smoke 22 "activity-log: file absent on fresh launch" — still PASSES (eager pre-load contract from S25 preserved through Phase 1's MenuBarRoot edits).
- gh-pages worktree at `../latte-gh-pages-staging/` — verified intact (`e3738a9` HEAD), `index.html` + `privacy.html` already in sync with `docs/site/` (deploy_pages.sh `--dry-run` confirms no diff, no-op exit).

### What was deferred to a later session

- **Step 6 region 7 (B1.2 ⌘⇧L global hotkey owner-manual-smoke verification)** — Phase 1 of S26 ships the ⌘, / ⌘Q monitor for the popover, but owner-confirmed `.keyboardShortcut(...)` failure in popover context was the long-standing context for "Step 6 region 7" being deferred since S22. The S26 ship is structural: **owner has yet to verify ⌘, / ⌘Q actually fire** with the new `NSEvent.addLocalMonitor` plumbing. Owner manual smoke when convenient. Defer carry-over.
- **S22 P-issue-4 lessons** are now folded into the codebase, so this item drops off the "S22 P-issue-4 revisit" defer list for next session — replaced by "owner verify Phase 1 ship."

The v1.x autonomous-coding backlog is now down to:
- Owner-blocked: S8d Pages deploy (one-command after `git remote add origin ...`), S8.5 Apple Dev Program (awaiting Apple), S9 ASC meta (depends on S8.5), V2-22 GitHub remote.
- Multi-session candidates that need owner direction: C-3 iCloud sync of activity history, B1.2 deferred (per-action chords / iCloud chord sync), V2-06 lid-closed-only mode + per-display position requirement.
- Single autonomous candidates that don't fit S26-style "small drain": none currently identified.

---

## Next-session entry points (priority order)

1. **Owner verify Phase 1 ship** — manually open popover, press ⌘, → expect Settings opens; press ⌘Q → expect Latte quits. If verified, "Step 6 region 7" closes permanently. If not, fall back to PopoverKeyHandler unit tests + log instrumentation in `installKeyMonitor` to diagnose monitor non-installation.
2. **Owner-blocked S8d** — `gh repo create bj-park/latte --public` (or owner's chosen name) + `cd ../latte-gh-pages-staging && git remote add origin git@github.com:bj-park/latte.git && git push -u origin gh-pages` + GitHub Settings → Pages → Source = gh-pages. Then `scripts/validate_pages.sh` to confirm 200s.
3. **Owner-blocked S8.5** (Apple Dev Program — applied 2026-05-02). 1-2 days awaiting Apple.
4. **Owner-blocked S9** (App Store Connect; depends on S8.5).
5. **C-3 iCloud sync of activity history** + **B1.2 iCloud chord sync** — joint design (CloudKit + conflict resolution). Multi-session, requires owner direction on whether/when to start.
6. **V2-06 still-deferred**: lid-closed-only mode, per-display position requirement.
7. **B1.2 still-deferred** (per 07-spec §1): per-action chords, false-negative chord-reserved indicator (the iCloud part overlaps with C-3 #5 above).
8. **V2-22 GitHub remote** — `.github/` templates landed in S26 Phase 4; owner-side step is `gh repo create` + `git push -u origin main` + Pages enable.

S26 is an autonomous polish session. v1.x version unchanged at v1.9.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -8
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 586 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 586/586 tests PASS in ~9s. Smoke 22/22 PASS in ~6:14.

**Diagnostic stream (carry over from S24)**: `/usr/bin/log stream --predicate 'subsystem == "com.parkbyeongjun.latte" AND category == "activity"' --info --debug --style compact` (`--info --debug` flags are mandatory or info-level logs are silently filtered).

**Note**: S16-S26 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 25 (S26) for the most recent session, row 24 (S25) for the immediately prior session.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (now 14-line index) → drill into `project_latte_v1_9.md` for the S20→S26 section.
4. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (unchanged from S25 except S8d easier)

| # | What | Why blocked | Effort |
|---|---|---|---|
| Verify S26 P1 | Open popover; press ⌘, then ⌘Q. Expect Settings opens then app quits. | Owner-only manual smoke | ~30 sec |
| S8d | `gh repo create` + `git remote add origin` + `git push -u origin gh-pages` + GitHub Settings → Pages enable + `scripts/validate_pages.sh`. | Owner clicks + auth | ~5 min (down from prior ~15 min thanks to S26 scripts) |
| S8.5 | Apple Developer Program — applied 2026-05-02 | Awaiting Apple review | 1-2 days |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push (main branch) + Pages enable | repo URL + auth owner-only | ~10 min |

---

## v1.9 owner-visible behavior reference (post-S26)

- Activity tab no longer flashes the empty-state placeholder ("Trigger fires will appear here") on the first-ever entry per app launch (S25 P-issue-4 — pre-loaded at boot via `AppEnvironment.activityEntries`).
- Activity tab no longer offers Export CSV / Export JSON (feature removed S24 — non-functional across multiple fix attempts).
- Activity tab no longer flashes a spinner-only frame on first entry (S24 P-issue-2).
- Activity tab no longer flashes the previous scroll position on every tab re-entry (S24 P-issue-3 — first-load gate).
- Recurring Quick presets render an active marker (left coffee-accent stripe + right checkmark) on the picked preset row, not on Custom (S23 P-issue-2 + P-issue-3).
- All three popover row types (duration / custom / recurring preset) show consistent left stripe + right checkmark when active (S23 P-issue-3 universal stripe).
- "Until X" caption shows the target wall-clock minute (e.g. "12:00 AM" for midnight preset), never one minute before due to whole-minute precision (S23 P-issue-1).
- Activity tab Retention is a Picker (1 day / 1 week / 2 weeks / 1 month / 2 months / 3 months), not a Stepper. Switching retention does not collapse the chart sections (S23 P-issue-4).
- **NEW S26 P1 (pending owner verification)**: Popover footer ⌘, opens Settings; ⌘Q quits Latte. Carbon-registered ⌘⇧L global awake-toggle is unaffected (passes through). System ⌘⇧Q (log out) passes through.

Carryover from earlier sessions (unchanged):

- v1.0~v1.8 owner-visible feature set (5 trigger types, custom presets, activity log, theme customisation, etc.)
- S22 fixes: pause-all snooze caption, Turn off "big red button" (disables all triggers), HeaderView caption gates, cross-trigger pause-lift auto-recovery, recurring presets light-mode visuals.
