# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 9 family — v1.1 feature pass (S9 + S9.5 + S9.6, all 2026-04-29 same-day) |
| **Theme** | First post-v1.0 feature work while owner-side S8d/S8.5 still blocked. Owner picked 1+2+3 from a feature menu (V2-05 schedule trigger, C-1 battery-aware, C-9 pause-all); a follow-up polish pass added A-1 About status card and V2-02 surface parity. |
| **Status** | ✅ All landed clean. 309 → **380 tests** (+71). Working tree clean. Build verified macOS 26.4 SDK + Xcode 26.4.1 (~5.2 s test run). |
| **Tail commit** | `f37d3d4` |

### Commit chain (this session)

```
f37d3d4 feat: A-1 About status card + V2-02 reevaluateWatched parity (v1.1, S9.6)
70ab76a feat: C-1 battery-aware mode + C-9 pause-all triggers          (v1.1, S9.5)
0a5cc9e feat: V2-05 Schedule trigger — recurring time-of-day windows   (v1.1, S9)
ca2d3ff docs+ci+smoke: S8c-final wrap                                  (S8c base)
```

### What landed

| Sub-session | Feature | Tests Δ | Key surfaces |
|---|---|---|---|
| **S9** | **V2-05** Schedule trigger | +28 | `Sources/Triggers/ScheduleTrigger.swift` (new), `ScheduleTriggerConfigForm` in `TriggersTab`, onboarding wizard row, AppEnvironment 4th default registration |
| **S9.5** | **C-1** Battery-aware mode | +11 | `Sources/Core/PowerSource.swift` (new — `IOPowerSource` real + `MockPowerSource`), `AwakeManager.requireACForAwake`, GeneralTab "Sleep when on battery" toggle |
| **S9.5** | **C-9** Pause-all triggers | +12 | `AwakeManager.triggersPaused`, MenuBarRoot popover top-row toggle, OFF-vote pass-through invariant |
| **S9.6** | **A-1** About status card | +14 | `AssertionStatusFormatter` (pure helpers, no SwiftUI), AboutTab signature change `(manager:coordinator:)`, Mode/Reason/Power rows |
| **S9.6** | **V2-02** reevaluateWatched parity | +6 | `reevaluateWatched()` added to Calendar / WiFi / Schedule (matching AppTrigger S7.9 contract — running-state guard); 4 config forms unified to call it |

### Architectural invariants preserved

- **State machine untouched** — both C-1 and C-9 gate at the AwakeManager input boundary, not via new state-machine inputs. State machine + `Trigger` protocol surface unchanged across the entire S9 family.
- **AsyncStream lifecycle (S7.11)** — every new trigger code path obeys "do not finish() the stream on stop()". Verified by tests in each new trigger.
- **Persistence schema** — additive only (4 new `SettingsKey` cases: scheduleTriggerEnabled, scheduleTriggerEntries, requireACForAwake, triggersPaused). No `schemaVersion` bump needed.
- **No-auto-replay policy (C-1, C-9)** — un-pause / AC-return does **not** silently re-acquire awake. User or trigger must re-engage. Documented in code + tested.

### Files changed (cumulative across S9 family)

