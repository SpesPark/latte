# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 9 family — v1.1 feature pass (S9 + S9.5 + S9.6 + S9d, all 2026-04-29 same-day) |
| **Theme** | First post-v1.0 feature work while owner-side S8d/S8.5 still blocked. Owner picked 1+2+3 from a feature menu (V2-05 schedule trigger, C-1 battery-aware, C-9 pause-all); a follow-up polish pass added A-1 About status card and V2-02 surface parity; S9d closed the loop with B1 (⌘⇧L global hotkey), 4 new smoke scenarios covering the S9 family, and a patch to existing 08/13 scenarios for a pipefail+SIGPIPE false-negative. |
| **Status** | ✅ All landed clean. 309 → **388 tests** (+79). 14 → **18 smoke scenarios**, full batch passes. Working tree clean. Build verified macOS 26.4 SDK + Xcode 26.4.1 (~5.4 s test run). |
| **Tail commit** | (S9d head — see git log) |

### Commit chain (this session)

```
(S9d head)  feat: B1 keyboard shortcut + smoke S9 coverage + 08/13 pipefail patch (v1.1, S9d)
61289a9    smoke: cover S9 family — 4 new scenarios + handoff observations    (S9d step 1)
39a3d2a    docs: rewrite SESSION_HANDOFF for S9 family                          (S9 family wrap)
f37d3d4    feat: A-1 About status card + V2-02 reevaluateWatched parity        (v1.1, S9.6)
70ab76a    feat: C-1 battery-aware mode + C-9 pause-all triggers               (v1.1, S9.5)
0a5cc9e    feat: V2-05 Schedule trigger — recurring time-of-day windows        (v1.1, S9)
ca2d3ff    docs+ci+smoke: S8c-final wrap                                       (S8c base)
```

### What landed

| Sub-session | Feature | Tests Δ | Key surfaces |
|---|---|---|---|
| **S9** | **V2-05** Schedule trigger | +28 | `Sources/Triggers/ScheduleTrigger.swift` (new), `ScheduleTriggerConfigForm` in `TriggersTab`, onboarding wizard row, AppEnvironment 4th default registration |
| **S9.5** | **C-1** Battery-aware mode | +11 | `Sources/Core/PowerSource.swift` (new — `IOPowerSource` real + `MockPowerSource`), `AwakeManager.requireACForAwake`, GeneralTab "Sleep when on battery" toggle |
| **S9.5** | **C-9** Pause-all triggers | +12 | `AwakeManager.triggersPaused`, MenuBarRoot popover top-row toggle, OFF-vote pass-through invariant |
| **S9.6** | **A-1** About status card | +14 | `AssertionStatusFormatter` (pure helpers, no SwiftUI), AboutTab signature change `(manager:coordinator:)`, Mode/Reason/Power rows |
| **S9.6** | **V2-02** reevaluateWatched parity | +6 | `reevaluateWatched()` added to Calendar / WiFi / Schedule (matching AppTrigger S7.9 contract — running-state guard); 4 config forms unified to call it |
| **S9d** | **B1** Global keyboard shortcut (⌘⇧L) | +8 | `Sources/Core/KeyboardShortcutCoordinator.swift` (Carbon `RegisterEventHotKey` + `HotKeyRegistrar` protocol + `MockHotKeyRegistrar`); off by default; Settings → General toggle. Custom-shortcut recorder = v1.2. |
| **S9d** | Smoke harness — S9 family coverage | (smoke only) | 14 → 18 scenarios (15 pause-all / 16 battery-aware / 17 about-status / 18 schedule). Existing 08 / 13 patched for `pipefail` + `grep -Eq` SIGPIPE false-negative; pmset grep broadened to match by owning-pid line (catches both `NoDisplaySleepAssertion` and `NoIdleSleepAssertion`). |

### Architectural invariants preserved

- **State machine untouched** — both C-1 and C-9 gate at the AwakeManager input boundary, not via new state-machine inputs. State machine + `Trigger` protocol surface unchanged across the entire S9 family. B1 wires through `manager.toggle()` which is also pre-existing FSM input (`.userToggle`) — no new state machine surface.
- **AsyncStream lifecycle (S7.11)** — every new trigger code path obeys "do not finish() the stream on stop()". Verified by tests in each new trigger.
- **Persistence schema** — additive only (5 new `SettingsKey` cases: scheduleTriggerEnabled, scheduleTriggerEntries, requireACForAwake, triggersPaused, keyboardShortcutEnabled). No `schemaVersion` bump needed.
- **No-auto-replay policy (C-1, C-9)** — un-pause / AC-return does **not** silently re-acquire awake. User or trigger must re-engage. Documented in code + tested.
- **DI surface for OS-level integrations** — every Carbon / IOKit / NSEvent boundary is fronted by a protocol (`PowerSourceType`, `HotKeyRegistrar`) so tests substitute mocks. Adapter exemption from coverage gate per S7 policy applies.

