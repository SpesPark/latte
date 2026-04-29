# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 10 — S9-family follow-through (simplify pass, Settings resizable, AppTrigger friendly reason, smoke comment hygiene, **Activate at launch**). 2026-04-30. |
| **Theme** | Owner gave green-light to take recommended priorities in parallel while owner-side S8d/S8.5 stays blocked. Spawned a code-reviewer simplify pass on the S9 family and resolved its findings; landed `.resizable` on Settings (handoff-tracked observation); fixed S9d "raw bundle id in Reason" debt with friendly-name resolution + 3 regression tests; cleaned the now-stale 18-schedule smoke comment; closed the deferred `SettingsKey.activateOnLaunch` debt with an end-to-end "Activate at launch" feature (toggle + boot path + 3-gate behavior + 7 unit tests + new smoke scenario 19). Six landed commits, no architectural change. |
| **Status** | ✅ All landed clean. 388 → **398 tests** (+3 regression for AppTrigger friendly-reason + 7 for activateOnLaunch). Smoke 18 → **19 scenarios**, full batch passes. Working tree clean. Build verified macOS 26.4 SDK + Xcode 26.4.1 (~5.0 s test run). |
| **Tail commit** | resolves to S10 head when read (~`3ebc4af` after ROADMAP/v2-backlog sync) — see `git log -8` |

### Commit chain (this session)

