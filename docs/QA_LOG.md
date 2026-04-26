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

- [ ] Settings → General → Appearance → switch between 5 presets (espresso, caramel, mocha, latte, noir).
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
- [ ] After quit, `pmset -g assertions | grep -i com.example.latte` returns nothing (no leaked assertion).
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

- [ ] **Fresh install behavior** (delete the Latte preferences before re-launching, e.g. `defaults delete com.example.latte`): App trigger config form opens with **empty** watched list and the new empty-state copy. None of Zoom / Teams / Discord / etc. appear pre-populated unless installed.
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

## Adapter exemption rationale

The following classes are excluded from the 80% coverage gate because they wrap live system services and require an interactive user / permission grant / hardware to exercise:

| Adapter | System service | Consumer covered via |
|---|---|---|
| `EKCalendarSource` | EventKit | `MockCalendarSource` |
| `NSWorkspaceSource` | NSWorkspace running-apps | `MockAppSource` |
| `INFocusSource` | Intents Focus state | `MockFocusSource` |
| `CoreWLANSource` | CoreWLAN + CoreLocation | `MockWiFiSource` |

`PowerAssertion` was originally on this list but was promoted to the gate after we found `IOPMAssertionCreateWithName` works in any test process without entitlements (see `Tests/PowerAssertionTests.swift`).