### Files changed (cumulative across S9 family)

```
Sources/App/AppEnvironment.swift                              (S9: register ScheduleTrigger; S9d: own KeyboardShortcutCoordinator + hotKeyRegistrar DI)
Sources/Core/AwakeManager.swift                               (S9.5: 3 published flags + gate logic + observer)
Sources/Core/KeyboardShortcutCoordinator.swift                (S9d: NEW — Carbon RegisterEventHotKey + HotKeyRegistrar protocol + CarbonHotKeyRegistrar)
Sources/Core/Logging.swift                                    (S9 + S9.5: 2 new categories)
Sources/Core/PowerSource.swift                                (S9.5: NEW)
Sources/Core/SettingsStore.swift                              (S9 + S9.5 + S9d: 5 new keys)
Sources/Triggers/CalendarTrigger.swift                        (S9.6: reevaluateWatched)
Sources/Triggers/ScheduleTrigger.swift                        (S9: NEW; S9.6: rename reevaluate → reevaluateWatched)
Sources/Triggers/WiFiTrigger.swift                            (S9.6: reevaluateWatched)
Sources/UI/MenuBar/MenuBarRoot.swift                          (S9.5: pauseTriggersRow)
Sources/UI/Onboarding/OnboardingView.swift                    (S9: schedule case)
Sources/UI/Settings/AboutTab.swift                            (S9.6: status card)
Sources/UI/Settings/AssertionStatusFormatter.swift            (S9.6: NEW pure helpers)
Sources/UI/Settings/GeneralTab.swift                          (S9.5: requireACForAwake toggle + battery hint; S9d: keyboardShortcutToggle row)
Sources/UI/Settings/SettingsRoot.swift                        (S9.6: AboutTab signature)
Sources/UI/Settings/TriggersTab.swift                         (S9: ScheduleTriggerConfigForm; S9.6: API rename to reevaluateWatched)

Tests/AppEnvironmentTests.swift                               (S9: testRegistersFour…)
Tests/AssertionStatusFormatterTests.swift                     (S9.6: NEW, 14 tests)
Tests/KeyboardShortcutCoordinatorTests.swift                  (S9d: NEW, 8 tests)
Tests/PowerSourceAndConstraintsTests.swift                    (S9.5: NEW, 23 tests)
Tests/ReevaluateWatchedTests.swift                            (S9.6: NEW, 6 tests)
Tests/ScheduleTriggerTests.swift                              (S9: NEW, 28 tests)
Tests/SettingsStoreTests.swift                                (S9 + S9.5 + S9d: 5 new keys)

.smoke/scenarios/08-power-assertion.sh                        (S9d: pmset grep widening + pipefail+SIGPIPE patch)
.smoke/scenarios/13-soak-short.sh                             (S9d: pmset grep widening + pipefail+SIGPIPE patch)
.smoke/scenarios/15-pause-all.sh                              (S9d: NEW)
.smoke/scenarios/16-battery-aware.sh                          (S9d: NEW)
.smoke/scenarios/17-about-status.sh                           (S9d: NEW)
.smoke/scenarios/18-schedule.sh                               (S9d: NEW)

ROADMAP.md                                                    (rows 9, 9b, 9c, 9d filled)
docs/SESSION_HANDOFF.md                                       (THIS file — rewritten)
docs/v2-backlog.md                                            (V2-05 / C-1 / C-9 / A-1 / V2-02 / B1 marked shipped; B1.2 v1.2)
docs/design/02-architecture.md                                (v1.1, v1.2, v1.3 entries)
docs/design/04-data-model.md                                  (§4.6 schedule entry; battery + pause keys)
```

---

## How to resume

