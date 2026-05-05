# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S27** — Owner manual-smoke fix-first (2026-05-05). Same-day continuation of S26. Owner ran S26 Phase 1's popover key handler through manual smoke; found ⌘Q working but ⌘, silently failing. Combined with owner-reported ⌘⇧L global chord collision (Claude Code holds the chord). Single-commit fix-first session: drop ⌘, popover binding (low-value per owner) + chord-recorder rebind for ⌘⇧L (no code change needed — recorder shipped v1.2). |
| **Theme** | "S26 Phase 1's NSEvent.addLocalMonitor closes the .keyboardShortcut(...) popover gap structurally, but ⌘, character matching via `event.charactersIgnoringModifiers` is unreliable when Korean IME is active — IME forwards letter-keys (q) untransformed under ⌘ but consumes punctuation (,). Considered keyCode fallback (kVK_ANSI_Comma == 43) but owner judged the binding low-value: popover is already mouse-bound for trigger selection, so the 1-step ⌘, → Settings shortcut adds little. Removed entirely. ⌘⇧L collision resolved by chord-recorder rebind to ⌘⌃L (control rarely used in third-party global chords) — kept default unchanged for new users since any new default would collide with some other inevitable third-party app." |
| **Status** | ✅ **1 code commit** (`6d4c95a`) + this docs commit forthcoming. **Tests 586 → 587** (+1 net: 3 ⌘, branches removed, 4 ⌘Q + capslock variants added). **Smoke 22/22 PASS** (re-verified post-Step 1; first run had a flaky 13-soak-short due to LSMultipleInstancesProhibited zombie residue from the just-prior xcodebuild test, isolated re-run + full re-run both PASS). Working tree clean (excluding `.claude/`). |
| **Tail commit** | `6d4c95a` (refactor: drop ⌘, popover binding) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S27 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF + ROADMAP wrap for S27                          (S27 #2)
6d4c95a        refactor: drop ⌘, popover binding — owner low-value                   (S27 #1)
```

### What landed this session

| Step | Resolution path | Tests Δ |
|---|---|---|
| 1 — Drop ⌘, popover binding | Owner manual smoke against S26 Phase 1 found ⌘Q working but ⌘, silently failing inside a Korean-IME-active session. Root cause: macOS Hangul IME forwards letters (a-z) untransformed when ⌘ is held, so ⌘+q produces `"q"` reliably; punctuation (`,`, `.`, `;`) goes through IME's character-mapping path and may yield IME-transformed character (or be consumed entirely). `event.charactersIgnoringModifiers` returns the post-IME character, not the US-layout glyph. Considered `event.keyCode == kVK_ANSI_Comma (43)` fallback but owner judged the binding low-value (popover requires mouse for trigger selection anyway; ⌘, → Settings is a 1-step shortcut to a context the user is already mouse-bound to). Removed entirely. `PopoverKeyAction` enum: `.openSettings` case dropped — only `.quit` + `.passthrough` remain. `PopoverKeyHandler.decide` switch on `q`/`Q` only. `MenuBarRoot.installKeyMonitor` `.openSettings` arm removed. ⌘, now passes through so any other app that consumes ⌘, while a Latte popover happens to be visible keeps working. Tests: removed `testCommandCommaOpensSettings`, `testCommandOptionCommaPassesThrough`, `testNumPadModifierIgnored`; added `testCommandCommaPassesThrough` (regression guard ensuring S27 removal stays in place), `testCommandOptionQPassesThrough`, `testNumPadModifierIgnoredForQuit`, `testCapsLockIgnoredForQuit`. | +1 |
| 2 — ⌘⇧L Claude-Code collision resolution | Owner reported ⌘⇧L 동작 안 됨 in both Latte ON and OFF states. Diagnosed: Claude Code (LSUIElement, also Carbon-style global chord registrant) holds ⌘⇧L first — `RegisterEventHotKey` is OS-level, second registrant gets `kEventHotKeyExistsErr`. **Initial misdescription corrected mid-session**: I had described the original ⌘⇧L behaviour as "Latte master toggle" early in the conversation, but reading `AwakeManager.toggle()` at line 683 confirmed it already matches owner's proposed redesign 100% (caffeinate-OFF → `.userActivate(.indefinite)`; caffeinate-ON → `.constraintDeactivate` + `postUserExplicitDeactivateIfTransitioned` → `disableAll()`, exactly the "Indefinitely on / Turn off" flow owner asked for). No code change needed for the behaviour. Resolution: owner used the chord-recorder UI (shipped v1.2 / S11) in Settings → General → Keyboard shortcut to rebind from ⌘⇧L → ⌘⌃L. Control rarely participates in third-party global chords (Slack, Notion, Logi Options+, Claude Code all favour ⌘⇧/⌘⌥ chords) so collision risk is lowest. Owner verified post-rebind: popover toggle on, ⌘⌃L from another app's foreground awake-on; ⌘⌃L again awake-off + disable triggers. Default chord stays ⌘⇧L for new users — changing the default would just shift collision to a different third-party app (Mac users tend to install at least one of {Claude Code, Notion, Linear, Raycast, Logi Options+}, all of which use ⌘⇧/⌘⌥ chords). | 0 |
| 3 — Smoke 23 dropped | Planned smoke scenario "popover ⌘, → Settings does not open" rejected during scoping. Smoke harness scenario 21 (shortcut-recorder) explicitly states "Pure SwiftUI key capture isn't scriptable from a smoke harness without Accessibility permission" — same constraint applies here. Owner manual smoke territory. The unit-test layer covers it deterministically: `testCommandCommaPassesThrough` ensures ⌘, never reactivates as a popover binding (regression guard). | 0 |

### Patterns reinforced this session

- **Korean IME consumes punctuation under ⌘ but lets letters pass** (Step 1) — macOS Hangul IME forwards letter-keys (a-z) to apps untransformed when ⌘ modifier is held, so ⌘Q matches `"q"` reliably; punctuation (`,`, `.`, `;`, etc.) goes through IME's character-mapping path, so ⌘, may yield an IME-transformed character (or be consumed entirely) depending on input mode. Don't rely on `charactersIgnoringModifiers` alone for punctuation chords — either drop the chord (simplest, what S27 chose) or add `event.keyCode` fallback (`kVK_ANSI_Comma == 43`). The bug only manifests in Korean input mode, so CI/unit tests can't catch it; manual smoke on the actual locale was the only surfacing path.
- **Manual smoke is the regression test for owner-environment-specific bugs** (Step 1) — bugs that only manifest under specific environment state (locale, input mode, third-party app collisions, hardware variants) can't be unit-tested deterministically. The S27 fix follows scenario 21's precedent: capture the constraint in a unit test where it CAN be deterministic (`testCommandCommaPassesThrough` ensures the popover never re-binds ⌘,) and accept that the original symptom-detection path is owner manual smoke.
- **"Default chord choice in shipped product" decision pattern** (Step 2) — when a user reports the default global chord (⌘⇧L) collides with their environment, prefer the chord-recorder rebind over changing the default. Rationale: any new default risks colliding with a different inevitable third-party app for a different user (Mac users tend to install at least one of {Claude Code, Notion, Linear, Raycast, Logi Options+}, all of which use ⌘⇧/⌘⌥ chords). The shipped chord recorder is the per-user escape hatch (~5 seconds rebind). Default changes for new users only after evidence of systematic collision (e.g., with macOS itself).

### What was checked but not changed

- `KeyboardShortcutCoordinator` + `AwakeManager.toggle()` — read in full to verify owner's proposed ⌘⇧L redesign was already shipped (it was, since v1.1). No edits.
- Smoke harness scenarios 13/15/21/22 — flaky 13-soak-short on first post-Step-1 full run was traced to LSMultipleInstancesProhibited zombie from the immediately-prior xcodebuild test (S26 documented this same pattern). Isolated re-run + full re-run both PASS. Step 1 changes (popover key handler) have zero interaction with App-trigger / IOPMAssertion lifecycle that scenario 13 tests.

### What was deferred to a later session

- **B1.2 still-deferred items** (per 07-spec §1) — per-action chord assignment (e.g., separate chord for "trigger Indefinitely" vs "trigger Turn off"), false-negative chord-reserved indicator. iCloud chord sync overlaps with C-3.
- **Default chord change** — not in S27 scope. Tracked as "consider only if systematic collision evidence emerges" — since Latte chord recorder is the per-user escape, no action until owner sees multiple users hit the same collision.

The v1.x autonomous-coding backlog is now down to:
- Owner-blocked: S8d Pages deploy (one-command after `git remote add origin ...`), S8.5 Apple Dev Program (awaiting Apple), S9 ASC meta (depends on S8.5), V2-22 GitHub remote.
- Multi-session candidates that need owner direction: C-3 iCloud sync of activity history, B1.2 deferred (per-action chords / iCloud chord sync), V2-06 lid-closed-only mode + per-display position requirement.
- Single autonomous candidates that don't fit S27-style "small fix-first": none currently identified.

---

## Next-session entry points (priority order)

1. **Owner-blocked S8d** — `gh repo create bj-park/latte --public` (or owner's chosen name) + `cd ../latte-gh-pages-staging && git remote add origin git@github.com:bj-park/latte.git && git push -u origin gh-pages` + GitHub Settings → Pages → Source = gh-pages. Then `scripts/validate_pages.sh` to confirm 200s.
2. **Owner-blocked S8.5** (Apple Dev Program — applied 2026-05-02). 1-2 days awaiting Apple.
3. **Owner-blocked S9** (App Store Connect; depends on S8.5).
4. **C-3 iCloud sync of activity history** + **B1.2 iCloud chord sync** — joint design (CloudKit + conflict resolution). Multi-session, requires owner direction on whether/when to start.
5. **V2-06 still-deferred**: lid-closed-only mode, per-display position requirement.
6. **B1.2 still-deferred** (per 07-spec §1): per-action chords, false-negative chord-reserved indicator (the iCloud part overlaps with C-3 #4 above).
7. **V2-22 GitHub remote** — `.github/` templates landed in S26 Phase 4; owner-side step is `gh repo create` + `git push -u origin main` + Pages enable.

S27 is an owner-driven fix-first session. v1.x version unchanged at v1.9.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -8
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 587 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 587/587 tests PASS in ~9s. Smoke 22/22 PASS in ~6:14.

**Diagnostic stream (carry over from S24)**: `/usr/bin/log stream --predicate 'subsystem == "com.parkbyeongjun.latte" AND category == "activity"' --info --debug --style compact` (`--info --debug` flags are mandatory or info-level logs are silently filtered).

**Note**: S16-S27 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory. **S27 also confirmed**: a flaky 13-soak-short failure right after `xcodebuild test` is the same zombie-residue pattern (Latte.app from xcodebuild's test runner left around) — kill + retry (or wait the smoke harness's own `quit_app` step) clears it.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 26 (S27) for the most recent session, row 25 (S26) for the immediately prior session.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (now 14-line index) → drill into `project_latte_v1_9.md` for the S20→S27 section.
4. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S27 update)

| # | What | Why blocked | Effort |
|---|---|---|---|
| ⌘⇧L collision | **DONE this session** — owner rebound to ⌘⌃L via Settings chord recorder | Was: Claude Code held the global chord first | 0 (closed) |
| S8d | `gh repo create` + `git remote add origin` + `git push -u origin gh-pages` + GitHub Settings → Pages enable + `scripts/validate_pages.sh`. | Owner clicks + auth | ~5 min (S26 scripts in place) |
| S8.5 | Apple Developer Program — applied 2026-05-02 | Awaiting Apple review | 1-2 days |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push (main branch) + Pages enable | repo URL + auth owner-only | ~10 min |

---

## v1.9 owner-visible behavior reference (post-S27)

- Activity tab no longer flashes the empty-state placeholder ("Trigger fires will appear here") on the first-ever entry per app launch (S25 P-issue-4 — pre-loaded at boot via `AppEnvironment.activityEntries`).
- Activity tab no longer offers Export CSV / Export JSON (feature removed S24 — non-functional across multiple fix attempts).
- Activity tab no longer flashes a spinner-only frame on first entry (S24 P-issue-2).
- Activity tab no longer flashes the previous scroll position on every tab re-entry (S24 P-issue-3 — first-load gate).
- Recurring Quick presets render an active marker (left coffee-accent stripe + right checkmark) on the picked preset row, not on Custom (S23 P-issue-2 + P-issue-3).
- All three popover row types (duration / custom / recurring preset) show consistent left stripe + right checkmark when active (S23 P-issue-3 universal stripe).
- "Until X" caption shows the target wall-clock minute (e.g. "12:00 AM" for midnight preset), never one minute before due to whole-minute precision (S23 P-issue-1).
- Activity tab Retention is a Picker (1 day / 1 week / 2 weeks / 1 month / 2 months / 3 months), not a Stepper. Switching retention does not collapse the chart sections (S23 P-issue-4).
- **NEW S26 P1 (verified S27)**: Popover footer ⌘Q quits Latte from inside the popover. Carbon-registered global awake-toggle chord (default ⌘⇧L, owner rebound to ⌘⌃L this session) is unaffected (passes through). System ⌘⇧Q (log out) passes through.
- **NEW S27 (this session)**: ⌘, in popover passes through (no longer opens Settings — shortcut removed; mouse → Settings… footer button is the supported path).

Carryover from earlier sessions (unchanged):

- v1.0~v1.8 owner-visible feature set (5 trigger types, custom presets, activity log, theme customisation, etc.)
- S22 fixes: pause-all snooze caption, Turn off "big red button" (disables all triggers), HeaderView caption gates, cross-trigger pause-lift auto-recovery, recurring presets light-mode visuals.

---

## ⌘⇧L behaviour reference (read before next chord-related work)

**S27 confirmed**: `AwakeManager.toggle()` at line 683 ALREADY implements "if caffeinate ON → Turn off (disable all triggers); if caffeinate OFF → Indefinitely activate" — no code change pending. Future ⌘⇧L-related work (e.g., per-action chords for B1.2 deferred) builds on this.

```
AwakeManager.toggle():
  if state.assertionHeld {
      process(.constraintDeactivate)
      postUserExplicitDeactivateIfTransitioned()  // disableAll()
  } else {
      process(.userActivate(.indefinite))
  }
```

Don't re-research this in a future session — the behaviour is correct, only the chord (default ⌘⇧L, owner-rebindable) is collision-prone.
