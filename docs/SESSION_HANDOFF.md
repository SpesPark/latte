# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S11 → S12** — same-day double feature ship: V2-06 ExternalDisplayTrigger end-to-end (S11) + B1.2 custom-shortcut recorder end-to-end (S12), bracketed by a 3rd and 4th simplify-pass cleanup. 2026-04-30 (continuation of the S10 / S10.1 / S10.1.1 chain). |
| **Theme** | Owner approved successive 1순위 plans during the session. (1) **3rd simplify-pass** on S10.1+S10.1.1 → APPROVE + 1 LOW (em-dash → ASCII). (2) **V2-06 ExternalDisplayTrigger** as designed in `docs/design/06-display-trigger.md` — 4-commit sequence (Core / wire / UI / smoke). (3) **4th simplify-pass** on S11's 5 commits → APPROVE-WITH-NITS (1 MED + 2 LOW). (4) **02-architecture §4.4.2 codification** of the single-consumer AsyncStream gotcha + isRunning gate pattern surfaced during V2-06. (5) **B1.2 custom-shortcut recorder** as designed in `docs/design/07-shortcut-recorder.md` — 3-commit sequence (Core / UI / smoke+docs). v1.2 baseline now ships both V2-06 + B1.2 with no owner-side decisions blocking. |
| **Status** | ✅ **11 commits** across the session. **398 → 423 tests** (+25: 9 V2-06 unit + 2 V2-06 coordinator + 7 KeyChord + 7 coordinator chord-management). **19 → 21 smoke scenarios** (full batch passes, ~5 min). Working tree clean. Test run ~6.0 s, smoke ~5 min. |
| **Tail commit** | resolves to the head of the S11+S12 chain when read — typically the latest `docs: SESSION_HANDOFF…` commit. Run `git log --oneline -12` to see this session in full. |

### Commit chain (this session — top is HEAD)

```
<wrap commit>  docs: SESSION_HANDOFF wrap for S11+S12 (V2-06 + B1.2 shipped)
063cdad  smoke+docs: scenario 21 + 07-spec Shipped + ROADMAP 11b + v2-backlog (B1.2 #3)
d7e4a97  feat: ShortcutRecorderField NSViewRepresentable + GeneralTab row (B1.2 #2 UI)
f3d1b24  feat: KeyChord + parameterised HotKeyRegistrar (B1.2 #1 Core RED+GREEN)
43cf9c9  docs: 02-arch §4.4.2 single-consumer AsyncStream gotcha + isRunning gate
7a4ecf0  chore: 4th simplify-pass follow-through (S11)
e9999b9  docs: SESSION_HANDOFF wrap for S11 (V2-06 shipped + 3rd simplify-pass)
5642bbc  smoke: scenario 20 external-display (V2-06 #4)
fd9df79  feat: TriggersTab External Display section (V2-06 #3 UI)
9c6504c  feat: register ExternalDisplayTrigger + 2 coordinator tests (V2-06 #2 wire)
4895d35  feat: ExternalDisplayTrigger core (V2-06 #1 RED+GREEN)
5a7f42f  chore: ASCII hyphen in activate-at-launch log (3rd simplify-pass LOW)
```

