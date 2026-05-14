# QA Log

> Manual smoke + acceptance log for each session. Append, never overwrite.
> Triage: **P1** = blocks ship, **P2** = ship with workaround, **P3** = cosmetic.

---

## S7 — coverage + QA pass (2026-04-26)

### Automated coverage gate

Per `02-architecture.md` §13 / PRD §10. Gate = ≥80% for `Sources/Core/**` and `Sources/Triggers/**` (excluding live-system adapters: `EKCalendarSource`, `NSWorkspaceSource`, `INFocusSource`, `CoreWLANSource`).

Result on 2026-04-26 from `/tmp/Latte_S7_round3.xcresult` (227/227 tests pass):

| File | Cov% | Status |
|---|---|---|
| Core/AwakeDuration | 100.0% | ✅ |
| Core/AwakeManager | 94.1% | ✅ |
| Core/Logging | 100.0% | ✅ |
| Core/PowerAssertion | 87.3% | ✅ |
| Core/SettingsStore | 100.0% | ✅ |
| Triggers/Trigger | 82.8% | ✅ |
| Triggers/TriggerCoordinator | 92.3% | ✅ |
| Triggers/AppTrigger | 98.5% | ✅ |
| Triggers/CalendarTrigger | 98.8% | ✅ |
| Triggers/FocusTrigger | 97.9% | ✅ |
| Triggers/WiFiTrigger | 96.5% | ✅ |

**GATE: PASS**

### Reproduction

```bash
xcodebuild test -scheme Latte \
  -destination "platform=macOS,arch=arm64" \
  -enableCodeCoverage YES \
  -resultBundlePath /tmp/Latte_S7.xcresult
xcrun xccov view --report /tmp/Latte_S7.xcresult
```

### Manual smoke checklist (owner)

> Run on **macOS 26 Tahoe** (current dev box). Re-run on macOS 13/14/15 if available, or defer to TestFlight (S9). Tick each line; log defects below.

Build location after S7 test run: `~/Library/Developer/Xcode/DerivedData/Latte-*/Build/Products/Debug/Latte.app`. Open with `open <path>` and the menu-bar icon should appear.

#### Menu-bar UI

- [ ] Menu-bar icon visible after launch (default `cup.and.saucer.fill`).
- [ ] Click icon → menu opens with header, four duration rows (15m / 30m / 1h / 2h), Custom row, Turn-off row, Settings…, Quit.
- [ ] Pick "30m" → cup view animates (steam particles drift up, liquid fills).
- [ ] Switch to another app → cup keeps animating (TimelineView is foreground-agnostic).
- [ ] Click "Turn off" → cup empties, menu-bar icon returns to inactive style, no power assertion held (`pmset -g assertions | grep -i caffeinate` shows nothing).

#### Custom duration

- [ ] Custom row stepper accepts 1…1440 min.
- [ ] Setting custom duration to e.g. 7 min triggers awake for ~7 minutes; auto-expires.
- [ ] Negative / out-of-range values are rejected (the Stepper clamps).

#### Coffee tone customization

- [ ] Settings → General → Appearance → switch between 6 presets (espresso, caramel, mocha, latte, matcha, noir).
- [ ] Inline Preview cup updates color **immediately** (live binding).
- [ ] Menu-bar icon and main cup re-tint **without restart** (within ≤1 frame).
- [ ] Choosing a preset persists across quit + relaunch.

#### Menu-bar icon style

- [ ] Settings → General → Menu-bar icon style → switch between Filled / Outlined / Clock.
- [ ] Menu-bar icon updates **immediately** (no delay, no relaunch).
- [ ] Selection persists across quit + relaunch.

#### Triggers tab

- [ ] Settings → Triggers → toggling a disabled trigger ON does not crash; permission prompt appears for Calendar/Wi-Fi/Focus on first enable.
- [ ] Toggling a trigger OFF does not re-prompt for permission.
- [ ] Vote indicator (live dot/text) reflects coordinator's last vote per trigger.

#### Per-trigger configuration (Phase 1.5.A — added in S7.5)

- [ ] Tapping a trigger row expands the disclosure and reveals the per-trigger config form.
- [ ] Toggling a trigger ON auto-expands its config form (so the user sees what they just enabled).
- [ ] **App** trigger: bundle-ID list shows curated defaults (Zoom / Teams / Webex / Discord / Slack) plus any user additions.
  - [ ] "Add" button is disabled for empty input and for invalid bundle IDs (e.g. with spaces).
  - [ ] "Add from running apps" disclosure shows actual running bundle IDs that aren't already in the list. Plus button adds them.
  - [ ] Minus button removes a bundle ID, change persists across quit + relaunch.
- [ ] **Wi-Fi** trigger: mode picker (on-list vs inverse) live-updates `wifiTriggerInverseLogic`.
  - [ ] "Add" button rejects SSIDs longer than 32 UTF-8 bytes and rejects duplicates.
  - [ ] If currently joined to a non-listed network, "Add current network: <ssid>" button appears and adds it on tap.
  - [ ] Empty list under inverse mode displays the no-op explanation copy.
- [ ] **Calendar** trigger: lead/trail steppers clamp to 0–15 (UI Stepper enforces); "Exclude all-day events" toggle defaults to ON.
- [ ] **Focus** trigger: shows the explanatory paragraph about INFocusStatusCenter limitation; no other UI.