```
3ebc4af  docs: ROADMAP row 9e + v2-backlog S10 shipped section (S10)
5c06ea9  docs: SESSION_HANDOFF S10 update for Activate-at-launch (S10)
a2c74a3  feat: Activate at launch (S10)
cfe9155  smoke: 18-schedule INFO line reflects resizable Settings (S10)
c6c6408  fix: AppTrigger vote reason uses friendly app names (S10)
66e8628  feat: Settings window resizable (S10)
d4497f1  chore: S9 family simplify-pass cleanup (S10)
f1fbc1d  docs: SESSION_HANDOFF wrap for S9 family                          (S9 family wrap)
63b8b3e  feat: B1 keyboard shortcut + smoke S9 coverage + 08/13 patch     (S9d)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `d4497f1` | **Simplify-pass cleanup** — `LatteLog.shortcut` added; `IOPowerSource` + `CarbonHotKeyRegistrar` drop inline `Logger(subsystem:...)`; `ScheduleEntryRow` label committed on `.onChange` (was `.onSubmit`-only → silently dropped on focus-loss); `CarbonHotKeyRegistrar` class doc adds process-global static state note; 3× `reevaluateWatched()` comment trims drop misleading `AppTrigger` cross-reference. | 0 (no behavior change) |
| 2 | `66e8628` | **Settings window resizable** — `SettingsWindowController` adds `.resizable` to styleMask + explicit `setContentSize(NSSize(460, 360))`; `SettingsRoot` `.frame(width:height:)` → `.frame(minWidth:minHeight:)`. Opens at the same default; user can drag to grow; Form auto-scrolls so Schedule (4th trigger) becomes visible without scroll. | 0 (AppKit-only; existing tests cover SwiftUI surfaces) |
| 3 | `c6c6408` | **AppTrigger friendly reason** — S9d known issue closed. `AppTrigger.emitOn` now resolves bundle ids through `WorkspaceSource.displayInfo` (`us.zoom.xos` → "Zoom", explicit `displayInfoLookup` overrides win, unmapped ids fall back to raw id). Sorted-by-id, joined as friendly names. | +3 regression (fallback / curated / explicit-override) + 4 existing test literals updated |
| 4 | `cfe9155` | **Smoke 18 comment hygiene** — `.smoke/scenarios/18-schedule.sh` INFO line + inline comment rewritten to reflect "resizable but harness lacks AX permission for AppleScript-driven resize" instead of the old "non-resizable" claim. No code change. | 0 (smoke-only) |
| 5 | `a2c74a3` | **Activate at launch** — closes the deferred `SettingsKey.activateOnLaunch` debt. New `AppEnvironment.activateOnLaunch` published flag + `applyActivateOnLaunchIfEnabled()` method invoked from `LatteAppDelegate.applicationDidFinishLaunching` after `bootTriggers`. Three gates: flag ON + onboarding completed + manager currently asleep. Activates `.indefinite` with `reason: .launch`. Fixes the previously-dead `reason:` parameter on `AwakeManager.activate(for:reason:)` — the FSM hardcodes `.user` for `.userActivate` inputs, so the manager now overrides `activeReason` post-step when caller passes a non-`.user` reason. New Settings → General → Behavior toggle. New smoke scenario `19-activate-on-launch.sh` covers ON / OFF / onboarding-incomplete gates. | +7 (4 binding mirror + 3 functional gating) |

### Reviewer findings resolved

S9-family code-reviewer simplify pass (run 2026-04-30) returned: **0 CRITICAL, 0 HIGH, 2 MEDIUM, 2 LOW** — all addressed in commit `d4497f1`. Verdict was APPROVE; the fixes are quality-of-life cleanup only.

### Architectural invariants preserved

- **No state-machine changes** across all four S10 commits.
- **Persistence schema unchanged** (no new SettingsKey cases this session).
- **DI surface unchanged** (no new protocols; `WorkspaceSource.displayInfo` was already a S7.7-vintage seam — this session just calls it from one more place).
- **AsyncStream lifecycle** untouched.
- **No-auto-replay policy** untouched.

### Files changed (S10)

```
Sources/App/AppEnvironment.swift                   (a2c74a3: + activateOnLaunch published + applyActivateOnLaunchIfEnabled)
Sources/App/LatteApp.swift                         (a2c74a3: post-bootTriggers call)
Sources/Core/AwakeManager.swift                    (a2c74a3: activate() honours reason: param post-FSM)
Sources/Core/KeyboardShortcutCoordinator.swift     (d4497f1: LatteLog.shortcut + class doc)
Sources/Core/Logging.swift                         (d4497f1: + LatteLog.shortcut)
Sources/Core/PowerSource.swift                     (d4497f1: LatteLog.powerSource)
Sources/Triggers/AppTrigger.swift                  (c6c6408: emitOn → friendly via displayInfo)
Sources/Triggers/CalendarTrigger.swift             (d4497f1: reevaluateWatched comment trim)
Sources/Triggers/ScheduleTrigger.swift             (d4497f1: reevaluateWatched comment trim)
Sources/Triggers/WiFiTrigger.swift                 (d4497f1: reevaluateWatched comment trim)
Sources/UI/Settings/GeneralTab.swift               (a2c74a3: + activateOnLaunchToggle in Behavior)
Sources/UI/Settings/SettingsRoot.swift             (66e8628: minWidth/minHeight)
Sources/UI/Settings/SettingsWindowController.swift (66e8628: + .resizable + setContentSize)
Sources/UI/Settings/TriggersTab.swift              (d4497f1: ScheduleEntryRow label .onChange)

Tests/AppEnvironmentTests.swift                    (a2c74a3: + 7 tests for activateOnLaunch)
Tests/AppTriggerTests.swift                        (c6c6408: 4 literal updates + 3 new regression tests)
Tests/TriggerCoordinatorTests.swift                (c6c6408: 1 literal update)

.smoke/scenarios/18-schedule.sh                    (cfe9155: comment hygiene)
.smoke/scenarios/19-activate-on-launch.sh          (a2c74a3: NEW)
```

---

## How to resume

```bash
cd ~/Documents/Claude/Projects/Latte
git log --oneline -7
# Expected top: cfe9155 smoke: 18-schedule INFO line reflects resizable Settings (S10)

# Pre-flight (always before Xcode Cmd-R OR xcodebuild test):
pkill -9 -f "Latte.app" 2>/dev/null
# `LSMultipleInstancesProhibited` blocks the test runner / a fresh build
# from launching when a stale Latte (from prior smoke / Cmd-R) is still
# alive. Killing first turns a confusing "Could not launch LatteTests"
# into a clean run.

# Verify Latte tests:
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 398 tests"
# Expected: Executed 398 tests, with 0 failures (~5.0 s)

