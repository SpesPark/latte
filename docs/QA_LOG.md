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

## Adapter exemption rationale

The following classes are excluded from the 80% coverage gate because they wrap live system services and require an interactive user / permission grant / hardware to exercise:

| Adapter | System service | Consumer covered via |
|---|---|---|
| `EKCalendarSource` | EventKit | `MockCalendarSource` |
| `NSWorkspaceSource` | NSWorkspace running-apps | `MockAppSource` |
| `INFocusSource` | Intents Focus state | `MockFocusSource` |
| `CoreWLANSource` | CoreWLAN + CoreLocation | `MockWiFiSource` |

`PowerAssertion` was originally on this list but was promoted to the gate after we found `IOPMAssertionCreateWithName` works in any test process without entitlements (see `Tests/PowerAssertionTests.swift`).