#### Quit & power assertion hygiene

- [ ] Quit via menu → process exits cleanly.
- [ ] After quit, `pmset -g assertions | grep -i com.parkbyeongjun.latte` returns nothing (no leaked assertion).
- [ ] Force-kill (`kill -9`) → `pmset` may briefly show a stale assertion; re-launch then quit cleanly to verify recovery (acceptable; documented in arch §13).

#### macOS version matrix

- [x] **macOS 26 Tahoe** (dev box) — covered by automated tests + above smoke if owner ticks.
- [ ] macOS 15 Sequoia — defer to TestFlight (S9).
- [ ] macOS 14 Sonoma — defer to TestFlight (S9).
- [ ] macOS 13 Ventura (PRD min) — defer to TestFlight (S9).

### Defects found

> Log here if any checklist line fails. Format:
>
> #### S7-DEF-NN — short title
> - **Severity**: P1/P2/P3
> - **Repro**: …
> - **Expected**: …
> - **Actual**: …
> - **Status**: open / fixed-in-Sx / wontfix

_None recorded as of 2026-04-26 (smoke owed by owner)._

---

## S7.5 → S7.6 — TriggersTab UX defects logged + fixed (2026-04-26)

Owner ran the S7.5 smoke and surfaced two related defects in the per-trigger config UI. Both were resolved in S7.6 the same day; the original DisclosureGroup-based TriggersTab no longer exists.

#### S75-DEF-01 — TriggersTab subtitle / Toggle state visibly out of sync

- **Severity**: P1
- **Repro**: open Settings → Triggers, tap a trigger row's Toggle several times in succession.
- **Expected**: Toggle ON ↔ subtitle reads "Idle" or active vote reason; Toggle OFF ↔ subtitle reads "Disabled".
- **Actual**: After a few clicks, Toggle and subtitle would show contradictory states (Toggle ON while subtitle said "Disabled", or vice versa).
- **Root cause**: `DisclosureGroup` label contained both the row HStack and the Toggle, so SwiftUI's hit testing was firing the disclosure-expand and the Toggle's onTap on overlapping click regions. `subtitle` read `trigger.isEnabled` (via `SettingsStore` round-trip) while the Toggle UI bound to a local `@State var isOn` — any race where one updated before the other left the two visibly inconsistent. The `if newValue { isExpanded = true }` side-effect inside the Toggle's `onChange` added a second state mutation in the same transaction, making the race more visible.
- **Status**: **fixed-in-S7.6** (commit pending in this session). DisclosureGroup retired in favor of `Section` per trigger; standalone Toggle row removes click-target collision; `subtitle` helper deleted (Toggle is now the sole UI for enabled-state).

#### S75-DEF-02 — Per-trigger config UI feels "복잡하고 직관적이지 않음"

- **Severity**: P2 (UX)
- **Repro**: open Settings → Triggers → tap a row.
- **Expected**: clear, macOS-native config layout.
- **Actual**: row had 6+ elements packed (icon / name / subtitle / voting dot / Toggle / disclosure chevron); nested `Form > Section > DisclosureGroup > VStack > Stepper/Picker` produced inconsistent paddings; "Add from running apps" was another nested DisclosureGroup inside the App config form.
- **Status**: **fixed-in-S7.6**. Section-per-trigger reduces visual density; "Add from running apps" replaced with a `Menu` (standard macOS dropdown); WiFi mode picker switched to `.segmented` for a cleaner binary choice.

> Re-run the **Per-trigger configuration** smoke checklist above against the S7.6 build before opening S8 — that's the only outstanding S7→S8 prerequisite.

---

## S7.6 → S7.7 — App trigger UX rewrite to friendly app names (2026-04-26)

Owner ran the S7.6 smoke and surfaced one defect in the App trigger config UI. Resolved in S7.7 the same day.

#### S76-DEF-01 — App trigger row shows raw bundle IDs + no purpose copy

- **Severity**: P2 (UX)
- **Repro**: Settings → Triggers → enable App trigger → expand config form.
- **Expected**: human-readable app names (e.g. "Zoom", "Microsoft Teams") with familiar icons; clear explanation of what the trigger does.
- **Actual**: each watched row rendered a generic `app.fill` SF Symbol + raw bundle ID (`us.zoom.xos`, `com.microsoft.teams2`, …). No purpose copy. The "Add from running apps" Menu also listed raw bundle IDs. Owner: "앱 이름들이 com.xxxxx.xxxxx 다 이런식으로 나와서 직관적으로 이해하기 좀 어렵고, 이 트리거가 무슨 용도로 사용되는지도 직관적으로 이해가 잘 안돼."
- **Root cause**: `AppTriggerConfigForm` rendered `Text(bundleID)` directly with no resolution layer. The underlying `WorkspaceSource` protocol had no facility to resolve a friendly name or icon for a bundle ID.
- **Status**: **fixed-in-S7.7** (this session).
  - `WorkspaceSource` extended with `displayInfo(for: String) -> AppDisplayInfo?` returning a Sendable struct of `displayName` + optional PNG-encoded icon data.
  - `NSWorkspaceSource.displayInfo(for:)` resolves in priority order: running app (`NSRunningApplication.localizedName`/`icon`) → installed bundle (`NSWorkspace.urlForApplication(...)` + `Bundle` metadata) → curated default name table → `nil`.
  - `AppTriggerDefaults.displayName(for:)` provides fallback names for the 6 curated default IDs (Zoom, Microsoft Teams, Webex, Discord, Slack, Google Meet).
  - `MockWorkspaceSource.displayInfoLookup` stubbable; falls back to `AppTriggerDefaults.displayName(for:)`.
  - `AppTriggerConfigForm` rewritten: each row uses new `AppRow` view (icon + display name + bundle ID secondary line). Purpose-explaining caption added at the top of the form. "Add from running apps" Menu items now show display names. Manual bundle-ID input collapsed into a `DisclosureGroup` labelled "Advanced — add by bundle ID" (closed by default, label is non-interactive caption per S7.6 lesson).
  - `Tests/AppTriggerTests.swift`: 6 new tests (curated mapping, mock fallback, mock override priority, AppTrigger passthrough). 229 → 235 tests.
  - **Architecture / persistence changes**: none. `SettingsStore.appTriggerBundleIDs` still stores `[String]` of bundle IDs; the friendly resolution is purely a render-time concern.

