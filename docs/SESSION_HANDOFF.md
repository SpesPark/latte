# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 4 of ~10 |
| **Theme** | Phase 1.A — real trigger wiring (Calendar, App, Wi-Fi, Focus) |
| **Date** | 2026-04-26 |
| **Status** | ✅ Completed as planned. All four triggers now back to real system APIs through a `*Source` DI seam. |

### What was accomplished

1. **`Sources/Triggers/CalendarTrigger.swift`**
   - Added `CalendarSource` protocol (`permissionStatus`, `requestAccess`, `events(in:calendarIDs:)`).
   - Added `EKCalendarSource` (real EventKit adapter; uses `requestFullAccessToEvents` on macOS 14+, falls back to `requestAccess(to: .event)` on macOS 13).
   - Added `MockCalendarSource` for tests.
   - `CalendarTrigger.start()` polls every 60 s by default, computes the active set per event window `[start − leadTime, end + trailingTime]`, and emits ON/OFF only on set transitions. Honors `calendarTriggerCalendarIDs`, `calendarTriggerExcludeAllDay`, and clamped 0–15 min lead/trailing windows from `04 §4.2`.
   - `pollOnce()` exposed as a test seam so we don't have to spin a real polling task in tests.

2. **`Sources/Triggers/AppTrigger.swift`**
   - Added `WorkspaceSource` protocol with `runningBundleIDs` snapshot + `observeLifecycle(onLaunch:onTerminate:) -> WorkspaceObservation`.
   - Added `NSWorkspaceSource` (real `NSWorkspace.shared` + `notificationCenter.didLaunchApplicationNotification` / `didTerminateApplicationNotification`).
   - Added `MockWorkspaceSource` with `simulateLaunch(_:)` / `simulateTerminate(_:)` test helpers.
   - `AppTrigger.start()` snapshots running apps, intersects with `appTriggerBundleIDs` (sanitized via `AppTriggerDefaults.sanitize`), and emits ON if any are running. Subsequent launches/terminates are diffed against the watched set; ON is emitted only on `empty → non-empty`, OFF only on `non-empty → empty`. Avoids spurious re-emits.

3. **`Sources/Triggers/WiFiTrigger.swift`**
   - Added `WiFiSource` protocol with `currentSSID`, `permissionStatus`, `requestAccess()`.
   - Added `CoreWLANSource` (real `CWWiFiClient.shared().interface()?.ssid()` + `CLLocationManager` for permission). Implements `CLLocationManagerDelegate` to capture authorization-status callbacks.
   - Added `MockWiFiSource` for tests.
   - `WiFiTrigger.start()` polls every 30 s by default. `evaluate()` is the test seam: vote ON when `SSID ∈ wifiTriggerSSIDs` (or, with `wifiTriggerInverseLogic = true`, when `SSID ∉ list` AND list non-empty). Empty inverse list is a no-op rather than "always on" — a safer default.
   - Suppresses repeated identical votes.

