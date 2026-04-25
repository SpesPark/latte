# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 3 of ~10 |
| **Theme** | Phase 1.0 implementation — `Sources/` rewrite + tests |
| **Date** | 2026-04-25 |
| **Status** | ✅ Completed as planned. Code matches architecture; FSM is cell-by-cell faithful to 03 §7. |

### What was accomplished

1. **Pre-rewrite housekeeping (Step A)**
   - `project.yml` target renamed `Caffeinated → Latte`. Bundle ID `com.example.caffeinated → com.example.latte`. Tests target `LatteTests`.
   - `Configuration/Caffeinated.entitlements` → `Configuration/Latte.entitlements` (`git mv`).
   - `Resources/Info.plist`: `CFBundleDisplayName` and calendar-usage strings updated to "Latte".
   - All ten skeleton files in `Sources/` and the skeleton `Tests/AwakeManagerTests.swift` deleted.
   - Folder layout per [02-architecture.md §3.1](design/02-architecture.md) created (`App/`, `Core/`, `Triggers/`, `Intents/`, `UI/MenuBar`, `UI/Settings`, `UI/Components`, `UI/Theme`).
   - **Filesystem rename of repo root `Caffeinated-Clone/` → `Latte/` deferred** to before-first-push (cosmetic; would invalidate the active session's CWD mid-flight). Tracked under "Known issues / debt" below.

2. **`Sources/Core/` (Step B)** — pure-logic, SwiftUI-free per [02 §3.2](design/02-architecture.md)
   - [`AwakeDuration.swift`](../Sources/Core/AwakeDuration.swift): `.minutes/.hours/.indefinite`, presets matching PRD F-1.0.04 (5m/15m/30m/1h/2h/5h/indefinite).
   - [`PowerAssertion.swift`](../Sources/Core/PowerAssertion.swift): `PowerAssertionType` protocol + real `PowerAssertion` (IOKit) + `MockPowerAssertion` (records calls).
   - [`SettingsStore.swift`](../Sources/Core/SettingsStore.swift): `SettingsStore` protocol + complete `SettingsKey` enum from [04 §5](design/04-data-model.md) (21 keys, all `latte.` prefixed) + `UserDefaultsSettingsStore` + `InMemorySettingsStore` + JSON-array helpers + clamped-int validation.
   - [`Logging.swift`](../Sources/Core/Logging.swift): `LatteLog.{awake,triggers,calendar,app,wifi,focus,intents,ui}` factories on `os.Logger`.
   - [`AwakeManager.swift`](../Sources/Core/AwakeManager.swift): the FSM. **Pure `AwakeStateMachine.step(state:pendingVotes:input:now:)` step function** with no I/O, returning `(state, pendingVotes, [SideEffect], reason)`. `AwakeManager` (@MainActor) holds state, applies side effects, owns timers as `Task` handles, exposes `@Published` properties, public API (`toggle`, `activate(for:)`, `deactivate()`, `receiveTriggerVote`), `installSignalHandlers()` for SIGINT/SIGTERM/SIGABRT cleanup. **Implements every cell of the 03 §7 transition table verbatim.**

3. **`Sources/Triggers/` (Step C)** — protocol + 4 stubs + coordinator
   - [`Trigger.swift`](../Sources/Triggers/Trigger.swift): `Trigger` protocol per [02 §4.4](design/02-architecture.md), `TriggerPermissionStatus` enum, `MockTrigger` for tests with `emit(_:)`.
   - [`TriggerCoordinator.swift`](../Sources/Triggers/TriggerCoordinator.swift): registry, vote-stream consumer, forwards votes to `AwakeManager`, tracks `activeVotes`.
   - Stubs: [`CalendarTrigger.swift`](../Sources/Triggers/CalendarTrigger.swift), [`AppTrigger.swift`](../Sources/Triggers/AppTrigger.swift), [`WiFiTrigger.swift`](../Sources/Triggers/WiFiTrigger.swift), [`FocusTrigger.swift`](../Sources/Triggers/FocusTrigger.swift) — each conforms to `Trigger`, reads its enable-flag from `SettingsStore`, has empty `voteStream`. Real EventKit/NSWorkspace/CoreWLAN/AppIntents wiring is **session 4's** scope.
   - Typed `SettingsStore` extensions per [04 §5.1](design/04-data-model.md): `calendarTriggerCalendarIDs/ExcludeAllDay/LeadTimeMinutes/TrailingMinutes`, `appTriggerBundleIDs` (with curated defaults + bundle-ID regex sanitizer per 04 §4.3.1–4.3.2), `wifiTriggerSSIDs/InverseLogic` (with 1–32 byte SSID validation), `focusTriggerFocusIDs`.

4. **`Sources/Intents/` (Step D)** — [`AwakeIntents.swift`](../Sources/Intents/AwakeIntents.swift): `ToggleAwakeIntent`, `StartAwakeIntent(minutes:)`, `StopAwakeIntent`, `LatteShortcuts: AppShortcutsProvider` registers all three with phrases — matches PRD F-1.0.11.

5. **`Sources/UI/` (Step E)** — split per [02 §3.1](design/02-architecture.md)
   - `Theme/Theme.swift` — colors / spacing / radius / fonts / sizes constants.
   - `Components/CoffeeCupView.swift` — minimal placeholder; real animation = session 5.
   - `Components/LiquidGlassModifier.swift` — `#available(macOS 26, *)` regularMaterial branch + ultraThinMaterial fallback.
   - `MenuBar/{MenuBarRoot,HeaderView,DurationPickerRow}.swift` — split into 3 files as required.
   - `Settings/{SettingsRoot,GeneralTab,TriggersTab,AboutTab}.swift` — TabView shell + per-tab forms.

6. **`Sources/App/` (Step F)** — composition root
   - `AppEnvironment.swift` — wires `SettingsStore`, `AwakeManager`, `TriggerCoordinator`, registers all 4 trigger stubs.
   - `LatteApp.swift` — `@main`, `MenuBarExtra` + `Settings` scenes, calls `AwakeManager.installSignalHandlers()` in `init`.

7. **`Tests/` (Step G.1)** — 4 files, ~580 lines of test code
   - [`AwakeDurationTests.swift`](../Tests/AwakeDurationTests.swift) — preset shape, label, seconds, isFinite.
   - [`SettingsStoreTests.swift`](../Tests/SettingsStoreTests.swift) — parametrized `SettingsStoreContractTests` base class, run against both `InMemorySettingsStore` and `UserDefaultsSettingsStore` (temp suite); plus `SettingsKeyEnumTests` (every key is `latte.`-prefixed; full set matches 04 §5) and `AppTriggerDefaultsTests` (curated IDs + sanitizer regex).
   - [`AwakeManagerTests.swift`](../Tests/AwakeManagerTests.swift) — **one `@Test`-equivalent function per non-invariant cell of the 03 §7 transition table**, plus invariant-violation checks, plus integration tests covering all 6 worked examples in 03 §8 (`test81` through `test86`), plus public-API smoke and the any-OR aggregation rule from 03 §5.1.
   - [`TriggerCoordinatorTests.swift`](../Tests/TriggerCoordinatorTests.swift) — register / duplicate-rejection / start-enabled-only / vote forwarding / multi-trigger aggregation / stop cleans up.

8. **Doc updates (Step G.2)**
   - [`02-architecture.md`](design/02-architecture.md) §10 marked complete; version bumped 0.2 → 0.3 with change log entry.
   - [`01-PRD.md`](design/01-PRD.md) §13 change log: 0.2.1 traceability entry (no content changes).
   - [`ROADMAP.md`](../ROADMAP.md) — sessions 1–3 marked 🟢, session 4 marked 🟡 Next; version 0.3.

### What was *not* done (intentionally deferred)

- **Build verification** — Xcode is not installed locally; per the original plan, this is a session 6 prerequisite. Code is written to spec; first compile happens in session 6.
- **Real trigger wiring** — Calendar/App/Wi-Fi/Focus triggers are stubs whose `voteStream` is empty. EventKit / `NSWorkspace.didLaunchApplicationNotification` / `CWWiFiClient` / Focus AppIntents arrive in **session 4**.
- **UI polish** — `CoffeeCupView` is a placeholder; real Canvas/TimelineView animation, app icon, and Liquid Glass theming are **session 5**.
- **Filesystem rename of repo root** `Caffeinated-Clone/ → Latte/`. Owner can do this once before first external push; nothing in the codebase or `project.yml` references the parent folder name.

---

## Next session entry point

**Theme**: Phase 1.A — implement the four real triggers (session 4 of ~10)

**Goal**: After this session, all 4 triggers actually emit votes from real system signals; `TriggerCoordinator` orchestrates them; integration tests cover the cross-trigger paths.

### To-do (in order)

#### A. Calendar trigger (~45 min)

1. Replace `CalendarTrigger.start()` stub. Use `EKEventStore.requestFullAccessToEvents` (macOS 14+) with `requestAccess(to:)` fallback for macOS 13. Honor `permissionStatus`.
2. Poll for events every 60 s using `EKEventStore.events(matching:)` over `[now - leadTime, now + 24h]`.
3. For each event whose start ≤ `now + leadTimeMinutes` and end > `now - trailingMinutes`, emit a `wantsAwake = true` vote with `reason = "Calendar: \(event.title)"`. When the event ends + trailing window expires, emit `wantsAwake = false`.
4. Honor `calendarTriggerCalendarIDs` filter (empty = all granted) and `calendarTriggerExcludeAllDay`.
5. Tests: integration test with a fake `EKEventStore` adapter (extract a small `CalendarSource` protocol).

#### B. App-presence trigger (~30 min)

6. Use `NSWorkspace.shared.notificationCenter` for `didLaunchApplicationNotification` / `didTerminateApplicationNotification`. Snapshot `runningApplications` on `start()`.
7. When any app whose `bundleIdentifier ∈ appTriggerBundleIDs` is running, emit `wantsAwake = true`. When all such apps terminate, emit `false`.
8. Tests: simulate launch/terminate via injected workspace.

#### C. Wi-Fi trigger (~30 min)

9. Use `CWWiFiClient.shared().interface()?.ssid()` polled every 30 s (or on `interfaceModeDidChange` if available). Requires location permission — request via `CLLocationManager` lazy init.
10. Emit `wantsAwake = true` when current SSID ∈ `wifiTriggerSSIDs` (or, if `wifiTriggerInverseLogic`, when SSID ∉ list). Emit `false` otherwise.
11. Tests: integration test with mocked `WiFiSource`.

#### D. Focus trigger (~30 min)

12. Implement via `INFocusStatus` / `INFocusStatusCenter.default.requestAuthorization()`. Watch `INFocusStatusCenter.default.focusStatus`.
13. Emit `wantsAwake = true` when active focus ID ∈ `focusTriggerFocusIDs`.
14. Tests: mocked `FocusSource`.

#### E. Wrap (~15 min)

15. Update `LatteApp.swift` so triggers `start()` after permissions are confirmed.
16. Add an integration test crossing `MockTrigger` × real `AwakeManager` for the 03 §8 examples that previously used pure-mock votes.
17. Update [`02-architecture.md`](design/02-architecture.md) §10 (no remaining gaps); update [`ROADMAP.md`](../ROADMAP.md) and overwrite this file for session 5 entry.

### Cannot-start-without checks

- Xcode 15+ is **still not required** for session 4 — the goal remains correct-looking code. EventKit/NSWorkspace/CoreWLAN/Intents APIs are all type-checked from spec; build verification stays in session 6.
- Re-read [`03-state-machine.md` §5.1](design/03-state-machine.md) (any-OR aggregation) before wiring votes — every trigger emits independent votes; coordination policy is owned by `AwakeManager`.
- Read [`04-data-model.md` §4.2–4.5](design/04-data-model.md) before adding new keys — all schema must already exist there. **Do not invent new SettingsKey cases without bumping `schemaVersion` per 04 §6.2.**

---

## Decisions still pending owner approval

**None for session 4.** All design decisions needed for trigger work are in 02/03/04. Remaining open questions (OQ-07 ~ OQ-10) are content/marketing, unblocked separately for sessions 7–8.

---

## Known issues / debt

| Issue | Impact | Plan |
|---|---|---|
| Repo root folder still named `Caffeinated-Clone/` | Cosmetic only; nothing in code references it | Owner renames to `Latte/` before first external push |
| Bundle ID `com.example.latte` is placeholder | Cannot ship | Owner provides real reverse-domain before session 8 |
| Xcode (full) not installed locally | Cannot build/run | Owner installs before session 6 |
| No app icon yet | Cannot ship | Owner produces before session 8 |
| No Apple Developer Program enrollment | Cannot submit | Owner enrolls before session 8 |
| Stub triggers in session 3 are non-functional | No real auto-on yet | Real wiring is session 4's scope |
| `AwakeManager.installSignalHandlers()` uses `AwakeManager.shared` from a `@convention(c)` handler | Best-effort cleanup only; cannot fully synchronize on signal | Acceptable for menu-bar utility; revisit if app grows in scope |

---

## Files changed this session

```
A  Configuration/Latte.entitlements        (renamed from Caffeinated.entitlements)
M  Resources/Info.plist                    (CFBundleDisplayName + calendar copy → Latte)
M  project.yml                             (target Caffeinated → Latte; bundle id; entitlements path)
M  ROADMAP.md                              (v0.2 → v0.3; session 3 done; session 4 next)
M  docs/SESSION_HANDOFF.md                 (overwritten for session 4 entry)
M  docs/design/01-PRD.md                   (v0.2 → v0.2.1; change-log traceability entry)
M  docs/design/02-architecture.md          (v0.2 → v0.3; §10 gap closed)

D  Sources/CaffeinatedApp.swift            (skeleton)
D  Sources/AwakeManager.swift              (skeleton)
D  Sources/PowerAssertion.swift            (skeleton)
D  Sources/Duration.swift                  (skeleton)
D  Sources/MenuBarView.swift               (skeleton)
D  Sources/SettingsView.swift              (skeleton)
D  Sources/CoffeeCupView.swift             (skeleton)
D  Sources/Triggers/CalendarTrigger.swift  (skeleton)
D  Sources/Triggers/TriggerProtocol.swift  (skeleton)
D  Sources/Intents/AwakeIntents.swift      (skeleton)
D  Tests/AwakeManagerTests.swift           (skeleton)

A  Sources/App/AppEnvironment.swift
A  Sources/App/LatteApp.swift
A  Sources/Core/AwakeDuration.swift
A  Sources/Core/AwakeManager.swift
A  Sources/Core/Logging.swift
A  Sources/Core/PowerAssertion.swift
A  Sources/Core/SettingsStore.swift
A  Sources/Triggers/AppTrigger.swift
A  Sources/Triggers/CalendarTrigger.swift
A  Sources/Triggers/FocusTrigger.swift
A  Sources/Triggers/Trigger.swift
A  Sources/Triggers/TriggerCoordinator.swift
A  Sources/Triggers/WiFiTrigger.swift
A  Sources/Intents/AwakeIntents.swift
A  Sources/UI/Components/CoffeeCupView.swift
A  Sources/UI/Components/LiquidGlassModifier.swift
A  Sources/UI/MenuBar/DurationPickerRow.swift
A  Sources/UI/MenuBar/HeaderView.swift
A  Sources/UI/MenuBar/MenuBarRoot.swift
A  Sources/UI/Settings/AboutTab.swift
A  Sources/UI/Settings/GeneralTab.swift
A  Sources/UI/Settings/SettingsRoot.swift
A  Sources/UI/Settings/TriggersTab.swift
A  Sources/UI/Theme/Theme.swift
A  Tests/AwakeDurationTests.swift
A  Tests/AwakeManagerTests.swift
A  Tests/SettingsStoreTests.swift
A  Tests/TriggerCoordinatorTests.swift
```

---

## How to resume

1. Read [ROADMAP.md](../ROADMAP.md) — orientation (~30 sec).
2. Read this file — current state (~2 min).
3. Open the spec docs in tabs:
   - [02-architecture.md §4.4](design/02-architecture.md) (`Trigger` contract)
   - [03-state-machine.md §5.1](design/03-state-machine.md) (any-OR aggregation — guides every trigger's vote semantics)
   - [04-data-model.md §4.2–4.5](design/04-data-model.md) (per-trigger schema; all keys already exist in code)
4. Open `Sources/Triggers/` — fill in the four stubs in order: Calendar → App → Wi-Fi → Focus.
5. TDD: write the integration test for each trigger first (mocked source), watch it fail, implement, watch it pass.
