# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S11** — V2-06 ExternalDisplayTrigger shipped end-to-end (RED+GREEN+wire+UI+smoke+docs) plus a 3rd simplify-pass cleanup that landed first as a tiny LOW fix. 2026-04-30, same-day continuation of the S10 → S10.1 → S10.1.1 chain. |
| **Theme** | Owner approved the 1순위 plan: **(B3.3) 3rd simplify-pass on S10.1+S10.1.1 → (B1.1) V2-06 RED-GREEN as designed in `docs/design/06-display-trigger.md`**. Both landed without any owner-side decision needed; v1.2 work proceeded in parallel while owner-side S8d/S8.5 still blocks. The 3rd simplify-pass APPROVE'd; the single LOW (em-dash → ASCII hyphen in a `LatteLog.awake.info` string) shipped as a one-line chore. V2-06 then landed as a four-commit sequence — `Core RED+GREEN → Wire+coordinator tests → Settings UI → Smoke 20`. Two implementation surprises were resolved in-session and documented: (1) `source.changeStream` is single-pass, so the spec's "cancel observeTask on stop / recreate on start" pattern would forfeit subsequent yields → switched to a `isRunning` gate flag with a single lifetime-long observeTask; (2) the spec's "no-replay on re-enable" §3 paragraph was inconsistent with WiFi/AppTrigger restart semantics → adopted WiFi pattern (start() always evaluates fresh source state) and amended the spec doc inline. |
| **Status** | ✅ **5 commits** landed (1 cleanup + 4 V2-06 + this docs wrap). **398 → 409 tests** (+11: 9 unit ExternalDisplayTriggerTests + 2 coordinator integration). **19 → 20 smoke scenarios** (full batch passes, ~5 min). Working tree clean after wrap commit. xcodebuild test ~4.6 s, smoke ~5 min. |
| **Tail commit** | resolves to the head of the S11 chain when read — typically the latest `docs: SESSION_HANDOFF…` commit. Run `git log --oneline -8` to see this session in full. |

### Commit chain (this session — top is HEAD)