```
Sources/App/AppEnvironment.swift                              (S9: register ScheduleTrigger)
Sources/Core/AwakeManager.swift                               (S9.5: 3 published flags + gate logic + observer)
Sources/Core/Logging.swift                                    (S9 + S9.5: 2 new categories)
Sources/Core/PowerSource.swift                                (S9.5: NEW)
Sources/Core/SettingsStore.swift                              (S9 + S9.5: 4 new keys)
Sources/Triggers/CalendarTrigger.swift                        (S9.6: reevaluateWatched)
Sources/Triggers/ScheduleTrigger.swift                        (S9: NEW; S9.6: rename reevaluate → reevaluateWatched)
Sources/Triggers/WiFiTrigger.swift                            (S9.6: reevaluateWatched)
Sources/UI/MenuBar/MenuBarRoot.swift                          (S9.5: pauseTriggersRow)
Sources/UI/Onboarding/OnboardingView.swift                    (S9: schedule case)
Sources/UI/Settings/AboutTab.swift                            (S9.6: status card)
Sources/UI/Settings/AssertionStatusFormatter.swift            (S9.6: NEW pure helpers)
Sources/UI/Settings/GeneralTab.swift                          (S9.5: requireACForAwake toggle + battery hint)
Sources/UI/Settings/SettingsRoot.swift                        (S9.6: AboutTab signature)
Sources/UI/Settings/TriggersTab.swift                         (S9: ScheduleTriggerConfigForm; S9.6: API rename to reevaluateWatched)

Tests/AppEnvironmentTests.swift                               (S9: testRegistersFour…)
Tests/AssertionStatusFormatterTests.swift                     (S9.6: NEW, 14 tests)
Tests/PowerSourceAndConstraintsTests.swift                    (S9.5: NEW, 23 tests)
Tests/ReevaluateWatchedTests.swift                            (S9.6: NEW, 6 tests)
Tests/ScheduleTriggerTests.swift                              (S9: NEW, 28 tests)
Tests/SettingsStoreTests.swift                                (S9 + S9.5: 4 new keys)

ROADMAP.md                                                    (rows 9, 9b, 9c filled)
docs/SESSION_HANDOFF.md                                       (THIS file — rewritten)
docs/v2-backlog.md                                            (V2-05 / C-1 / C-9 / A-1 / V2-02 marked shipped)
docs/design/02-architecture.md                                (v1.1, v1.2, v1.3 entries)
docs/design/04-data-model.md                                  (§4.6 schedule entry; battery + pause keys)
```

---

## How to resume

```bash
cd ~/Documents/Claude/Projects/Latte
git log --oneline -5
# Expected: f37d3d4 at the top.

# Verify tests:
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 380 tests"
# Expected: Executed 380 tests, with 0 failures
```

---

## Owner-side smoke checklist (high priority — do before next code session)

The S9 family added 71 tests but **none of them exercise the new SwiftUI views in a real popover**. The unit tests verify the formatters, gate logic, and trigger semantics; they do not verify that the new UI surfaces look correct. Before piling more code on, please spend ~5 minutes on:

> **Pre-flight (always)** — `pkill -9 -f "Latte.app"` before Cmd-R. `LSMultipleInstancesProhibited` makes a stale background Latte block all subsequent launches with a confusing LaunchServices error (test runner rejects, popover never appears, frontmost reports as "Latte" but no UI). Verified during S9-family post-session check (2026-04-29 11:24 — pid 32088 was a zombie from earlier smoke; killing it instantly unblocked `xcodebuild test` from `Could not launch "LatteTests"` → 380/380 PASS in 5.1 s).

1. **Build + launch** Latte from Xcode (Cmd-R) on a real macOS 13+ install.
2. **Pause-all toggle (C-9)** — open the menu-bar popover. New row at top under HeaderView: "Pause triggers" / "Triggers paused" with sub-text. Toggle it; the cup should stay live for manual activation but trigger votes should be ignored.
3. **Battery-aware (C-1)** — Settings → General → Behavior. Toggle "Sleep when on battery". On a laptop, unplug the AC adapter while awake; expect cup to drop to asleep within ~1 s. Re-plug; cup stays asleep (explicit non-feature: no auto-resume). Caption "Currently on battery — Latte is not holding awake." should appear under the toggle while unplugged.
4. **About status card (A-1)** — Settings → About. Below the hero card, a status card now shows State / Mode / Reason / Power. Verify Mode flips between "System + display awake" and "System awake (display may sleep)" when toggling Settings → General → "Allow display to sleep". **Note**: Power row is hidden by design when "Sleep when on battery" is OFF (see `AssertionStatusFormatter.powerLabel` returning nil); this is intentional clutter-avoidance, but confirm it reads correctly when both are off (no row) and when battery-aware is on (row shows AC vs battery).
5. **Schedule trigger (V2-05)** — Settings → Triggers → Schedule. Enable, add an entry covering "now"; cup should activate. Cross-midnight entries (e.g. 23:00–01:00) auto-render a caption "Crosses midnight — runs from start time on the selected day(s) until the end time the next morning." (verified to exist in code at `TriggersTab.swift:839-844`); confirm it reads correctly. Late-night verification or manual `now()` injection in dev for the runtime path.