4. **`Sources/Triggers/FocusTrigger.swift`**
   - Added `FocusSource` protocol (`permissionStatus`, `isFocusActive`, `requestAccess()`, `observe(onChange:) -> FocusObservation`).
   - Added `INFocusSource` (real `INFocusStatusCenter.default`, KVO on `focusStatus`, `requestAuthorization()`).
   - Added `MockFocusSource` for tests.
   - **v1 limitation**: `INFocusStatusCenter` does not disclose Focus identifiers, only `isFocused: Bool?`. So `FocusTrigger` interprets `focusTriggerFocusIDs` as a presence check (non-empty + `isFocused == true` → vote ON). Per-Focus filtering deferred to Phase 1.5 (documented in [04 §4.5 footnote](design/04-data-model.md#45-focus-mode-trigger)).

5. **`Sources/App/AppEnvironment.swift` + `LatteApp.swift`**
   - Added `AppEnvironment.bootTriggers()`. For each registered + enabled trigger: if `requiresPermission`, ask first; only call `coordinator.start(...)` if granted.
   - `LatteApp` invokes `bootTriggers()` from the `MenuBarExtra`'s `.task` modifier on first appearance.

6. **`Resources/Info.plist`**
   - Kept: `NSCalendarsFullAccessUsageDescription`, `NSCalendarsUsageDescription`.
   - **Added**: `NSLocationWhenInUseUsageDescription` (Wi-Fi SSID prerequisite per macOS 12+).
   - **Added**: `NSFocusStatusUsageDescription` (required by `INFocusStatusCenter.requestAuthorization`).

7. **`Configuration/Latte.entitlements`**
   - Kept: app-sandbox, calendars, network.client.
   - **Added**: `com.apple.security.personal-information.location` (sandboxed Wi-Fi SSID access).

8. **`docs/design/02-architecture.md`** v0.3 → **v0.4**
   - New §4.4.1 documenting the `*Source` DI pattern adopted in this session. Trigger protocol unchanged; only impl strategy changed.

9. **`docs/design/04-data-model.md`** v0.1 → **v0.2**
   - §4.5 footnote added: documents the `INFocusStatusCenter` ID-opacity limitation and that the existing `focusTriggerFocusIDs` key shape is preserved for future per-Focus filtering.

10. **Tests** — 5 new files, ~750 lines
    - [`CalendarTriggerTests.swift`](../Tests/CalendarTriggerTests.swift) — 9 tests: active emit, future no-emit, lead/trailing windows, all-day exclude, calendar-ID filter, on→off transition, disabled no-op, permission-status branches.
    - [`AppTriggerTests.swift`](../Tests/AppTriggerTests.swift) — 10 tests: initial-snapshot ON/no-ON, launch/terminate, second-launch idempotence, partial-terminate keeps ON, stop cleanup, requires-no-permission.
    - [`WiFiTriggerTests.swift`](../Tests/WiFiTriggerTests.swift) — 9 tests: allowlist hit/miss, on→off transition, inverse logic both directions, empty-inverse no-op, idempotent re-emit, disabled / denied no-ops.
    - [`FocusTriggerTests.swift`](../Tests/FocusTriggerTests.swift) — 8 tests: active-on-start, inactive-no-emit, flip on/off via mock, default fallback, denied no-op, permission-status branches, stop cleanup.
    - [`TriggerIntegrationTests.swift`](../Tests/TriggerIntegrationTests.swift) — 2 end-to-end tests (`MockTrigger × TriggerCoordinator × real AwakeManager`) covering 03 §8.1 happy path and §8.2 back-to-back-meetings (assertion never released).

### What was *not* done (intentionally deferred)

- **Build verification** — Xcode is still not installed locally; build still happens in session 6. Code is type-checked from spec.
- **Per-Focus-mode filtering** — Apple's privacy stance on Focus IDs blocks this. Tracked as Phase 1.5 (see [04 §4.5](design/04-data-model.md#45-focus-mode-trigger)).
- **Settings UI for trigger configuration** — currently the four `TriggersTab.swift` cells are placeholders; populating with calendar pickers, app-bundle pickers, SSID pickers, etc. lives in session 5 alongside the design polish.
- **Filesystem rename of repo root** `Caffeinated-Clone/ → Latte/`. Same as before — owner does this once before first push.

---

## Next session entry point

**Theme**: Phase 1.C — design polish (session 5 of ~10)

**Goal**: Deliver the visual polish that makes Latte feel like a $2.99 utility rather than an SF-Symbol-default skeleton. Hits PRD F-1.C.01 ~ F-1.C.07.

### To-do (in order)

#### A. Coffee cup animation (~60 min) — F-1.C.01

1. Replace `Sources/UI/Components/CoffeeCupView.swift` placeholder with a `Canvas` + `TimelineView` that renders the cup body, handle, and steam particles. Target 60 fps.
2. Steam particles should drift up and fade. Use a small particle system seeded by `Date().timeIntervalSinceReferenceDate` so animation is deterministic per frame time.
3. Bind the active/inactive visual state to `AwakeManager.isAwake` — full opacity + steam when awake, dimmed + no steam when asleep.

#### B. Liquid Glass treatment + fallback (~30 min) — F-1.C.02 / F-1.C.03

4. Today `Sources/UI/Components/LiquidGlassModifier.swift` already gates with `#available(macOS 26, *)`. Verify the macOS-13~25 fallback uses `.ultraThinMaterial` consistently across `MenuBarRoot`, `HeaderView`, and the Settings tabs.
5. Apply the modifier where the design calls for it; do **not** apply globally.

#### C. App icon spec (~30 min) — F-1.C.04

6. Owner-facing deliverable: write `docs/design/05-icon-spec.md` describing the icon brief — palette, motif (steaming coffee cup over a half-moon?), required sizes, reference to Apple's Icon Composer guidance. This doc is what the owner hands to a designer/AI tool. **No actual PNG produced this session** — that's owner-side work between sessions.

#### D. Menu bar icon variants (~30 min) — F-1.C.05

7. In `Resources/Assets.xcassets/` add three SF-Symbol-rendered icon variants (`filled`, `outline`, `clock`). Update `MenuBarExtra` to switch on `menuBarIconStyle` from `SettingsStore`. Wire the General tab picker.

#### E. Settings typography + dark mode (~30 min) — F-1.C.06 / F-1.C.07

8. Audit every `Text(...)` in `Sources/UI/Settings/*.swift` and `Sources/UI/MenuBar/*.swift`. Use `.headline` / `.body` / `.caption` consistently. Verify dark-mode contrast ratios pass WCAG AA at standard text sizes.

#### F. Wrap (~15 min)

9. Update the trigger detail UI in `TriggersTab.swift` so each row shows current vote status from `coordinator.activeVotes`. (Out-of-scope: per-trigger config UI — that's session 7.)
10. Bump `02-architecture.md` if any new UI primitives shift module boundaries (unlikely). Bump `01-PRD.md` change log to mark F-1.C.01 ~ F-1.C.07 as in-flight.
11. Overwrite `docs/SESSION_HANDOFF.md` for session 6 entry (build verification — owner-blocked on Xcode).

### Cannot-start-without checks

- Xcode is **not** required for session 5 either — animation correctness is reviewable in code; visual verification ships in session 6.
- Re-read [`02-architecture.md` §3.1](design/02-architecture.md) before adding new files — keep `UI/` subfolders intact (`MenuBar/`, `Settings/`, `Components/`, `Theme/`).
- Read [`PRD §6.4`](design/01-PRD.md) for the F-1.C feature IDs above; cross-check checkbox status in §10.

---

## Decisions still pending owner approval

**None for session 5.** Visual decisions (palette, exact motif) are deferred to the icon-spec doc; that goes to the owner as a brief, not a unilateral commit.

---

## Known issues / debt

| Issue | Impact | Plan |
|---|---|---|
| Repo root folder still named `Caffeinated-Clone/` | Cosmetic only; nothing in code references it | Owner renames to `Latte/` before first external push |
| Bundle ID `com.example.latte` is placeholder | Cannot ship | Owner provides real reverse-domain before session 8 |
| Xcode (full) not installed locally | Cannot build/run | Owner installs before session 6 |
| No app icon yet | Cannot ship | Spec written in session 5; owner produces PNG before session 8 |
| No Apple Developer Program enrollment | Cannot submit | Owner enrolls before session 8 |
| `INFocusStatusCenter` does not expose Focus IDs | Per-Focus filtering can't ship in v1 | Documented as Phase 1.5 follow-up; key shape preserved |
| Trigger config UI (calendar/bundle/SSID pickers) not built | Settings → Triggers tab is placeholder rows | Session 7 (test coverage + UI fill-in) |
| `AwakeManager.installSignalHandlers()` uses `AwakeManager.shared` from a `@convention(c)` handler | Best-effort cleanup only; cannot fully synchronize on signal | Acceptable for menu-bar utility |

---

## Files changed this session

```
M  Configuration/Latte.entitlements        (added location entitlement)
M  Resources/Info.plist                    (added NSLocation + NSFocusStatus usage strings)
M  ROADMAP.md                              (v0.3 → v0.4; session 4 done; session 5 next)
M  docs/SESSION_HANDOFF.md                 (overwritten for session 5 entry)
M  docs/design/02-architecture.md          (v0.3 → v0.4; §4.4.1 added)
M  docs/design/04-data-model.md            (v0.1 → v0.2; §4.5 footnote added)

M  Sources/App/AppEnvironment.swift        (bootTriggers)
M  Sources/App/LatteApp.swift              (.task → bootTriggers)
M  Sources/Triggers/CalendarTrigger.swift  (CalendarSource + EKCalendarSource + Mock + real polling)
M  Sources/Triggers/AppTrigger.swift       (WorkspaceSource + NSWorkspaceSource + Mock + lifecycle observe)
M  Sources/Triggers/WiFiTrigger.swift      (WiFiSource + CoreWLANSource + Mock + 30s poll)
M  Sources/Triggers/FocusTrigger.swift     (FocusSource + INFocusSource + Mock + KVO observe)

A  Tests/CalendarTriggerTests.swift
A  Tests/AppTriggerTests.swift
A  Tests/WiFiTriggerTests.swift
A  Tests/FocusTriggerTests.swift
A  Tests/TriggerIntegrationTests.swift
```

---

## How to resume

1. Read [ROADMAP.md](../ROADMAP.md) — orientation (~30 sec).
2. Read this file — current state (~2 min).
3. Open the spec in tabs:
   - [01-PRD.md §6.4](design/01-PRD.md) (Phase 1.C feature list)
   - [02-architecture.md §3.1](design/02-architecture.md) (UI folder layout)
4. Open `Sources/UI/Components/CoffeeCupView.swift` — start with the animation. Hit each F-1.C ID in order.