```
<wrap commit>  docs: SESSION_HANDOFF wrap for S11 (V2-06 shipped + 3rd simplify-pass)
5642bbc  smoke: scenario 20 external-display (V2-06)               (V2-06 #4)
fd9df79  feat: TriggersTab External Display section (V2-06 UI)      (V2-06 #3)
9c6504c  feat: register ExternalDisplayTrigger + 2 coordinator tests (V2-06 wire)  (V2-06 #2)
4895d35  feat: ExternalDisplayTrigger core (V2-06 RED+GREEN)        (V2-06 #1)
5a7f42f  chore: ASCII hyphen in activate-at-launch log (3rd simplify-pass LOW)  (B3.3)
f11994c  docs: SESSION_HANDOFF self-referential tail rephrased (S10.1.1)         (prev wrap)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `5a7f42f` | **3rd simplify-pass LOW fix** — `AppEnvironment.applyActivateOnLaunchIfEnabled`'s log message replaced em-dash (U+2014) with ASCII hyphen for log-stream-viewer consistency. The 3rd pass APPROVE'd (0 CRIT/HIGH/MED) — this single LOW was the only finding from a code-reviewer scan over S10.1 + S10.1.1. | 0 |
| 2 | `4895d35` | **V2-06 core (RED+GREEN)** — `DisplaySource` protocol + `NSScreenSource` adapter (NSScreen.screens filtered through `CGDisplayIsBuiltin`, observing `NSApplication.didChangeScreenParametersNotification`) + `MockDisplaySource` + `ExternalDisplayTrigger` itself. Vote semantics: count==0 → no vote (lastVote-nil suppression matches WiFi); count≥1 → `"Display: <localizedName ?? External Display>"` mirroring S10 friendly format; detach → `"Display: disconnected"`. **Single-consumer changeStream pattern**: `observeTask` installed once at the first `start()` and gated through start/stop cycles via `isRunning` flag — `source.changeStream` is single-pass, so cancelling the task would forfeit subsequent yields. New `LatteLog.display`. New `SettingsKey.externalDisplayEnabled` (default false). | +9 unit (1 over the spec ≥8 floor — `testRestartAfterStopReEmitsForCurrentSourceState` split out from the original combined test once the single-consumer gotcha forced the gate-flag refactor) |
| 3 | `9c6504c` | **V2-06 wire** — `AppEnvironment.registerDefaultTriggers` registers `ExternalDisplayTrigger` after `ScheduleTrigger` (now 5 default triggers; Focus still excluded pending V2-03b entitlement). `AppEnvironmentTests.testRegistersDefaultTriggers` (was `testRegistersFourDefaultTriggers`) updated to expect `external-display` in the set. **Coordinator integration tests (per spec §6)**: `testExternalDisplayVoteCombinesORWithOtherTrigger` (vote OR'd with another trigger; both votes coexist in `.awakeTriggered`; detach monitor while other vote ON keeps cup awake) + `testPauseAllIgnoresExternalDisplayVote` (C-9 parity). | +2 coordinator |
| 4 | `fd9df79` | **V2-06 Settings UI** — `TriggersTab.configBody` adds the `"external-display"` case routing to a new private `ExternalDisplayTriggerConfigForm`. Form has a one-paragraph caption (per spec §4 copy guidance) plus a live status row reading `trigger.externalDisplayCount` + `firstExternalDisplayName` on every body evaluation. count==0 → "Currently: no external display"; ≥1 → "Currently: N external display(s)" + optional "Display: <localizedName>". | 0 (UI is covered indirectly through the trigger / coordinator suites) |
| 5 | `5642bbc` | **V2-06 smoke (scenario 20)** — CI hosts have no external monitor, so the natural "no vote ON" branch is automated: seed `firstRunCompleted=true` + `externalDisplayTrigger.enabled=true` (no other trigger armed) → launch → `pmset -g assertions` must show NO Latte assertion → open Settings → Triggers, capture window for owner review → quit. The "vote ON when monitor attached" path stays covered by the unit suite + owner manual smoke (handoff step 7 below). | 0 (smoke-only) |

### 3rd simplify-pass findings (code-reviewer agent, 2026-04-30, scope = S10.1 + S10.1.1 commits)

Verdict: **APPROVE** (0 CRITICAL, 0 HIGH, 0 MEDIUM, 1 LOW).

- LOW: em-dash (U+2014) inside `LatteLog.awake.info` string can render as a multi-byte artifact in `log stream` consumers; replaced with ASCII hyphen in `5a7f42f`. The reviewer also noted (pre-existing, not in scope) that `AppEnvironmentTests` could be migrated to Swift Testing per the project's swift/testing rules, but that's a separate sweep.

### V2-06 implementation deltas vs the plan-only spec

The spec in `docs/design/06-display-trigger.md` was authored S10.1 with two paragraphs that didn't survive contact with implementation; both were corrected in the spec itself and documented in this handoff:

1. **§3 "no-replay on re-enable"** — original spec said: "Do NOT re-emit the vote on re-enable if the display is still attached — match the C-1/C-9 no-auto-replay policy from S9." That conflicts with how WiFi/App/Schedule triggers actually behave: their `start()` calls `evaluate()` and yields a fresh vote based on current source state, because users expect "I just turned this on, my monitor is plugged in, the cup should be active." C-1/C-9 no-auto-replay applies at the **manager input boundary** (auto-resume on AC re-plug or unpause), not at the per-trigger toggle level. ExternalDisplayTrigger now matches WiFi: re-enable yields ON if monitor attached. Spec §3 amended.
2. **§7 `LATTE_TEST_MOCK_DISPLAY_COUNT` env-var injection** — proposed adding a test-only branch in production code. Not implemented — production stays free of test-only branches; physical-attach simulation belongs in owner manual smoke, not in CI. Smoke 20 covers the no-monitor branch; spec §11 amended to record this decision.

The single-consumer `source.changeStream` gotcha is the more interesting find. `for await` can only consume an `AsyncStream` once for its entire lifetime. The naive pattern (cancel observeTask on stop, create new one on start) means the second `for await` returns nil immediately and the trigger never gets another evaluate. The `isRunning` gate flag pattern (one observeTask for the trigger's whole lifetime, gated by a flag inside the for-await body) preserves restart-after-stop semantics that Coordinator needs. Documented inline in `ExternalDisplayTrigger.swift`.

### Architectural invariants preserved

- **No state machine changes** across all 5 commits.
- **Persistence schema**: 1 new `SettingsKey` case (`externalDisplayEnabled`); `SettingsKeyEnumTests.testRequiredKeysExist` updated accordingly. No migration.
- **Trigger protocol unchanged**.
- **DI surface**: 1 new protocol (`DisplaySource`) following the §4.4.1 `*Source` pattern.
- **No-auto-replay policy** unchanged at manager input boundary.
- **`AwakeManager.shared`** untouched.

### Files changed (S11)

```
Sources/App/AppEnvironment.swift                   (5a7f42f: em-dash → ASCII; 9c6504c: register ExternalDisplay)
Sources/Core/Logging.swift                         (4895d35: + LatteLog.display)
Sources/Core/SettingsStore.swift                   (4895d35: + externalDisplayEnabled key)
Sources/Triggers/ExternalDisplayTrigger.swift      (4895d35: NEW — protocol + adapter + mock + trigger)
Sources/UI/Settings/TriggersTab.swift              (fd9df79: external-display dispatch + ConfigForm view)