### Additional smoke checklist for S7.7 (owner)

Append to the §S7 "Per-trigger configuration" section. Run on the S7.7 build before opening S8.

- [ ] App trigger Section header copy reads roughly "Latte stays awake while any of these apps are running. Add the apps that must keep your Mac active — video meetings, presentations, long-running tools."
- [ ] Each watched-app row shows: real app icon (left) + friendly display name (top, body font) + bundle ID (bottom, muted caption).
  - For curated defaults that aren't installed (e.g. Webex if you don't have it): displays the curated name ("Webex") with a generic `app.fill` icon and the bundle ID below.
  - For installed apps that are currently running: real icon + system-localized display name.
- [ ] "Add from running apps" Menu lists running apps by display name (sorted alphabetically), not by bundle ID.
- [ ] "Advanced — add by bundle ID" disclosure is **collapsed** by default. Expanding it reveals the manual TextField + Add button (unchanged behaviour from S7.6).
- [ ] Adding an app via the Menu / Advanced TextField makes it appear in the list with the resolved friendly name on the next render.

### Coverage gate snapshot (post-S7.7)

Per-file coverage on `Sources/Core/**` and `Sources/Triggers/**` after S7.7, with the 4 adapter classes (`NSWorkspaceSource`, `EKCalendarSource`, `INFocusSource`, `CoreWLANSource`) and their inner closures excluded:

| File | Cov% | Status |
|---|---|---|
| Core/AwakeDuration | 100.00% | ✅ |
| Core/AwakeManager | 94.12% | ✅ |
| Core/Logging | 100.00% | ✅ |
| Core/PowerAssertion | 87.32% | ✅ |
| Core/SettingsStore | 100.00% | ✅ |
| Triggers/Trigger | 82.76% | ✅ |
| Triggers/TriggerCoordinator | 92.31% | ✅ |
| Triggers/AppTrigger | 98.68% | ✅ |
| Triggers/CalendarTrigger | 98.75% | ✅ |
| Triggers/FocusTrigger | 97.94% | ✅ |
| Triggers/WiFiTrigger | 96.55% | ✅ |

**GATE: PASS** (235/235 tests, lowest 82.76%).

---

## S7.7 → S7.8 — App trigger UX iteration #2: pickable filter + installed-only seed (2026-04-26)

Owner re-smoke against the S7.7 build surfaced three related complaints:

1. *Pre-loaded curated defaults (Zoom / Teams / Discord etc.) show no icon on owner's machine because owner has none of them installed.*
2. *"Add from running apps" Menu items show app names without icons — names alone are hard to scan.*
3. *"Add from running apps" Menu lists "별의별 것들이 다 떠있어" — every running process including system daemons, menu-bar utilities, and Latte itself.*

The root of #1 is structural: pre-populating curated defaults for users who don't have those apps installed creates a confusing list of unfamiliar entries. Fixing the icon visual (S7.7 attempted this with NSWorkspace resolution) helps users who *have* the apps but doesn't help users who *don't*. So S7.8 fixes the root by no longer pre-populating apps the user doesn't own.

#### S77-DEF-01 — Pre-loaded curated defaults populate apps the user doesn't have

- **Severity**: P2 (UX)
- **Repro**: Fresh install of Latte → Settings → Triggers → enable App trigger.
- **Expected**: a list of apps relevant to *this user*, or a friendly empty state that invites them to add their own.
- **Actual**: list pre-populated with all 6 curated defaults (Zoom, Microsoft Teams, Webex, Discord, Slack, Google Meet) regardless of which are actually installed. For owners with none installed, the list looks broken (generic icons, no apparent reason these apps are there).
- **Status**: **fixed-in-S7.8**.
  - `WorkspaceSource` extended with `isInstalled(_ bundleID: String) -> Bool` (real impl uses `NSWorkspace.urlForApplication(withBundleIdentifier:)`).
  - New `AppTriggerDefaults.installedDefaults(in source: WorkspaceSource) -> [String]` filters the 6 curated IDs to those that resolve on the user's machine.
  - New `SettingsKey.hasSeededAppDefaults` flag persists "we've already done first-launch seeding" so subsequent launches don't re-seed.
  - `AppTrigger.init` calls `seedInstalledDefaultsIfNeeded()` — runs once per install: if `raw` is empty and the flag is unset, write the installed-only filtered defaults and set the flag. Idempotent across all subsequent inits. If raw is non-empty (user has explicit config or a test fixture set the list directly), seeding is skipped and the flag is set.
  - `SettingsStore.appTriggerBundleIDs` getter no longer falls back to all 6 curated IDs when raw is empty — empty means "watch nothing." The seeding mechanism above is the *only* place curated defaults are populated.
  - UI empty-state copy refreshed: "No apps configured yet. Use 'Add from running apps' below to add the apps you want Latte to keep awake — or use 'Advanced' for an app that isn't running right now."