### What landed (S11 — V2-06 ExternalDisplayTrigger)

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `5a7f42f` | **3rd simplify-pass LOW fix** — em-dash (U+2014) in `LatteLog.awake.info` → ASCII hyphen for log-stream consumer compatibility. The 3rd pass APPROVE'd (0 CRIT/HIGH/MED). | 0 |
| 2 | `4895d35` | **V2-06 core** — `DisplaySource` protocol + `NSScreenSource` adapter + `MockDisplaySource` + `ExternalDisplayTrigger`. **Single-consumer changeStream gotcha** resolved with `isRunning` gate flag (observe task lives once for the trigger's lifetime, gated by a flag). New `LatteLog.display`, new `SettingsKey.externalDisplayEnabled`. | +9 unit |
| 3 | `9c6504c` | **V2-06 wire** — `AppEnvironment.registerDefaultTriggers` registers ExternalDisplay (5th default trigger). 2 coordinator integration tests (vote OR with another trigger; pause-all C-9 parity). | +2 coordinator |
| 4 | `fd9df79` | **V2-06 UI** — TriggersTab gains `external-display` dispatch + `ExternalDisplayTriggerConfigForm` with live count + name status row. | 0 |
| 5 | `5642bbc` | **V2-06 smoke** — scenario 20 covers the no-monitor branch (CI hosts have no external monitor → `pmset` shows no Latte assertion + Settings capture). | 0 |
| — | `e9999b9` | S11 wrap — ROADMAP row 11a, 02-architecture §4.4.1 trigger list extended, 06-spec status → Shipped + §3 / §11 amended (no-replay/env-var hack rejected during impl). | 0 |

### What landed (S12 — B1.2 custom-shortcut recorder)

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 6 | `7a4ecf0` | **4th simplify-pass follow-through** — APPROVE-WITH-NITS verdict. MED resolved (`DisplaySource.changeStream` doc said "coalesces bursts" but adapter forwards raw — comment rewritten). LOW-A resolved (test was creating a 2nd iterator on a single-consumer AsyncStream — switched to reusing existing iterator). LOW-B (`TriggersTab.swift` >800 line ceiling, pre-existing) tracked as new V2-13 backlog. NSScreenSource debounce future-polish recorded under V2-06 entry. | 0 |
| 7 | `43cf9c9` | **02-arch §4.4.2 single-consumer AsyncStream gotcha** — codifies the lesson learned during V2-06 implementation. Two correct shapes documented: (A) `*Source` exposes AsyncStream → install observe task once + `isRunning` gate (`ExternalDisplayTrigger`); (B) `*Source` exposes per-call query / callback → trigger owns its own poll task (`WiFiTrigger`/`AppTrigger`/`CalendarTrigger`/`ScheduleTrigger`). | 0 (docs-only) |
| 8 | `f3d1b24` | **B1.2 core** — `KeyChord` Codable+Hashable+Sendable value type + `ReservedChord` system blocklist (⌘Q/W/C/V/X/Tab/Space) + `SettingsStore` `keyChord` round-trip. `HotKeyRegistrar` protocol gains `register(chord:handler:)` + `currentChord`; legacy `register(handler:)` kept as default-impl shim for backwards compat. `KeyboardShortcutCoordinator.@Published chord` + `setChord` / `resetChord`. `SettingsKey.shortcutChord` (silent-default migration: nil/garbage → `.default`). | +14 (7 KeyChord + 7 coordinator) |
| 9 | `d7e4a97` | **B1.2 UI** — `ShortcutRecorderField` SwiftUI wrapper around an `NSResponder`-based `NSView` (Spotlight-picker pattern; pure SwiftUI key capture isn't reliable on macOS 13). Inline FSM (idle / recording) + reserved-chord + missing-modifier validation. GeneralTab gains "Shortcut" `LabeledContent` row + Reset button (disabled while on default). Toggle label switched from compile-time `chordGlyph` to live `coordinator.chord.glyph`. | 0 |
| 10 | `063cdad` | **B1.2 smoke + docs** — scenario 21 covers silent-default migration (`defaults read … shortcutChord` exits non-zero) + Settings capture for owner review. ROADMAP row 11b NEW. v2-backlog B1.2 entry → Shipped paragraph. 07-spec status → 1.0 / Shipped + §10 implementation order rewritten "as shipped in S12". | 0 |

### Reviewer findings — cumulative across the session

- **3rd simplify-pass** (scope = S10.1 + S10.1.1, run 2026-04-30): **0 CRITICAL, 0 HIGH, 0 MEDIUM, 1 LOW** — em-dash → ASCII hyphen. Resolved in `5a7f42f`.
- **4th simplify-pass** (scope = S11's 5 commits, run 2026-04-30): **0 CRITICAL, 0 HIGH, 1 MEDIUM, 2 LOW** — MED + LOW-A resolved in `7a4ecf0`; LOW-B (pre-existing TriggersTab line ceiling) tracked as V2-13 backlog; future polish on NSScreenSource debounce noted under V2-06 entry.

### Architectural invariants preserved (across S11 + S12)

- **No state-machine changes** across all 11 commits.
- **Persistence schema**: 2 new `SettingsKey` cases (`externalDisplayEnabled`, `shortcutChord`); `SettingsKeyEnumTests.testRequiredKeysExist` updated. No migration banner — silent-default fallback for both keys.
- **Trigger protocol unchanged** — V2-06 follows §4.4.1 `*Source` DI pattern; V2-06 added §4.4.2 documenting the AsyncStream observe-pattern.
- **HotKeyRegistrar protocol extended** with one required method + one new property; legacy `register(handler:)` kept as default-impl shim so existing callers compile unchanged.
- **No-auto-replay policy** unchanged at manager input boundary; V2-06 re-enable matches WiFi/AppTrigger restart pattern (start() always evaluates fresh source state) — spec §3 amended in-line during S11.
- **`AwakeManager.shared`** untouched.

### Files changed (S11 + S12 combined)

```
Sources/App/AppEnvironment.swift                   (5a7f42f / 9c6504c)
Sources/Core/KeyChord.swift                        (f3d1b24: NEW — value type + ReservedChord)
Sources/Core/KeyboardShortcutCoordinator.swift     (f3d1b24: chord + setChord/resetChord, parameterised registrar)
Sources/Core/Logging.swift                         (4895d35: + LatteLog.display)
Sources/Core/SettingsStore.swift                   (4895d35 / f3d1b24: + 2 keys + keyChord round-trip)
Sources/Triggers/ExternalDisplayTrigger.swift      (4895d35: NEW — protocol + adapter + mock + trigger; 7a4ecf0: doc fix)
Sources/UI/Settings/GeneralTab.swift               (d7e4a97: live glyph + recorder row)
Sources/UI/Settings/ShortcutRecorderField.swift    (d7e4a97: NEW — NSViewRepresentable recorder)
Sources/UI/Settings/TriggersTab.swift              (fd9df79: external-display config form)

Tests/AppEnvironmentTests.swift                    (9c6504c: registered triggers set)
Tests/ExternalDisplayTriggerTests.swift            (4895d35: NEW; 7a4ecf0: probe iterator fix)
Tests/KeyChordTests.swift                          (f3d1b24: NEW — 7 unit tests)
Tests/KeyboardShortcutCoordinatorTests.swift       (f3d1b24: + 7 chord-management tests + Mock extensions)
Tests/SettingsStoreTests.swift                     (4895d35 / f3d1b24: required keys list)
Tests/TriggerCoordinatorTests.swift                (9c6504c: + 2 V2-06 integration tests)

.smoke/scenarios/20-external-display.sh            (5642bbc: NEW)
.smoke/scenarios/21-shortcut-recorder.sh           (063cdad: NEW)

ROADMAP.md                                         (e9999b9 / 063cdad: rows 11a + 11b)
docs/design/02-architecture.md                     (e9999b9 / 43cf9c9: §4.4.1 + §4.4.2)
docs/design/06-display-trigger.md                  (e9999b9: status → Shipped, §3 + §11 amend)
docs/design/07-shortcut-recorder.md                (063cdad: status → Shipped, §10 amend)
docs/v2-backlog.md                                 (e9999b9 / 7a4ecf0 / 063cdad: V2-06 + V2-13 + B1.2)
docs/SESSION_HANDOFF.md                            (e9999b9 + this wrap)
```

---

## How to resume

```bash
cd ~/Documents/Claude/Projects/Latte
git log --oneline -12
# Expected top: latest "docs: SESSION_HANDOFF…" wrap commit for S11+S12
# (commit chain in this file's "Last session" → "Commit chain" block).

# Pre-flight (always before Xcode Cmd-R OR xcodebuild test):
pkill -9 -f "Latte.app" 2>/dev/null
# `LSMultipleInstancesProhibited` blocks the test runner / a fresh build
# from launching when a stale Latte (from prior smoke / Cmd-R) is still
# alive. Killing first turns a confusing "Could not launch LatteTests"
# into a clean run.

# Verify Latte tests:
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 423 tests"
# Expected: Executed 423 tests, with 0 failures (~6.0 s)

# Verify smoke harness (~5 min, requires Release build of Latte at the
# DerivedData path encoded in `.smoke/config.yml`):
xcodebuild build -scheme Latte -configuration Release -destination 'platform=macOS,arch=arm64'
~/dev/smoke-harness/run.sh --project .
# Expected: all scenarios passed (21/21)

# IMPORTANT: run `xcodebuild test` and `~/dev/smoke-harness/run.sh` SERIALLY,
# never in parallel — both launch `com.parkbyeongjun.latte` and the test
# runner's failed launch (LSMultipleInstancesProhibited) propagates SIGKILL
# to the smoke scenario's Latte instance, surfacing as a phantom rc=137 fail
# (typically on `03-icon-states`). Verified S10/S11 cold-start 2026-04-30.
```

---

## Owner-side smoke checklist (high priority — do before next code session)

7-step list. Step 6 (NEW) reflects the B1.2 recorder; step 7 covers V2-06.

> **Pre-flight (always)** — `pkill -9 -f "Latte.app"` before Cmd-R. `LSMultipleInstancesProhibited` makes a stale background Latte block all subsequent launches with a confusing LaunchServices error.

1. **Build + launch** Latte from Xcode (Cmd-R) on a real macOS 13+ install.
2. **Pause-all toggle (C-9)** — open the menu-bar popover. Top row "Pause triggers" / "Triggers paused" with sub-text. Toggle it; the cup should stay live for manual activation but trigger votes should be ignored.
3. **Battery-aware (C-1)** — Settings → General → Behavior. Toggle "Sleep when on battery". On a laptop, unplug; expect cup to drop within ~1 s. Re-plug; cup stays asleep (explicit non-feature: no auto-resume). Caption "Currently on battery — Latte is not holding awake." should appear under the toggle while unplugged.
4. **About status card (A-1)** — Settings → About. State / Mode / Reason / Power card. Reason should read "App: Finder" / "App: Zoom" instead of bundle ids (S10 c6c6408 fix). Power row hidden by design when "Sleep when on battery" is OFF.
5. **Schedule trigger (V2-05)** — Settings → Triggers → Schedule. Enable, add entry covering "now"; cup should activate. Cross-midnight entries (23:00–01:00) auto-render "Crosses midnight…" caption. Settings is resizable (S10 66e8628) — drag a corner; Form auto-scrolls.
6. **Keyboard shortcut + recorder (B1 / B1.2)** — Settings → General. Toggle "Toggle Latte with ⌘⇧L" ON. Default OFF. Press ⌘⇧L from anywhere; Latte should toggle. **NEW (S12 d7e4a97):** below the toggle is a "Shortcut" recorder row — click the field, press ⌘⌥K (any chord with at least one of ⌘ ⌃ ⌥). Field should show `⌘⌥K`; toggle's label should refresh from "Toggle Latte with ⌘⇧L" → "Toggle Latte with ⌘⌥K"; press ⌘⌥K from anywhere to verify it fires; quit Latte, reopen — chord should persist; click "Reset" → field reverts to `⌘⇧L`. Reserved chords (⌘Q / ⌘W / ⌘V / ⌘Tab / ⌘Space etc.) should show inline red error and refuse to commit. Bare ⇧L (no required modifier) should show "Add ⌘ ⌃ or ⌥" error.
7. **External display trigger (V2-06)** — Settings → Triggers → External Display. Default OFF. Toggle ON; status row should read "Currently: no external display" (laptop with no monitor). Plug in monitor; within ~1 s the cup activates, status row refreshes to "Currently: 1 external display / Display: <monitor name>", About → Reason should read "Display: <name>". Unplug; cup deactivates immediately. Toggle OFF mid-attach → cup deactivates immediately. Re-toggle ON with monitor still attached → cup re-activates immediately (matches WiFi/App restart pattern).

If any of these surfaces are awkward, file as P1 follow-up before piling on more v1.x features.

### Pre-emptive code-review observations (cumulative; resolved items struck through)

- ~~**A-1 reason field shows raw bundle id**~~ — **resolved S10 c6c6408**.
- ~~**Settings window not resizable**~~ — **resolved S10 66e8628**.
- ~~**`SettingsKey.activateOnLaunch` declared but never read**~~ — **resolved S10 a2c74a3**.
- ~~**V2-06 external-display trigger plan-only**~~ — **shipped S11**.
- ~~**B1.2 custom-chord recorder plan-only**~~ — **shipped S12**.
- **TriggersTab.swift > 800 lines** — pre-existing, tracked as V2-13 in backlog. Mechanical extraction (~45 min); no behaviour change.
- **NSScreenSource debounce** — theoretical-only (lastVote guard already swallows same-state bursts); recorded as future polish under V2-06 backlog entry.
- **A-1 Power row conditional rendering** — `nil`-suppression intentional. Owner should confirm during step 4.
- **Smoke harness coverage** — **21 scenarios**. Run via `~/dev/smoke-harness/run.sh --project ~/Documents/Claude/Projects/Latte` (~5 min, 21/21 expected).

---

## Next session entry points (in priority order)

1. **Owner smoke results** — the 7-step list above. P1 from there comes first. Steps 6 + 7 are new.
2. **Owner-side blocked actions** (still): S8d ~5 min capture + Pages deploy; S8.5 Apple Developer Program enrollment ($99/yr, 1–2 day review).
3. **v1.x candidates** (still need owner pick + scope confirmation):
   - **C-7 Quick presets** — full A/B/C/D path comparison in [docs/design/08-c7-quick-presets-paths.md](docs/design/08-c7-quick-presets-paths.md). Owner picks on a single screen.
   - **C-3 Activity history** — Charts framework + new Settings tab. Higher risk while owner-side S8d/S8.5 still pending.
4. **5th simplify-pass** (S12's 3 code commits) — pattern dictates one more code-reviewer agent run; estimate ~20 min, expected APPROVE.
5. **V2-13 TriggersTab extraction** (P2 hygiene) — split each per-trigger config form out of `TriggersTab.swift` (now 958 lines, breaches the 800 ceiling). ~45 min mechanical; no behaviour change. Worth doing before the next trigger lands.
6. **B1.2 deferred refinements** (now that v1.2 baseline ships):
   - **Per-action chords** — Pause-all, snooze, etc. could each get a recorder. Defer until usage signals demand.
   - **Visual indicator that current chord is reserved by another app** — macOS doesn't enumerate other apps' Carbon registrations; we'd ship false negatives. Continue to surface the OS-level rejection at register time only.
7. **V2-06 deferred refinements** (carried from S11):
   - **Clamshell-aware** lid-close detection (`IOPMrootDomain`/`NSScreen.main` heuristics). v1.3+.
   - **Per-display whitelist** picker via `CGDisplayCreateUUIDFromDisplayID`. v1.3+.
   - **NSScreenSource debounce** (100 ms coalesce) — theoretical only; revisit if telemetry surfaces flicker.
8. **Smoke harness AX permission** — granting the runner Accessibility privilege would unlock AppleScript-driven window resize and let scenarios 18 / 20 / 21 capture full-page Settings tabs. Pure infra; affects no app code.

> **Activate-at-launch follow-up note** (carried from S10): the published `activeReason` is overridden post-FSM when callers pass a non-`.user` reason. If a future change adds more `.launch`-style reasons (e.g. `.system`, `.shortcut`), prefer plumbing the reason through `AwakeInput.userActivate` directly (8 Sources sites + 7 Tests sites). Documented in `Sources/Core/AwakeManager.swift:activate(for:reason:)` inline comment.

---

## Decisions still pending owner approval

- **C-7 scope** — pick path A / B / C / D from [docs/design/08-c7-quick-presets-paths.md](docs/design/08-c7-quick-presets-paths.md).
- Whether to keep going on v1.x features in parallel with owner-side S8d, or pause new feature work until S8d/S8.5 unblocks.

---

## Known issues / debt

- AboutTab status card layout has not been visually reviewed (see owner smoke step 4).
- C-1 IOKit code path (`IOPowerSource`) has no real-system test coverage — adapter exemption per S7 policy. `MockPowerSource` exercises the protocol contract.
- B1 / B1.2 Carbon hotkey path (`CarbonHotKeyRegistrar`) has no real-system test coverage — same adapter exemption. `MockHotKeyRegistrar` exercises the protocol contract; real Carbon registration verified manually at owner smoke step 6.
- B1.2 `ShortcutRecorderField` NSViewRepresentable has no real-system test coverage — keyDown injection needs Accessibility privilege the harness doesn't have. Smoke 21 covers the silent-default migration + Settings capture; recorder interaction is owner manual smoke step 6.
- V2-06 `NSScreenSource` path has no real-system test coverage — adapter exemption; `MockDisplaySource` exercises the protocol. Real attach/detach verified at owner smoke step 7.
- `MockPowerSource` / `MockHotKeyRegistrar` / `MockDisplaySource` ship in the production module so DI works at app start. Acceptable; no symbol leak per Swift module boundaries.
- Smoke harness lacks Accessibility permission, so AppleScript-driven window resize + keyDown injection is not yet possible. Owner-side runner permission grant unblocks scenarios 18 / 20 / 21 fullpage capture and the recorder interaction loop.
- `TriggersTab.swift` 958 lines (>800 ceiling) — pre-existing, tracked as V2-13. Mechanical extraction.

---

## Recap stats (S12 end)

| | S8c end | S9d end | S10 end | S10.1.1 end | S11 end | **S12 end** | Δ (S11+S12) |
|---|---|---|---|---|---|---|---|
| Tests | 309 | 388 | 398 | 398 | 409 | **423** | +25 (S11: +11; S12: +14) |
| Smoke scenarios | 14 | 18 | 19 | 19 | 20 | **21** | +2 |
| Default triggers | 3 | 4 | 4 | 4 | 5 | **5** | +1 (ExternalDisplay) |
| AwakeManager `@Published` settings | 1 | 3 | 3 | 3 | 3 | **3** | 0 |
| AppEnvironment `@Published` settings | 2 | 2 | 3 | 3 | 3 | **3** | 0 |
| KeyboardShortcutCoordinator `@Published` settings | 1 | 1 | 1 | 1 | 1 | **2** | +1 (chord) |
| Settings keys total | 22 | 27 | 27 | 27 | 28 | **29** | +2 (`externalDisplayEnabled`, `shortcutChord`) |
| `*Source` DI protocols | 4 | 5 | 5 | 5 | 6 | **6** | +1 (`DisplaySource`) |
| `HotKeyRegistrar` protocol API | n/a | 3 | 3 | 3 | 3 | **5** | +2 (`register(chord:handler:)`, `currentChord`) |
| Plan-only specs in `docs/design/` | 5 | 5 | 5 | 8 | 8 | **8** (06+07 → Shipped, 08 still plan-only) | 0 status flips only |
| ROADMAP rows | through 9d | through 9d | through 9e | through 9f | through 11a | **through 11b** | +1 |
| Simplify-passes run | 0 | 1 | 2 | 2 | 3 | **4** | +2 (3rd APPROVE / 4th APPROVE-WITH-NITS) |