Tests/AppEnvironmentTests.swift                    (9c6504c: registered triggers set updated)
Tests/ExternalDisplayTriggerTests.swift            (4895d35: NEW — 9 unit tests)
Tests/SettingsStoreTests.swift                     (4895d35: required keys list extended)
Tests/TriggerCoordinatorTests.swift                (9c6504c: + 2 V2-06 integration tests)

.smoke/scenarios/20-external-display.sh            (5642bbc: NEW — functional + capture)

docs/ROADMAP.md                                    (this wrap: + row 11a)
docs/v2-backlog.md                                 (this wrap: V2-06 → Shipped)
docs/design/02-architecture.md                     (this wrap: §4.4.1 trigger list)
docs/design/06-display-trigger.md                  (this wrap: status → Shipped, §3 + §11 amendments)
docs/SESSION_HANDOFF.md                            (this wrap)
```

---

## How to resume

```bash
cd ~/Documents/Claude/Projects/Latte
git log --oneline -8
# Expected top: latest "docs: SESSION_HANDOFF…" wrap commit for S11
# (commit chain in this file's "Last session" → "Commit chain" block).

# Pre-flight (always before Xcode Cmd-R OR xcodebuild test):
pkill -9 -f "Latte.app" 2>/dev/null
# `LSMultipleInstancesProhibited` blocks the test runner / a fresh build
# from launching when a stale Latte (from prior smoke / Cmd-R) is still
# alive. Killing first turns a confusing "Could not launch LatteTests"
# into a clean run.

# Verify Latte tests:
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 409 tests"
# Expected: Executed 409 tests, with 0 failures (~4.6 s)

# Verify smoke harness (~5 min, requires Release build of Latte at the
# DerivedData path encoded in `.smoke/config.yml`):
xcodebuild build -scheme Latte -configuration Release -destination 'platform=macOS,arch=arm64'
~/dev/smoke-harness/run.sh --project .
# Expected: all scenarios passed (20/20)