If any of these surfaces are awkward, file as P1 follow-up before piling on more v1.1 features.

### Pre-emptive code-review observations (before owner smoke)

A walk-through of the new SwiftUI surfaces during session-end verification surfaced two latent items worth flagging *before* owner runs the smoke — neither is a P1 bug, but recording so they don't get re-discovered:

- **A-1 Power row conditional rendering** — verified the `nil`-suppression is intentional (per code comment in `AssertionStatusFormatter.powerLabel`). Owner should confirm during step 4.
- **V2-05 cross-midnight visual hint** — *already implemented* (`TriggersTab.swift:839-844`): caption "Crosses midnight — runs from start time on the selected day(s) until the end time the next morning." auto-renders when `endDate <= startDate`. Earlier handoff observation that this was missing was incorrect; verified by file read during smoke pre-flight.
- **Smoke harness coverage** — extended in this same session: `15-pause-all.sh`, `16-battery-aware.sh`, `17-about-status.sh`, `18-schedule.sh` added (4 scenarios, ~12 KB). Now 18 scenarios total. The new four exercise the C-9 gate (paused → no assertion; unpaused → assertion held), C-1 settings round-trip + power-source-conditional gate, A-1 status card in 3 modes, and V2-05 runtime + cross-midnight visual capture. Run them via `~/dev/smoke-harness/run.sh --project ~/Documents/Claude/Projects/Latte`.

---

## Next session entry points (in priority order)

1. **Owner smoke results** — the 5-step list above. P1 from there comes first.
2. **Owner-side blocked actions** (still): S8d ~5 min capture + Pages deploy; S8.5 Apple Developer Program enrollment ($99/yr, 1–2 day review).
3. **Remaining v1.1 candidates** (not yet picked):
   - Keyboard shortcut for manual toggle (backlog row, still pending — needs conflict-avoidance UI)
   - C-7 Quick presets in menu bar
   - C-3 Activity history (Charts framework, new Settings tab — single-session size)
4. **simplify pass** on the S9 family — best done in a fresh session with a fresh reviewer, not in continuation.

---

## Decisions still pending owner approval

- Whether keyboard shortcut belongs in v1.1 or v1.2.
- Whether to keep going on v1.1 features in parallel with owner-side S8d, or pause new feature work until S8d/S8.5 unblocks (App Store-bound work).

---

## Known issues / debt

- AboutTab status card layout has not been visually reviewed (see owner smoke step 4).
- C-1 IOKit code path (`IOPowerSource`) has no real-system test coverage — adapter classes are exempt from the 80% gate per S7 policy. `MockPowerSource` exercises the protocol contract.
- `MockPowerSource` is not isolated to test-target visibility — it ships in the production module so `AwakeManager` DI can substitute it. Acceptable for now; not a leak.

---

## Recap stats (S9 family end)

| | S8c end | S9.6 end | Δ |
|---|---|---|---|
| Tests | 309 | **380** | +71 |
| Default triggers | 3 | **4** | +1 (Schedule) |
| AwakeManager `@Published` settings | 1 (allowDisplaySleep) | **3** (+ requireACForAwake, triggersPaused) | +2 |
| Settings keys total | 22 | **26** | +4 |
| Power-source DI surface | none | `PowerSourceType` | +1 protocol |
| Tail commit | `ca2d3ff` | `f37d3d4` | +3 commits |