#### S77-DEF-02 — "Add from running apps" Menu items have no icons

- **Severity**: P2 (UX)
- **Repro**: Settings → Triggers → enable App trigger → "Add from running apps".
- **Actual**: each candidate row shows app name as plain text only.
- **Status**: **fixed-in-S7.8**. Menu items now use SwiftUI `Label { Text(name) } icon: { Image(nsImage: …) }`. When the resolved `displayInfo.iconImageData` is non-nil (real running app), the real app icon renders alongside the name. When the icon is missing but the bundle ID has a curated category (Zoom/Teams/Webex/Meet → `video.fill`, Discord/Slack → `bubble.left.and.bubble.right.fill`), `Label(title, systemImage:)` is used so the row at least communicates *what kind of app* it is. The same SF Symbol fallback is applied to the watched-list `AppRow` icon view.

#### S77-DEF-03 — "Add from running apps" shows every running process

- **Severity**: P2 (UX)
- **Repro**: Settings → Triggers → "Add from running apps".
- **Actual**: dropdown lists 30+ entries including system daemons, menu-bar utility helpers, and Latte itself.
- **Status**: **fixed-in-S7.8**. New `WorkspaceSource.pickableRunningBundleIDs` requirement; the real `NSWorkspaceSource` filters `runningApplications` to `activationPolicy == .regular` (apps the user actively works in — approximately the Dock-visible set) and excludes the current process (`Bundle.main.bundleIdentifier`). The trigger's lifecycle / start-snapshot logic still uses `runningBundleIDs` (unfiltered), so users can still manually add a `.accessory` bundle via the Advanced section and the trigger will detect launches/terminates of those apps via the `observeLifecycle` notification path. UI uses `pickableRunningBundleIDs` for the Menu candidates only.

### Additional smoke checklist for S7.8 (owner)

Append to the §S7 / §S7.7 sections. Run on the S7.8 build before opening S8.