# IMPORTANT: run `xcodebuild test` and `~/dev/smoke-harness/run.sh` SERIALLY,
# never in parallel — both launch `com.parkbyeongjun.latte` and the test
# runner's failed launch (LSMultipleInstancesProhibited) propagates SIGKILL
# to the smoke scenario's Latte instance, surfacing as a phantom rc=137 fail
# (typically on `03-icon-states`). Verified S10 cold-start 2026-04-30.
```

---

## Owner-side smoke checklist (high priority — do before next code session)

7-step list (was 6 through S10.1.1; step 7 NEW for V2-06):

> **Pre-flight (always)** — `pkill -9 -f "Latte.app"` before Cmd-R. `LSMultipleInstancesProhibited` makes a stale background Latte block all subsequent launches with a confusing LaunchServices error.

1. **Build + launch** Latte from Xcode (Cmd-R) on a real macOS 13+ install.
2. **Pause-all toggle (C-9)** — open the menu-bar popover. New row at top under HeaderView: "Pause triggers" / "Triggers paused" with sub-text. Toggle it; the cup should stay live for manual activation but trigger votes should be ignored.
3. **Battery-aware (C-1)** — Settings → General → Behavior. Toggle "Sleep when on battery". On a laptop, unplug the AC adapter while awake; expect cup to drop to asleep within ~1 s. Re-plug; cup stays asleep (explicit non-feature: no auto-resume). Caption "Currently on battery — Latte is not holding awake." should appear under the toggle while unplugged.
4. **About status card (A-1)** — Settings → About. Below the hero card, a status card now shows State / Mode / Reason / Power. Verify Mode flips between "System + display awake" and "System awake (display may sleep)" when toggling Settings → General → "Allow display to sleep". **Reason row should now read "App: Finder" / "App: Zoom" instead of bundle ids** (S10 c6c6408 fix). **Power row** is hidden by design when "Sleep when on battery" is OFF.
5. **Schedule trigger (V2-05)** — Settings → Triggers → Schedule. Enable, add an entry covering "now"; cup should activate. Cross-midnight entries (e.g. 23:00–01:00) auto-render a caption "Crosses midnight…". Settings window is resizable (S10 66e8628) — drag any corner to grow; the Form auto-scrolls so all five trigger sections fit without manual scroll.
6. **Keyboard shortcut (B1)** — Settings → General → "Toggle Latte with ⌘⇧L". Default OFF. Toggle ON, close Settings, then anywhere on the Mac press ⌘⇧L: Latte should toggle awake/asleep. Custom recorder is v1.2 (B1.2).
7. **External display trigger (V2-06, NEW)** — Settings → Triggers → External Display. Default OFF. Toggle ON; status row should read "Currently: no external display" (assuming you're on a laptop with no monitor attached). Plug in an external monitor; within ~1s the cup should activate, the status row should refresh to "Currently: 1 external display / Display: <your monitor name>", and the menubar tooltip / About → Reason should read "Display: <name>". Unplug; cup deactivates immediately (grace=0 default). Toggle OFF mid-attach; cup deactivates immediately (Toggle OFF is grace=0 user-explicit). Re-toggle ON with monitor still attached; cup re-activates immediately (matches WiFi/App restart pattern, not the spec's earlier "wait for next event" idea — that was rejected during S11).

If any of these surfaces are awkward, file as P1 follow-up before piling on more v1.x features.

### Pre-emptive code-review observations (cumulative; resolved items struck through)

- ~~**A-1 reason field shows raw bundle id**~~ — **resolved S10 c6c6408**.
- ~~**Settings window not resizable**~~ — **resolved S10 66e8628**.
- ~~**`SettingsKey.activateOnLaunch` declared but never read**~~ — **resolved S10 a2c74a3**.
- ~~**V2-06 external-display trigger plan-only**~~ — **shipped S11 (4 commits)**.
- **A-1 Power row conditional rendering** — verified the `nil`-suppression is intentional. Owner should confirm during step 4.
- **Smoke harness coverage** — **20 scenarios**. Run via `~/dev/smoke-harness/run.sh --project ~/Documents/Claude/Projects/Latte` (~5 min, 20/20 expected).

---

## Next session entry points (in priority order)

1. **Owner smoke results** — the 7-step list above. P1 from there comes first. Step 7 is the new V2-06 verification.
2. **Owner-side blocked actions** (still): S8d ~5 min capture + Pages deploy; S8.5 Apple Developer Program enrollment ($99/yr, 1–2 day review).
3. **v1.x candidates** (still need owner pick + scope confirmation):
   - **C-7 Quick presets** — full A/B/C/D path comparison in [docs/design/08-c7-quick-presets-paths.md](docs/design/08-c7-quick-presets-paths.md). Owner picks on a single screen.
   - **C-3 Activity history** — Charts framework + new Settings tab. Higher risk while owner-side S8d/S8.5 still pending.
4. **B1.2 custom keyboard-shortcut recorder** — full spec in [docs/design/07-shortcut-recorder.md](docs/design/07-shortcut-recorder.md). ~5h impl, 12 unit tests, smoke 21 outline. RED-GREEN ready, can start anytime owner doesn't object.
5. **Smoke harness AX permission** — granting the runner Accessibility privilege would unlock AppleScript-driven window resize and let scenarios 18 / 20 capture full-page Triggers tab in one shot. Pure infra; affects no app code.
6. **V2-06 deferred refinements** (now that v1.2 baseline ships):
   - **Clamshell-aware** — lid-closed-while-external-display-present is the single most awake-relevant case. Querying lid state needs `IOPMrootDomain` or `NSScreen.main` heuristics. v1.3+ if telemetry warrants.
   - **Per-display whitelist** — "only this monitor at home" UX. Picker + UUID via `CGDisplayCreateUUIDFromDisplayID`. Defer until usage signals demand.

> **Activate-at-launch follow-up note** (carried from S10): the published `activeReason` is overridden post-FSM when callers pass a non-`.user` reason. If a future change adds more `.launch`-style reasons (e.g. `.system`, `.shortcut`), prefer plumbing the reason through `AwakeInput.userActivate` directly (8 Sources sites + 7 Tests sites). Documented in `Sources/Core/AwakeManager.swift:activate(for:reason:)` inline comment.

---

## Decisions still pending owner approval

- **C-7 scope** — pick path A / B / C / D from [docs/design/08-c7-quick-presets-paths.md](docs/design/08-c7-quick-presets-paths.md). The doc has a single-screen recommendation matrix; pick the row that matches your sprint priorities and write the answer here as a one-line note.
- Whether to keep going on v1.x features in parallel with owner-side S8d, or pause new feature work until S8d/S8.5 unblocks.

---

## Known issues / debt

- AboutTab status card layout has not been visually reviewed (see owner smoke step 4).
- C-1 IOKit code path (`IOPowerSource`) has no real-system test coverage — adapter classes are exempt from the 80% gate per S7 policy. `MockPowerSource` exercises the protocol contract.
- B1 Carbon hotkey path (`CarbonHotKeyRegistrar`) has no real-system test coverage — same adapter exemption. `MockHotKeyRegistrar` exercises the protocol contract. Real Carbon registration only verified manually at owner smoke step 6.
- B1 hardcoded chord — ⌘⇧L cannot be customised in v1.1. v1.2 (B1.2) adds the recorder.
- V2-06 `NSScreenSource` path has no real-system test coverage — adapter exemption applies. `MockDisplaySource` exercises the protocol contract; real attach/detach verified at owner smoke step 7.
- `MockPowerSource` / `MockHotKeyRegistrar` / `MockDisplaySource` ship in the production module so DI works at app start. Acceptable; no symbol leak per Swift module boundaries.
- Smoke harness lacks Accessibility permission, so AppleScript-driven window resize from scenarios 18 / 20 is not yet possible. Owner-side runner permission grant unblocks both.

---

## Recap stats (S11 end)

| | S8c end | S9d end | S10 end | S10.1.1 end | **S11 end** | Δ (S11) |
|---|---|---|---|---|---|---|
| Tests | 309 | 388 | 398 | 398 | **409** | +11 (9 unit + 2 coordinator) |
| Smoke scenarios | 14 | 18 | 19 | 19 | **20** | +1 |
| Default triggers | 3 | 4 | 4 | 4 | **5** | +1 (ExternalDisplay) |
| AwakeManager `@Published` settings | 1 | 3 | 3 | 3 | **3** | 0 |
| AppEnvironment `@Published` settings | 2 | 2 | 3 | 3 | **3** | 0 |
| Settings keys total | 22 | 27 | 27 | 27 | **28** | +1 (`externalDisplayEnabled`) |
| `*Source` DI protocols | 4 | 5 | 5 | 5 | **6** | +1 (`DisplaySource`) |
| Plan-only specs in `docs/design/` | 5 | 5 | 5 | 8 | **8** (06 → Shipped, 07/08 still plan-only) | 0 (06 status flip only) |
| ROADMAP rows | through 9d | through 9d | through 9e | through 9f | **through 11a** | +1 |