# Verify smoke harness (~5 min, requires Release build of Latte at the
# DerivedData path encoded in `.smoke/config.yml`):
xcodebuild build -scheme Latte -configuration Release -destination 'platform=macOS,arch=arm64'
~/dev/smoke-harness/run.sh --project .
# Expected: all scenarios passed (19/19)

# IMPORTANT: run `xcodebuild test` and `~/dev/smoke-harness/run.sh` SERIALLY,
# never in parallel — both launch `com.parkbyeongjun.latte` and the test
# runner's failed launch (LSMultipleInstancesProhibited) propagates SIGKILL
# to the smoke scenario's Latte instance, surfacing as a phantom rc=137 fail
# (typically on `03-icon-states`). Verified S10 cold-start 2026-04-30.
```

---

## Owner-side smoke checklist (high priority — do before next code session)

Same 6-step list as S9d, with one update on step 5 to reflect the S10 resizable change:

> **Pre-flight (always)** — `pkill -9 -f "Latte.app"` before Cmd-R. `LSMultipleInstancesProhibited` makes a stale background Latte block all subsequent launches with a confusing LaunchServices error.

1. **Build + launch** Latte from Xcode (Cmd-R) on a real macOS 13+ install.
2. **Pause-all toggle (C-9)** — open the menu-bar popover. New row at top under HeaderView: "Pause triggers" / "Triggers paused" with sub-text. Toggle it; the cup should stay live for manual activation but trigger votes should be ignored.
3. **Battery-aware (C-1)** — Settings → General → Behavior. Toggle "Sleep when on battery". On a laptop, unplug the AC adapter while awake; expect cup to drop to asleep within ~1 s. Re-plug; cup stays asleep (explicit non-feature: no auto-resume). Caption "Currently on battery — Latte is not holding awake." should appear under the toggle while unplugged.
4. **About status card (A-1)** — Settings → About. Below the hero card, a status card now shows State / Mode / Reason / Power. Verify Mode flips between "System + display awake" and "System awake (display may sleep)" when toggling Settings → General → "Allow display to sleep". **Reason row should now read "App: Finder" / "App: Zoom" instead of bundle ids** (S10 c6c6408 fix). **Power row** is hidden by design when "Sleep when on battery" is OFF.
5. **Schedule trigger (V2-05)** — Settings → Triggers → Schedule. Enable, add an entry covering "now"; cup should activate. Cross-midnight entries (e.g. 23:00–01:00) auto-render a caption "Crosses midnight…". **NEW (S10 66e8628):** Settings window is now resizable — drag any corner to grow it; the Form auto-scrolls so all four trigger sections fit without manual scroll.
6. **Keyboard shortcut (B1)** — Settings → General → "Toggle Latte with ⌘⇧L". Default OFF. Toggle ON, close Settings, then anywhere on the Mac press ⌘⇧L: Latte should toggle awake/asleep. Custom recorder is v1.2 (B1.2).

If any of these surfaces are awkward, file as P1 follow-up before piling on more v1.1 features.

### Pre-emptive code-review observations (cumulative; resolved items struck through)

- ~~**A-1 reason field shows raw bundle id**~~ — **resolved S10 c6c6408**.
- ~~**Settings window not resizable**~~ — **resolved S10 66e8628**.
- ~~**`SettingsKey.activateOnLaunch` declared but never read**~~ — **resolved S10 a2c74a3** (full feature: toggle + boot path + 3-gate behavior).
- **A-1 Power row conditional rendering** — verified the `nil`-suppression is intentional. Owner should confirm during step 4.
- **Smoke harness coverage** — **19 scenarios**. Run via `~/dev/smoke-harness/run.sh --project ~/Documents/Claude/Projects/Latte` (~5 min, 19/19 expected).

---

## Next session entry points (in priority order)

1. **Owner smoke results** — the 6-step list above. P1 from there comes first.
2. **Owner-side blocked actions** (still): S8d ~5 min capture + Pages deploy; S8.5 Apple Developer Program enrollment ($99/yr, 1–2 day review).
3. **Remaining v1.1 candidates** (need owner pick + scope confirmation):
   - **C-7 Quick presets** — note that `AwakeDuration.presets` already has 7 entries and the popover already renders them. The actual delta vs the original sketch is "Until X PM" semantic presets, which require a small AwakeManager state extension or an `AwakeDuration.until(Date)` enum case. See "C-7 scope alternatives" in S10 conversation transcript.
   - **C-3 Activity history** — Charts framework + new Settings tab. May trigger SwiftData v2 migration depending on storage choice. Higher risk while owner-side S8d/S8.5 still pending.
4. **Smoke harness AX permission** — granting the runner Accessibility privilege would unlock AppleScript-driven window resize and let scenario 18 capture the full Triggers tab in one shot. Pure infra; affects no app code.
5. **v1.2 candidates** (post-v1.1):
   - **B1.2** Custom keyboard-shortcut recorder
   - **V2-06** External display trigger (validated demand per S8b research)

> **Activate-at-launch follow-up note**: the published `activeReason` is now overridden post-FSM when callers pass a non-`.user` reason. This is a narrow workaround; if a future change adds more `.launch`-style reasons (e.g. `.system`, `.shortcut`), prefer plumbing the reason through `AwakeInput.userActivate` directly (8 Sources sites + 7 Tests sites). Documented in `Sources/Core/AwakeManager.swift:activate(for:reason:)` inline comment.

---

## Decisions still pending owner approval

- **C-7 scope** — A (`.minutes(N)` conversion, simplest, UX checkmark leaks to Custom row) vs B (`AwakeDuration.until(Date)`, semantic-clean but ~3× LOC) vs C (`@Published var activeQuickPreset`, future-proofs C-3) vs skip-to-C-3.
- Whether to keep going on v1.1 features in parallel with owner-side S8d, or pause new feature work until S8d/S8.5 unblocks.

---

## Known issues / debt

- AboutTab status card layout has not been visually reviewed (see owner smoke step 4).
- C-1 IOKit code path (`IOPowerSource`) has no real-system test coverage — adapter classes are exempt from the 80% gate per S7 policy. `MockPowerSource` exercises the protocol contract.
- B1 Carbon hotkey path (`CarbonHotKeyRegistrar`) has no real-system test coverage — same adapter exemption. `MockHotKeyRegistrar` exercises the protocol contract. Real Carbon registration only verified manually at owner smoke step 6.
- B1 hardcoded chord — ⌘⇧L cannot be customised in v1.1. v1.2 (B1.2) adds the recorder.
- `MockPowerSource` / `MockHotKeyRegistrar` ship in the production module so DI works at app start. Acceptable; no symbol leak per Swift module boundaries.
- Smoke harness lacks Accessibility permission, so AppleScript-driven window resize from scenario 18 is not yet possible. Schedule trigger (4th) sits below the default 460×360 fold; manual scroll required for visual review.

---

## Recap stats (S10 end)

| | S8c end | S9d end | **S10 end** | Δ (S10) |
|---|---|---|---|---|
| Tests | 309 | 388 | **398** | +10 (3 regression + 7 new feature) |
| Smoke scenarios | 14 | 18 | **19** | +1 (19-activate-on-launch) |
| Default triggers | 3 | 4 | **4** | 0 |
| AwakeManager `@Published` settings | 1 | 3 | **3** | 0 |
| AppEnvironment `@Published` settings | 2 (icon style + accent) | 2 | **3** (+ activateOnLaunch) | +1 |
| Settings keys total | 22 | 27 | **27** (activateOnLaunch was already declared) | 0 |
| Power-source DI surface | none | `PowerSourceType` | unchanged | 0 |
| Hotkey DI surface | none | `HotKeyRegistrar` | unchanged | 0 |
| Global hotkeys | 0 | 1 (⌘⇧L) | **1** | 0 |
| Settings window | fixed 460×360 | fixed 460×360 | **resizable** | +1 UX win |
| AppTrigger Reason format | raw bundle id | raw bundle id | **friendly via displayInfo** | semantic fix |
| `AwakeReason.launch` | declared, unused | declared, unused | **wired end-to-end** | feature complete |