- [ ] **Fresh install behavior** (delete the Latte preferences before re-launching, e.g. `defaults delete com.parkbyeongjun.latte`): App trigger config form opens with **empty** watched list and the new empty-state copy. None of Zoom / Teams / Discord / etc. appear pre-populated unless installed.
- [ ] **Curated defaults still seeded if installed**: install Zoom (or any curated default app), delete preferences, re-launch Latte. Watched list should now contain only the installed curated entries.
- [ ] **"Add from running apps" Menu**: lists only `.regular` activation policy apps (the apps you'd see in Cmd-Tab + Dock), sorted alphabetically by display name. Latte itself does not appear. Menu bar utilities (e.g. CleanShot X, Bartender, Raycast) do not appear. System daemons do not appear.
- [ ] **Menu items show icons**: each candidate has the real app icon left of the name when running. Curated defaults that aren't running but are watched fall back to the SF Symbol category icon (video / chat).
- [ ] **Idempotent seeding**: launch app, configure watched list, quit, re-launch. Watched list survives without the seed re-running.
- [ ] **Explicit-clear stays clear**: configure watched list → remove all entries → quit → re-launch. Watched list stays empty (the seed flag is set, so curated defaults don't repopulate).

### Coverage gate snapshot (post-S7.8)

Per-file coverage with adapter classes + their inner closures excluded:

| File | Cov% | Status |
|---|---|---|
| Core/AwakeDuration | 100.00% | ✅ |
| Core/AwakeManager | 94.12% | ✅ |
| Core/Logging | 100.00% | ✅ |
| Core/PowerAssertion | 87.32% | ✅ |
| Core/SettingsStore | 100.00% | ✅ |
| Triggers/Trigger | 82.76% | ✅ |
| Triggers/TriggerCoordinator | 92.31% | ✅ |
| Triggers/AppTrigger | 98.89% | ✅ |
| Triggers/CalendarTrigger | 98.75% | ✅ |
| Triggers/FocusTrigger | 97.94% | ✅ |
| Triggers/WiFiTrigger | 96.55% | ✅ |

**GATE: PASS** (249/249 tests, lowest 82.76%).

---

## S7.8 → S7.9 — Trigger off / watched-list-edit doesn't deactivate cup (2026-04-26)

Owner ran the S7.8 build and confirmed positive cases work: enabling a trigger and having a watched app actually fires the cup activation. Negative cases were broken — toggling a trigger OFF or removing an app from the watched list left the cup activated indefinitely. Two structural bugs.

#### S78-DEF-01 — Toggle OFF only writes the persisted flag; trigger keeps voting awake

- **Severity**: P1 (the off switch doesn't actually turn things off)
- **Repro**: Settings → Triggers → enable App trigger with at least one matching watched app running → menu-bar header cup activates. Toggle the same trigger OFF → cup stays activated.
- **Root cause**: `TriggerSection.Toggle.onChange` in `Sources/UI/Settings/TriggersTab.swift` only assigned `trigger.isEnabled = newValue`, which writes the persisted flag via `SettingsStore`. No side-effect on the live trigger: the `WorkspaceObservation` stayed registered, the `voteStream` consumer Task in `TriggerCoordinator.consumerTasks[id]` stayed alive, and the previously-emitted ON `TriggerVote` stayed in `awakeManager.pendingVotes` (state `.awakeTriggered`). `manager.isAwake` therefore stayed `true`, the `HeaderView`'s `CoffeeCupView(isAwake:)` stayed in the awake render path, the `IOPMAssertion` stayed acquired.
- **Status**: **fixed-in-S7.9**.
  - `TriggerSection` now takes a `coordinator: TriggerCoordinator` parameter and the Toggle's `onChange` dispatches a `Task { @MainActor in … }` that calls `coordinator.start(trigger)` on ON or `coordinator.stop(trigger.id)` on OFF.
  - `TriggerCoordinator.stop(_:)` already removes the active vote from `activeVotes` and forwards a synthesized vote-OFF (`TriggerVote(wantsAwake: false, reason: "trigger stopped")`) to `awakeManager.receiveTriggerVote`. The state machine then transitions out of `.awakeTriggered`, `publishDerived()` flips `isAwake` to false (modulo cool-down), and the cup deactivates.
  - **Universal across all 4 triggers**: any registered trigger (Calendar / App / WiFi / Focus) now correctly stops on Toggle OFF.

#### S78-DEF-02 — Removing an app from the watched list leaves AppTrigger emitting a stale ON vote

- **Severity**: P1 (the watched list looks like the source of truth but isn't)
- **Repro**: Enable App trigger with Zoom in the watched list while Zoom is running → cup activates. Remove Zoom from the watched list (in the App trigger config form) → cup stays activated.
- **Root cause**: `AppTrigger.start()` snapshotted `let watched = Set(settings.appTriggerBundleIDs)` once and **captured that set into the lifecycle closures** (`onLaunch:` / `onTerminate:`). All subsequent `handleLaunch(bundleID:watched:)` / `handleTerminate(bundleID:watched:)` calls used that frozen capture. When the user mutated the watched list via the UI (`AppTriggerConfigForm.commit` → `settings.appTriggerBundleIDs = next`), the trigger's view of the watched set didn't change. `matchingRunning` continued to include the now-unwatched bundle ID → no vote-OFF emit → state stayed `.awakeTriggered` → cup stayed on.
- **Status**: **fixed-in-S7.9**.
  - `AppTrigger` now stores `private var watchedSet: Set<String>` as an instance property, set in `start()` from `settings.appTriggerBundleIDs` and cleared in `stop()`.
  - `handleLaunch(bundleID:)` / `handleTerminate(bundleID:)` are simplified to read `watchedSet` (no more captured parameter).
  - New public method `AppTrigger.reevaluateWatched()` reads the latest `settings.appTriggerBundleIDs`, diffs against `watchedSet`, recomputes `matchingRunning = running ∩ watched`, and emits the appropriate vote on transition (empty→non-empty: ON, non-empty→empty: OFF, non-empty→non-empty with set change: re-emit ON so the reason text reflects the new contents). No-op when settings didn't change OR when the trigger is stopped (the next `start()` will read fresh data anyway).
  - `AppTriggerConfigForm.commit(_:)` calls `trigger.reevaluateWatched()` after writing settings, so every add / remove flows through to the live vote stream within one render pass.
  - **Stream lifecycle hardening (regression guard for Toggle ON → OFF → ON)**: removed the `continuation.finish()` call from `AppTrigger.stop()`. Finishing the continuation permanently closed the `AsyncStream` — once stopped, no future `start()` could deliver votes. Now `stop()` only cancels the observation and clears `matchingRunning`/`watchedSet`; the stream stays open for the trigger's lifetime so a Toggle OFF → Toggle ON cycle works correctly. New regression test `testRestartAfterStopReEmitsInitialSnapshot`.

### Additional smoke checklist for S7.9 (owner)

Append to the §S7 / §S7.7 / §S7.8 sections.

- [ ] **Toggle OFF actually deactivates the cup**: enable App trigger with a running watched app → cup ON. Toggle OFF → cup deactivates within one frame (or during cool-down period if `coolingDown` state still applies — confirm against `02-architecture.md` §3 + state machine §4).
- [ ] **Toggle OFF → ON cycle works**: after Toggle OFF, Toggle ON the same trigger → cup re-activates if the watched app is still running.
- [ ] **Removing an app from the watched list deactivates the cup**: with a single watched matching app → cup ON. Remove that app via the minus button → cup deactivates.
- [ ] **Removing one of multiple watched apps keeps the cup ON**: Zoom + Teams both running and watched → cup ON. Remove only Zoom → cup stays ON (Teams still matching). Removing Teams too → cup deactivates.
- [ ] **Adding a running watched app activates the cup**: with empty watched list → cup OFF. Add a running app via "Add from running apps" → cup activates.
- [ ] **Same applies to Calendar / WiFi / Focus Toggle** (universal Toggle fix): toggling any trigger OFF deactivates its contribution to the awake state, ON re-activates.

### Coverage gate snapshot (post-S7.9)

Per-file coverage with adapter classes + their inner closures excluded:

| File | Cov% | Status |
|---|---|---|
| Core/AwakeDuration | 100.00% | ✅ |
| Core/AwakeManager | 94.12% | ✅ |
| Core/Logging | 100.00% | ✅ |
| Core/PowerAssertion | 87.32% | ✅ |
| Core/SettingsStore | 100.00% | ✅ |
| Triggers/Trigger | 82.76% | ✅ |
| Triggers/TriggerCoordinator | 92.31% | ✅ |
| Triggers/AppTrigger | 98.06% | ✅ |
| Triggers/CalendarTrigger | 98.75% | ✅ |
| Triggers/FocusTrigger | 97.94% | ✅ |
| Triggers/WiFiTrigger | 96.55% | ✅ |

**GATE: PASS** (255/255 tests, lowest 82.76%). AppTrigger drift from 98.89% → 98.06% reflects the new `reevaluateWatched` branches; still well above the 80% gate.

### Known follow-ups (S7.10 candidate)

The same "watched-list mutation doesn't reach the live trigger" pattern likely affects the other 3 triggers — a `WiFiTrigger.reevaluateConfiguration()` for SSID list / inverse-mode changes, a `CalendarTrigger.reevaluateConfiguration()` for lead/trail/exclude-all-day changes, etc. Owner did not surface these in the S7.8 smoke; deferred to S7.10 if reported. The universal Toggle fix (S78-DEF-01) already handles "disable this trigger entirely" for all 4.

---

## S7.9 → S7.10 — Per-trigger grace replaces blanket 60 s cool-down (2026-04-26)

Owner re-smoke against the S7.9 build:

> "1. 컵 비활성 안되고
> 2. 재활성 확인할 수 없었고 (1번 안 됐으니까)
> 3. 비활성 안됨
> 4. 비활성 안됨"
>
> "지금 비활성이 안돼서 점검 불가"

Diagnosis: S7.9's wiring (Toggle → coordinator.stop → vote-off; reevaluateWatched → vote-off via stream) was correct, and the integration tests confirmed the vote-off transitioned `.awakeTriggered → .coolingDown(60s)`. But `.coolingDown` is `isAwake = true` — the cup stays activated for the full 60 seconds before the timer fires and we transition to `.asleep`. Owner read this as "OFF doesn't work" rather than "OFF, but with a 60 s grace period."

#### S79-DEF-01 — 60 s cool-down reads as broken to users

- **Severity**: P1 (the OFF action's perceived behavior)
- **Repro**: Enable App trigger with a running watched app → cup ON. Toggle OFF. Cup stays ON for the next 60 seconds, then deactivates.
- **Original design intent (`docs/design/03-state-machine.md` §5.2 v0.1)**: a 60 s grace period to absorb back-to-back triggers (e.g., Zoom call ends 14:30, next call starts 14:30:45) so the cup wouldn't flicker between sessions.
- **Why the original intent didn't hold up**:
  - Empirically, leading sleep-prevention apps (Amphetamine, Owly, KeepingYouAwake, Caffeinated, Theine, Lungo) all transition immediately on trigger state changes. There is no industry precedent for a hidden cool-down, and no documented user complaint about flicker in those apps.
  - Latte's `.asleep` only releases the IOPMAssertion. macOS still respects its own idle timeout (typically 5–15 min) before actually sleeping. So even with `grace=0`, an active user keeps the Mac awake — the 60 s cool-down was largely working *underneath* the OS idle timer where it had no perceptible effect.
  - Real user workflows rarely hit the back-to-back gap the cool-down was designed for (Zoom usually stays open between meetings; calendar gaps are minutes, not seconds; WiFi blips resolve in 1–2 s).
- **Status**: **fixed-in-S7.10**.
  - Replaced blanket cool-down with **per-trigger grace**. `Trigger.graceSecondsAfterOff: TimeInterval` (default 0 via protocol extension). `TriggerVote.graceSecondsAfterOff: TimeInterval` (Sendable, default 0). `AwakeInput.triggerVoteOff` carries grace; state machine forks on `grace == 0` (direct `.asleep` + release assertion) vs `grace > 0` (existing `.coolingDown` path).
  - User-explicit OFF actions (`coordinator.stop`, `AppTrigger.reevaluateWatched`) always force `grace = 0` — UI edits feel instant regardless of the trigger's declared value.
  - **v1 default for all 4 triggers: 0.** Toggle OFF / list edit / organic OFF (app-terminate, calendar-end, WiFi-leave, Focus-off) all release the assertion immediately, matching how Amphetamine / Owly / KeepingYouAwake behave.
  - Cool-down infrastructure preserved for future opt-in (1-line `graceSecondsAfterOff` override on a specific trigger if production telemetry surfaces a real flicker problem).
  - Design doc `03-state-machine.md` v0.2 rewrote §5.2 with the revised rationale; architecture doc v0.15 §13 captured the architectural surgery.

### Additional smoke checklist for S7.10 (owner)

Re-run the §S7.9 cases. With per-trigger grace = 0 in v1, all of them must now show **immediate** cup deactivation:

- [ ] Toggle OFF → cup deactivates **within one frame** (no 60 s wait).
- [ ] Toggle OFF → ON cycle → cup re-activates if the watched app is still running.
- [ ] Removing the last watched app → cup deactivates immediately.
- [ ] Removing one of multiple watched apps → cup stays ON (the other still matches).
- [ ] Closing the watched app while the trigger is enabled (organic OFF) → cup deactivates immediately. (S7.10 v1 default; if WiFiTrigger ever opts into grace > 0 in the future, that case will pause briefly before deactivating.)
- [ ] Same applies to Calendar / WiFi / Focus Toggle and their natural OFF events.

Note on macOS sleep: cup deactivating ≠ Mac sleeping. Latte just releases the IOPMAssertion; macOS still follows the system idle timeout (System Settings → Lock Screen → Display sleep). If you're actively typing or moving the mouse, Mac stays awake regardless of cup state.

### Coverage gate snapshot (post-S7.10)

| File | Cov% | Status |
|---|---|---|
| Core/AwakeDuration | 100.00% | ✅ |
| Core/AwakeManager | 94.26% | ✅ |
| Core/Logging | 100.00% | ✅ |
| Core/PowerAssertion | 87.32% | ✅ |
| Core/SettingsStore | 100.00% | ✅ |
| Triggers/Trigger | 83.33% | ✅ |
| Triggers/TriggerCoordinator | 92.96% | ✅ |
| Triggers/AppTrigger | 98.62% | ✅ |
| Triggers/CalendarTrigger | 98.75% | ✅ |
| Triggers/FocusTrigger | 97.94% | ✅ |
| Triggers/WiFiTrigger | 96.55% | ✅ |

**GATE: PASS** (261/261 tests, lowest 83.33%).

---

## S7.10 → S7.11 — Stream-lifecycle parity for Calendar/WiFi/Focus + first AppIcon raster set (2026-04-27)

Post-S7.10 review pass surfaced a latent regression risk and the owner supplied the app icon master.

#### S710-DEF-01 — Stream-lifecycle fix from S7.9 was AppTrigger-only

- **Severity**: P1 latent (the bug only manifests if owner enables, then toggles OFF then ON, any of Calendar/WiFi/Focus triggers — not yet hit because owner is exercising App trigger first)
- **Root cause**: S7.9 removed `continuation.finish()` from `AppTrigger.stop()` so that Toggle OFF→ON cycles work (the AsyncStream stays open across the cycle; the coordinator handles consumer-task cancel/recreate). The same fix was *not* propagated to `CalendarTrigger.stop()` / `WiFiTrigger.stop()` / `FocusTrigger.stop()`, which all still finished their continuations. Effect identical to the pre-S7.9 AppTrigger bug: future `start()` recreates the observation but `continuation.yield(...)` calls are silently dropped because the stream is permanently closed; the consumer's `for await` exits immediately; the manager never receives the new vote; the cup never re-activates.
- **Status**: **fixed-in-S7.11**. Removed `continuation.finish()` from all three `stop()` methods; mirrored the explanatory comment from `AppTrigger.stop()` in each. Existing tests in `CalendarTriggerTests` / `WiFiTriggerTests` / `FocusTriggerTests` that asserted "stream finishes after stop" were updated to "no further votes are yielded after stop" via a bounded-timeout `Task.cancel()` probe — matches the post-S7.9 `testStopCancelsObservation` pattern.

### Additional smoke for S7.11 (owner — supersedes the deferred S7.10 candidate from earlier)

- [ ] **Calendar Toggle OFF → ON cycle**: enable Calendar trigger with at least one event in the next 24 h matching lead-time → cup activates near event start. Toggle OFF (cup deactivates immediately per S7.10), Toggle ON. Polling resumes; if an active event still falls within window, cup re-activates within ≤60 s (the polling interval).
- [ ] **WiFi Toggle OFF → ON cycle**: configure SSID list to include current network, enable trigger → cup activates within ≤30 s. Toggle OFF, ON. Cup re-activates within ≤30 s if still on the network.
- [ ] **Focus Toggle OFF → ON cycle**: turn on a Focus mode → cup activates. Toggle OFF, ON. Cup re-activates immediately (Focus is observer-based, not polled).
- [ ] **App icon visible**: in Finder → Applications, the Latte app shows the new latte-cup icon at 16/32/128 sizes. In Dock (if dragged in for testing) the icon renders cleanly.

### Coverage gate snapshot (post-S7.11)

| File | Cov% | Status |
|---|---|---|
| Core/AwakeDuration | 100.00% | ✅ |
| Core/AwakeManager | 94.26% | ✅ |
| Core/Logging | 100.00% | ✅ |
| Core/PowerAssertion | 87.32% | ✅ |
| Core/SettingsStore | 100.00% | ✅ |
| Triggers/Trigger | 83.33% | ✅ |
| Triggers/TriggerCoordinator | 92.96% | ✅ |
| Triggers/AppTrigger | 98.62% | ✅ |
| Triggers/CalendarTrigger | 98.79% | ✅ |
| Triggers/FocusTrigger | 97.98% | ✅ |
| Triggers/WiFiTrigger | 96.61% | ✅ |

**GATE: PASS** (263/263 tests, lowest 83.33%). **This entry closes the S7-family iteration.** Next session is S8 — App Store prep, blocked owner-side on Apple Dev Program enrollment + bundle ID prefix decision + folder rename.

---

## S8b — v1.0 scope expansion (2026-04-27)

Owner approved aggressive ship after S8b market research. Five additions on top of the original v1.0 scope landed in 4 atomic commits.

### Owner-side smoke checklist (supersedes S7.11 alone)

Run all S7.11 items above first, then add these for the v1.0 expansion. Particular attention to interactions between the new and existing surfaces.

#### Onboarding wizard (commit `2da1f3d`)

- [ ] **First launch presents the onboarding window**. Simulate a fresh install: quit Latte, then `defaults delete com.parkbyeongjun.latte` (or move the prefs plist out of the Latte container), relaunch. The 3-step wizard should appear: welcome → trigger picker (4 cards) → done.
- [ ] **Skip path**: hit "Skip" at any step. Window dismisses, menu bar icon present, no triggers enabled. Settings → Triggers should show all four toggles OFF.
- [ ] **Apply path with permission**: pick Calendar at step 2, hit "Apply." Permission prompt fires. Granting it: trigger ends up enabled with permission status `.granted`. Denying it: trigger row appears with the "Permission denied" footer copy in Settings → Triggers.
- [ ] **Apply with multiple triggers**: pick Calendar + App at step 2, hit "Apply." Both prompts fire (App trigger is `.notRequired` so it just enables). Done step lists both triggers in the summary.
- [ ] **Idempotency**: the wizard does NOT appear on the next launch. `defaults read com.parkbyeongjun.latte latte.firstRunCompleted` returns 1.

#### Menu-bar awake visualization (commit `05f8c2d`)

- [ ] **Filled style**: at rest, the menu-bar shows `cup.and.saucer` (outline). Activate manually via the popover → icon swaps to `cup.and.saucer.fill` (filled). Toggle OFF → reverts to outline within ≤1 frame.
- [ ] **Outline style**: same paired behavior (outline → fill).
- [ ] **Clock style**: at rest shows `mug` (a distinct glyph), active shows `cup.and.heat.waves.fill` (cup with steam). The asleep glyph is intentionally different from filled/outline to differentiate the option.
- [ ] **Style switching while active**: toggle a trigger ON, then change icon style in Settings → General → Appearance. Both the asleep and awake variants should update across the chosen style without a flicker.
- [ ] **Light + dark menu bar**: verify all 6 combos (3 styles × 2 awake states) render legibly in System Settings → Appearance → Light then Dark.

#### Launch at Login (commit `6109859`)

- [ ] **Toggle ON**: Settings → General → Behavior → "Launch at login" → ON. System Settings → General → Login Items should now list "Latte" under "Open at Login." `defaults read com.parkbyeongjun.latte latte.launchAtLogin` returns 1.
- [ ] **Toggle OFF**: same path → OFF. Login Items entry disappears. Settings flag returns 0.
- [ ] **External-source reconciliation**: with Latte off, manually remove "Latte" from System Settings → Login Items. Relaunch Latte. The toggle in General should reflect OFF (live status reconciled to settings cache).
- [ ] **Sign-out / sign-in test (optional, slow)**: enable, sign out, sign in. Latte should auto-launch.

#### EKCalendar list picker (commit `7decb84`)

- [ ] **Empty selection (default)**: Settings → Triggers → Calendar → "Watched calendars" disclosure shows "All calendars" badge. Behavior matches v1: every granted calendar fires the trigger.
- [ ] **Single calendar selected**: tick one calendar (e.g. "Work"). Disclosure header now shows "1 selected." Create a test event on the unticked calendar → cup does NOT activate when the event starts. Create a test event on the ticked calendar → cup activates per the existing Calendar trigger contract.
- [ ] **"Select all" button**: ticks every available calendar. Disclosure shows "(N) selected" where N = available calendars count.
- [ ] **"Use all calendars" button**: clears selection. Returns to default behavior.
- [ ] **Permission denied fallback**: if Calendar permission has not been granted, the picker section shows the explanatory copy ("Re-open this tab once Calendar permission is granted...") instead of an empty list.
- [ ] **Calendar deletion edge case** (slow): tick "Work" calendar, then delete it from Calendar.app. Re-open Settings — the picker should re-list current calendars without the deleted one. The persisted ID stays in `latte.calendarTrigger.calendarIDs` (harmless; the source filter ignores unknown IDs).

#### V2-10 cleanup (commit `05f8c2d`)

- [ ] No visible behavior change. `Theme.Colors.accentAwake` was an unused alias; removing it must compile and run identically.

### Coverage gate snapshot (post-S8b expansion)

Re-run after fix-first if any P1 surfaces:

```bash
xcodebuild test -scheme Latte -destination "platform=macOS,arch=arm64" -enableCodeCoverage YES
```

Target: 284/284 tests pass (S7.11 baseline 263 + 21 new across the 4 commits). Coverage gate PASS expected (no source-file deletions; new files exercised by their tests).

---

## Adapter exemption rationale

The following classes are excluded from the 80% coverage gate because they wrap live system services and require an interactive user / permission grant / hardware to exercise:

| Adapter | System service | Consumer covered via |
|---|---|---|
| `EKCalendarSource` | EventKit | `MockCalendarSource` |
| `NSWorkspaceSource` | NSWorkspace running-apps | `MockAppSource` |
| `INFocusSource` | Intents Focus state | `MockFocusSource` |
| `CoreWLANSource` | CoreWLAN + CoreLocation | `MockWiFiSource` |

`PowerAssertion` was originally on this list but was promoted to the gate after we found `IOPMAssertionCreateWithName` works in any test process without entitlements (see `Tests/PowerAssertionTests.swift`).