```bash
cd ~/Documents/Claude/Projects/Latte
git log --oneline -5
# Expected top: 63b8b3e feat: B1 keyboard shortcut (⌘⇧L) + smoke 08/13 SIGPIPE patch (v1.1, S9d)

# Pre-flight (always before Xcode Cmd-R OR xcodebuild test):
pkill -9 -f "Latte.app" 2>/dev/null
# `LSMultipleInstancesProhibited` blocks the test runner / a fresh build
# from launching when a stale Latte (from prior smoke / Cmd-R) is still
# alive. Killing first turns a confusing "Could not launch LatteTests"
# into a clean run.

# Verify Latte tests:
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 388 tests"
# Expected: Executed 388 tests, with 0 failures (~5.4 s)

# Verify smoke harness (~5 min, requires Release build of Latte at the
# DerivedData path encoded in `.smoke/config.yml`):
xcodebuild build -scheme Latte -configuration Release -destination 'platform=macOS,arch=arm64'
~/dev/smoke-harness/run.sh --project .
# Expected: all scenarios passed (18/18)
```

---

## Owner-side smoke checklist (high priority — do before next code session)

The S9 family added 79 tests but **none of them exercise the new SwiftUI views in a real popover**. The unit tests verify the formatters, gate logic, and trigger semantics; they do not verify that the new UI surfaces look correct. Smoke scenarios 15-18 added in S9d cover the runtime side automatically (full batch 18/18 passes) but visual layout still needs human eyes. Please spend ~5 minutes on:

> **Pre-flight (always)** — `pkill -9 -f "Latte.app"` before Cmd-R. `LSMultipleInstancesProhibited` makes a stale background Latte block all subsequent launches with a confusing LaunchServices error (test runner rejects, popover never appears, frontmost reports as "Latte" but no UI). Verified during S9-family post-session check (2026-04-29 11:24 — pid 32088 was a zombie from earlier smoke; killing it instantly unblocked `xcodebuild test` from `Could not launch "LatteTests"` → 388/388 PASS in 5.4 s).

1. **Build + launch** Latte from Xcode (Cmd-R) on a real macOS 13+ install.
2. **Pause-all toggle (C-9)** — open the menu-bar popover. New row at top under HeaderView: "Pause triggers" / "Triggers paused" with sub-text. Toggle it; the cup should stay live for manual activation but trigger votes should be ignored.
3. **Battery-aware (C-1)** — Settings → General → Behavior. Toggle "Sleep when on battery". On a laptop, unplug the AC adapter while awake; expect cup to drop to asleep within ~1 s. Re-plug; cup stays asleep (explicit non-feature: no auto-resume). Caption "Currently on battery — Latte is not holding awake." should appear under the toggle while unplugged.
4. **About status card (A-1)** — Settings → About. Below the hero card, a status card now shows State / Mode / Reason / Power. Verify Mode flips between "System + display awake" and "System awake (display may sleep)" when toggling Settings → General → "Allow display to sleep". **Note**: Power row is hidden by design when "Sleep when on battery" is OFF (see `AssertionStatusFormatter.powerLabel` returning nil); this is intentional clutter-avoidance, but confirm it reads correctly when both are off (no row) and when battery-aware is on (row shows AC vs battery).
5. **Schedule trigger (V2-05)** — Settings → Triggers → Schedule. Enable, add an entry covering "now"; cup should activate. Cross-midnight entries (e.g. 23:00–01:00) auto-render a caption "Crosses midnight — runs from start time on the selected day(s) until the end time the next morning." (verified to exist in code at `TriggersTab.swift:839-844`); confirm it reads correctly. **Note**: Settings window is fixed-size 460×360 + non-resizable, so the Schedule section sits below the fold — scroll the Triggers tab to see all four sections.
6. **Keyboard shortcut (B1, S9d)** — Settings → General → "Toggle Latte with ⌘⇧L". Default is OFF. Toggle ON, close Settings, then anywhere on the Mac press ⌘⇧L: Latte should toggle awake/asleep (cup state flips, menu-bar icon swaps to the awake variant). Toggle OFF in Settings to release the chord — useful if it conflicts with another app. The chord is fixed for v1.1; custom recorder is v1.2 (B1.2).

If any of these surfaces are awkward, file as P1 follow-up before piling on more v1.1 features.

### Pre-emptive code-review observations (before owner smoke)

S9d session-end pass surfaced these — neither blocks shipping, but recording so future iterations don't re-discover:

- **A-1 Power row conditional rendering** — verified the `nil`-suppression is intentional (per code comment in `AssertionStatusFormatter.powerLabel`). Owner should confirm during step 4.
- **V2-05 cross-midnight visual hint** — *already implemented* (`TriggersTab.swift:839-844`).
- **A-1 reason field shows raw bundle id** — when App trigger is the active driver, About status card's Reason row reads "App: com.apple.finder" instead of a friendly name. S7.7's resolution applies to AppRow (Triggers tab) but not to `AwakeManager.activeReason` rendering. v1.x polish candidate; no ship impact.
- **`SettingsKey.activateOnLaunch` is declared but never read** — design docs (`02-architecture.md`, `04-data-model.md`) describe it as "boot Awake on launch" — deferred but still a planned feature, not dead code. Do **not** delete; revisit when the matching code path is implemented.
- **Settings window not resizable** — `SettingsWindowController` uses `[.titled, .closable, .miniaturizable]` (no `.resizable`) and `SettingsRoot` is `.frame(width: 460, height: 360)`. Schedule (4th trigger) sits below the fold. Adding `.resizable` would unlock both manual scroll AND AppleScript resize from the smoke harness — a small UX win + future test ergonomic. Tracked informally; not pressing.
- **Smoke harness coverage extended** — 14 → 18 scenarios. `15-pause-all`, `16-battery-aware`, `17-about-status`, `18-schedule`. Existing 08 / 13 patched in S9d for the same `pipefail` + `grep -Eq` SIGPIPE false-negative + pmset grep widened (`pid N(Latte):` instead of `PreventUserIdleSystemSleep`). Run via `~/dev/smoke-harness/run.sh --project ~/Documents/Claude/Projects/Latte` (~5 min, 18/18 expected).

---

## Next session entry points (in priority order)

1. **Owner smoke results** — the 6-step list above (now includes B1 ⌘⇧L). P1 from there comes first.
2. **Owner-side blocked actions** (still): S8d ~5 min capture + Pages deploy; S8.5 Apple Developer Program enrollment ($99/yr, 1–2 day review).
3. **Remaining v1.1 candidates** (not yet picked):
   - C-7 Quick presets in menu bar
   - C-3 Activity history (Charts framework, new Settings tab — single-session size)
4. **simplify pass** on the S9 family (S9 + S9.5 + S9.6 + S9d) — best done in a fresh session with a fresh reviewer agent.
5. **Settings window `.resizable`** — a small UX win + lets the smoke harness drive AppleScript resize (would unblock visible Schedule capture in scenario 18). Tracked informally in the observations section above.
6. **v1.2 candidates** (post-v1.1):
   - **B1.2** Custom keyboard-shortcut recorder (v1.2 polish on top of the fixed ⌘⇧L shipped in S9d)
   - **V2-06** External display trigger (validated demand per S8b research)

---

## Decisions still pending owner approval

- Whether to keep going on v1.1 features in parallel with owner-side S8d, or pause new feature work until S8d/S8.5 unblocks (App Store-bound work).

---

## Known issues / debt

- AboutTab status card layout has not been visually reviewed (see owner smoke step 4).
- C-1 IOKit code path (`IOPowerSource`) has no real-system test coverage — adapter classes are exempt from the 80% gate per S7 policy. `MockPowerSource` exercises the protocol contract.
- **B1 Carbon hotkey path (`CarbonHotKeyRegistrar`) has no real-system test coverage** — same adapter exemption. `MockHotKeyRegistrar` exercises the protocol contract. Real Carbon registration only verified manually at owner smoke step 6.
- **B1 hardcoded chord** — ⌘⇧L cannot be customised in v1.1. If a user already binds ⌘⇧L globally, registration fails and the hotkey silently no-ops (logged at error level under category `shortcut`). v1.2 (B1.2) adds the recorder.
- **`MockPowerSource` / `MockHotKeyRegistrar`** ship in the production module so DI works at app start. Acceptable; no symbol leak per Swift module boundaries.
- `MockPowerSource` is not isolated to test-target visibility — it ships in the production module so `AwakeManager` DI can substitute it. Acceptable for now; not a leak.

---

## Recap stats (S9 family end)

| | S8c end | S9d end | Δ |
|---|---|---|---|
| Tests | 309 | **388** | +79 |
| Smoke scenarios | 14 | **18** | +4 |
| Default triggers | 3 | **4** | +1 (Schedule) |
| AwakeManager `@Published` settings | 1 (allowDisplaySleep) | **3** (+ requireACForAwake, triggersPaused) | +2 |
| Settings keys total | 22 | **27** | +5 |
| Power-source DI surface | none | `PowerSourceType` | +1 protocol |
| Hotkey DI surface | none | `HotKeyRegistrar` | +1 protocol |
| Global hotkeys | 0 | **1** (⌘⇧L) | +1 |
