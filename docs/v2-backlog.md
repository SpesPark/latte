# v2 Backlog

> Items deferred from v1.0 ship. Each entry: discovery context (which session surfaced it), rough scope, and ship gate.
> Created during S8 prep (2026-04-27). Append, never overwrite.
>
> **S8b research reshuffle (2026-04-27)**: Q3 trigger-priority research (Reddit, KYA GitHub issues, Amphetamine reviews, MacRumors) reordered post-v1.0 ship. Headline finding: visual menu-bar state (V2-01) is a **15-year category-standard UX gap** validated by KYA Issue #57; time-of-day/schedule trigger (V2-05, new) shows higher demand than EKCalendar list picker (V2-04). Per-Focus selection (V2-03) is confirmed-low-demand and stays deferred. Full research record: `memory/project_latte_session8b_research.md`.

**v1.0 expansion (S8b, 2026-04-27)**: owner approved "ship aggressively" — V2-01, V2-04, V2-10 promoted into v1.0 alongside two new features (Launch at Login, first-run onboarding wizard). v1.1+ ship order updated below.

**Shipped in v1.0** (originally in this backlog, no longer deferred):
- ✅ **V2-01** menu-bar awake visualization → commit `05f8c2d`
- ✅ **V2-04** EKCalendar list picker → commit `7decb84`
- ✅ **V2-10** `Theme.Colors.accentAwake` cleanup → commit `05f8c2d`

**Shipped in v1.0** (NEW, not previously backlog'd):
- ✅ Launch at Login (SMAppService) → commit `6109859`
- ✅ First-run onboarding wizard (3-step picker) → commit `2da1f3d`
- ✅ `latte://settings/<tab>` URL scheme + tab deep linking → commit `3b39ba8`
- ✅ `latte://demo/cup?fill=&accent=&awake=` URL scheme + DemoCupWindow → commit `ce69864`
- ✅ `LSMultipleInstancesProhibited` (single-instance forwarding) → commit `3b39ba8`
- ✅ `setActivationPolicy(.regular)` toggle for Settings/Demo windows → commits `3b39ba8`+`ce69864`
- ✅ `CoffeeCupView.size` parameter (default-preserves backward compat) → commit `ce69864`

**Shipped in v1.1** (S9, 2026-04-29):
- ✅ **V2-05** Time-of-day / schedule trigger — see entry below for details
- ✅ **C-1** Battery-aware mode (Amphetamine parity) — `Sources/Core/PowerSource.swift` + `AwakeManager.requireACForAwake`. Settings → General → "Sleep when on battery". Constraint enforced at manager input boundary; AC-unplug while awake auto-releases the assertion; explicit re-engage required when AC returns (no auto-resume). 11 new tests.
- ✅ **C-9** Pause-all triggers — `AwakeManager.triggersPaused` + popover top-row toggle. Trigger ON votes dropped while paused; OFF votes still flow so post-unpause state is clean. Manual activation explicitly outlives pause. 12 new tests.
- ✅ **A-1** About tab active assertion display — Settings → About now shows live State / Mode / Reason / Power rows backed by pure `AssertionStatusFormatter` helpers (14 tests). Surfaces `allowDisplaySleep` mode visibly so the user can verify which assertion type is held without checking `pmset -g assertions`.
- ✅ **V2-02** Calendar/WiFi watched-list immediate reflection — was effectively shipped during S8b (forms already called `pollOnce`/`evaluate` on commit), now formalised: `CalendarTrigger.reevaluateWatched()`, `WiFiTrigger.reevaluateWatched()`, `ScheduleTrigger.reevaluateWatched()` — surface-parity wrappers with `AppTrigger.reevaluateWatched()`'s S7.9 contract (running-state guard; no-op when stopped). 6 new tests verify the running-state guard + transition-emit behaviour.
- ✅ **B1** Keyboard shortcut for manual toggle (S9d, 2026-04-29) — Carbon `RegisterEventHotKey` (no entitlement, works in adhoc-signed/sandboxed apps) toggles `manager.toggle()` on `⌘⇧L`. `KeyboardShortcutCoordinator` with `HotKeyRegistrar` protocol + `MockHotKeyRegistrar` for tests. `SettingsKey.keyboardShortcutEnabled` (off by default). Toggle in Settings → General → "Toggle Latte with ⌘⇧L". 8 new tests.
- ✅ **B1.2** Custom keyboard-shortcut recorder (S12, 2026-04-30) — `KeyChord` Codable value type + `ReservedChord` system-only blocklist (⌘Q/W/C/V/X/Tab/Space). `HotKeyRegistrar` protocol gains `register(chord:handler:)` overload + `currentChord`; legacy `register(handler:)` kept as default-impl shim for backwards compatibility. `KeyboardShortcutCoordinator.@Published var chord` + `setChord` / `resetChord`. `SettingsKey.shortcutChord` (silent-default migration: nil/garbage → `.default`). `ShortcutRecorderField` SwiftUI wrapper around an `NSResponder`-based `NSView` (Spotlight-picker pattern; pure SwiftUI key capture isn't reliable on macOS 13). Settings → General gains a "Shortcut" `LabeledContent` row with the recorder + Reset button below the existing toggle. Reset disabled while on default chord. Validation: `hasRequiredModifier` + reserved-chord check, with inline red copy and the FSM staying in `recording` until valid. 14 new tests (7 KeyChord + 7 coordinator chord-management). Smoke 21 covers silent-default migration + Settings capture; chord-customisation interaction is owner manual smoke (handoff step 6). Spec: [docs/design/07-shortcut-recorder.md](design/07-shortcut-recorder.md).

**Shipped in v1.3** (S14, 2026-04-30 — same-day continuation of v1.2):
- ✅ **C-3** Activity history — new 4th Settings tab "Activity" with Charts framework (24h stacked bar by trigger + 14-day heatmap + Currently active list). `ActivityLogStore` actor persists trigger fire events (ON/OFF + structured reasonCode) to `~/Library/Application Support/Latte/activity-log.json` with 14-day ring buffer GC. `TriggerCoordinator` hooks at `handleVote` (organic) + `stop(_:)` (user-explicit, distinct `.userToggleOff` reason). **Privacy contract**: only `triggerId` + timestamp + ON/OFF + structured `ReasonCode` enum persisted — raw `TriggerVote.reason` strings (which carry SSID / app names / event titles) intentionally dropped at the boundary; "Currently active" UI list reads from in-memory `coordinator.activeVotes` only, never disk. App Store privacy label unchanged ("No Data Collected"). 426 → 442 tests (+16: 7 store + 1 schema privacy + 4 integration + 3 AwakeSegment.merge regression + 1 URL handler). Smoke 21 → 22 (`22-activity-log.sh` covers lazy-load contract + Activity tab capture + jq schema assertion). Spec: [docs/design/09-c3-activity-history.md](design/09-c3-activity-history.md).

**Shipped in v1.1** (S10, 2026-04-30 — S9-family follow-through):
- ✅ **Settings window resizable** — `.resizable` styleMask + `setContentSize` + `minWidth/minHeight`. Opens at default 460×360 but user can drag corners to grow; Form auto-scrolls so all four trigger sections fit. `setFrameAutosaveName` already in place remembers user's preferred size. Closes the S9d-tracked observation.
- ✅ **AppTrigger friendly Reason** — `emitOn` resolves bundle ids via `WorkspaceSource.displayInfo` so About → Status card reads "App: Zoom" / "App: Microsoft Teams" instead of raw bundle ids. Curated table (`us.zoom.xos` → "Zoom"), explicit `displayInfoLookup` overrides, and unmapped-id fallback to raw id. 3 new regression tests + 4 existing tests updated. Closes S9d-tracked debt.
- ✅ **Activate at launch** — closes the S2-vintage `SettingsKey.activateOnLaunch` deferred feature. New `AppEnvironment.activateOnLaunch` published flag + `applyActivateOnLaunchIfEnabled()` invoked from `LatteAppDelegate.applicationDidFinishLaunching` after `bootTriggers`. Three gates: flag ON + onboarding completed + manager currently asleep. Activates `.indefinite` with `reason: .launch` (first non-`.user` reason wired end-to-end). New Settings → General toggle + new smoke scenario `19-activate-on-launch.sh` (3 phases: ON / OFF / onboarding-incomplete). 7 new tests (4 binding mirror + 3 functional gating).
- ✅ **Simplify-pass cleanup** (chore, no behavior change) — code-reviewer agent surfaced `LatteLog.shortcut` consolidation, `ScheduleEntryRow` label commit on `.onChange` (was `.onSubmit` only — silently dropped on focus-loss), `CarbonHotKeyRegistrar` process-global state doc, and 3× `reevaluateWatched()` comment trims.

**Recommended ship order** (post v1.0):

| Window | Item | Rationale |
|---|---|---|
| ~~v1.1~~ ✅ | **V2-05** Time-of-day / schedule trigger | Shipped 2026-04-29 (S9) |
| ~~v1.1~~ ✅ | **C-1** Battery-aware mode | Shipped 2026-04-29 (S9.5) |
| ~~v1.1~~ ✅ | **C-9** Pause-all triggers | Shipped 2026-04-29 (S9.5) |
| ~~v1.1~~ ✅ | **B1** Keyboard shortcut for manual toggle (⌘⇧L) | Shipped 2026-04-29 (S9d) |
| v1.2 | **V2-06** External display trigger (NEW) | Lightweight, validated demand (KYA #235) |
| v1.2 | **B1.2** Custom keyboard-shortcut recorder — ✅ **SHIPPED in S12 (2026-04-30)** | v1.1 shipped fixed ⌘⇧L; v1.2 adds chord rebinding |
| v1.2 | **V2-11** Icon dark/tinted variants | Owner-side Icon Composer pass; cosmetic polish |
| v1.x | **V2-02** Calendar/WiFi watched-list immediate-edit | Polling cycle ≤60s makes it tolerable |
| v1.x | **V2-12** macOS 13/14/15 matrix smoke | Surfaced via TestFlight beta in S10 |
| defer | **V2-03** Per-Focus selection | Apple API limit + confirmed-low-demand |

---

## P1 candidates (real UX gaps, defer only because not v1.0-blocking)

### V2-01 — Menu-bar icon does not visualize awake state — ✅ **shipped in v1.0** (commit `05f8c2d`)

- **Surfaced**: S7.11 diagnostic note (after owner reported "활성화가 바로 안돼" for App trigger; integration tests proved activation happens within ~100 ms, so the perceived bug was an absent visual signal).
- **S8b research validation (2026-04-27)**: KYA Issue #57 ("really not as clear as caffeine") + KYA #192 (display remaining time) directly demand this. Caffeine's 15-year-old full-cup/empty-cup is the de facto standard. Promoted to v1.1 must-have.
- **Current behavior**: `MenuBarExtra("Latte", systemImage: ...)` is bound to the user-selected icon style only (`MenuBarIconStyle` enum: filled/outline/clock). It does not reflect `manager.isAwake`. Owner can only verify activation by opening the popover.
- **v2 design sketch**:
  - Approach A: introduce a paired "awake variant" SF Symbol per style (e.g., `cup.and.saucer.fill` ↔ `cup.and.saucer.fill` with a small filled-dot accessory; or swap to a steaming-cup glyph).
  - Approach B: tint the existing symbol via `accessibilityLabel` + `.symbolRenderingMode(.palette)` switching foreground color when awake.
  - Approach C: add a tiny "○ / ●" accessory next to the symbol via `Label`-style composition (richer, but only macOS 14+ has the icon-composition API).
- **Decision needed before build**: which approach. A is simplest; C is most readable; B is most lightweight.
- **Ship gate for v2**: visual diff verified across all 3 icon styles + both light/dark menu bar.

### V2-02 — Calendar/WiFi watched-list edits not immediate — ✅ **shipped in v1.1** (S9.6, 2026-04-29)

- **Surfaced**: S7.9 follow-up; deferred at end of S7-family review.
- **Original behavior**: AppTrigger had `reevaluateWatched()` so config-form edits flow into live votes within one render pass. Calendar (60 s polling) and WiFi (30 s polling) did not — owner had to wait one polling cycle for an add/remove to take effect.
- **Effective shipping**: by S8b owner-feedback the forms already called `pollOnce()`/`evaluate()` on commit, so the user-facing behavior was already correct. S9.6 formalises the surface: `CalendarTrigger.reevaluateWatched()`, `WiFiTrigger.reevaluateWatched()`, and (extended to v1.1) `ScheduleTrigger.reevaluateWatched()` are now public methods with the same S7.9 contract — running-state guard (no-op when stopped) + immediate evaluate when running. Forms switched to use the unified API. 6 new tests in `Tests/ReevaluateWatchedTests.swift` verify running/stopped behaviour and transition emission.

### V2-03 — Per-Focus mode selection — **deferred (confirmed low demand)**

- **Surfaced**: S4 implementation notes; reaffirmed in S7.5 design (`FocusTriggerConfigInfo` shows informational copy only).
- **Blocker**: Apple. `INFocusStatusCenter` does not expose stable third-party Focus identifiers. List-presence semantics are the v1 ceiling.
- **S8b research validation (2026-04-27)**: Q3 research confirmed zero verbatim user requests for per-Focus selection across Reddit, KYA issues, Amphetamine reviews, MacRumors. Latte's binary list-presence approach is acceptable to users.
- **Re-evaluate trigger**: any future macOS release (15.x, 16) that surfaces a stable per-Focus API. Until then, do not invest engineering time.

### V2-03b — Focus trigger reliable read (sandbox + Communication Notifications entitlement) — **NEW, deferred from v1.0 ship**

- **Surfaced**: S8b owner smoke (2026-04-27). Focus trigger code path is fully wired and permission grant succeeds, but `INFocusStatusCenter.focusStatus.isFocused` always reads `false` even when the user has an active macOS Focus mode. Owner log evidence:
  ```
  20:18:28 FocusTrigger.start
  20:18:28 evaluate currentlyActive=false isEnabled=true permission=granted configured=true
  ```
  (cup never activates; multiple Toggle OFF→ON cycles produce identical `currentlyActive=false`.)
- **Root cause**: macOS sandboxed apps need `com.apple.developer.usernotifications.communication` entitlement to read Focus state reliably. The 19:32 log entry — `DoNotDisturb error: App is missing Communication Notifications entitlement` — is the smoking gun.
- **Action in v1.0**: `FocusTrigger` is no longer registered with the coordinator (`AppEnvironment.registerDefaultTriggers` comments it out). Onboarding wizard and Settings → Triggers no longer show it. `Sources/Triggers/FocusTrigger.swift` is preserved (build artefact + tests stay green) so re-enabling is a one-line change.
- **Action when revisiting**:
  1. Apple Developer Program enrollment must be live (S8.5 gate).
  2. Provision `com.apple.developer.usernotifications.communication` entitlement on the App ID.
  3. Add to `Configuration/Latte.entitlements`.
  4. Uncomment `coordinator.register(FocusTrigger(...))` in `AppEnvironment.swift`.
  5. Re-run owner smoke against the entitled build to confirm `currentlyActive` reflects real state.
  6. Apple may flag the entitlement on App Store review with "Why does this caffeine app need Communication Notifications?" — prepare a justification (Latte uses Focus-mode state to decide whether to keep the Mac awake; no notifications are sent or received).
- **Effort**: ~1 h code (entitlement file + uncomment + re-test) + Apple Developer Program approval (~1-2 days).
- **Ship target**: v1.1 if Apple approves the entitlement. Otherwise drop Focus permanently; Calendar/App/WiFi already cover the core wedge.

### V2-04 — EKCalendar list picker — ✅ **shipped in v1.0** (commit `7decb84`)

- **Surfaced**: S7.5 (`CalendarTriggerConfigForm` shipped without it); also called out in S7-family handoff and SESSION_HANDOFF "Known issues" section.
- **Scope**: live `EKEventStore.calendars(for:)` enumeration + permission flow, multi-select picker UI, persistence as `[String]` of EKCalendar identifiers, `CalendarTrigger` filter applied to the polled events.
- **Effort**: ~4-6 h end to end (incl. permission re-prompt edge case + 6-8 tests).
- **Why demoted to v1.3** (S8b research): Q3 research showed time-of-day trigger (V2-05) has higher demand than calendar picker. Picker is a refinement for users with multiple mixed calendars (work + personal); does not move the needle for the median user. Calendar trigger already differentiates Latte from Amphetamine without it.

### V2-05 — Time-of-day / schedule trigger — ✅ **shipped in v1.1** (S9, 2026-04-29)

- **Surfaced**: S8b research (2026-04-27). Q3 trigger-priority study found this is the **second-highest unmet demand** after V2-01.
- **User signal**:
  - KYA Issue #189: *"Would it be possible to add a scheduler?"*
  - KYA Issue #161: separate scheduler request.
  - MacRumors thread #2405685: *"have my Mac awake from 10:15 am until 10:45 am..."*
  - Amphetamine ships time-of-day triggers.
- **Shipped scope**:
  - New `ScheduleTrigger: Trigger` (`Sources/Triggers/ScheduleTrigger.swift`) — id `"schedule"`, `clock` symbol, no permission required, 30s polling.
  - Pure value-type model: `Weekday` enum (Sun=1..Sat=7, aligned with `Calendar.weekday`), `TimeOfDay` (hour+minute, clamped, comparable), `ScheduleEntry` (UUID id, weekday set, start/end, optional label, isEnabled flag).
  - Same-day windows are half-open `[start, end)`. Midnight-crossing (`end < start`): late half matches starting day's weekday, early half matches yesterday's weekday — so a Mon 22:00–02:00 entry covers Mon night through Tue 02:00 only.
  - Persistence: `[ScheduleEntry]` JSON-encoded under `latte.scheduleTrigger.entries`; `latte.scheduleTrigger.enabled` Bool gate.
  - UI: `ScheduleTriggerConfigForm` in TriggersTab — per-entry: enable toggle, label TextField, `DatePicker` start/end, weekday chips (Mon..Sun display order). Add/remove entries inline. Reflects edits immediately via `trigger.reevaluate()` (no 30s poll wait).
  - Onboarding wizard description added (`schedule` case → "On a recurring time schedule").
- **Tests**: 28 new (`Tests/ScheduleTriggerTests.swift`). Covers TimeOfDay clamping/comparable, ScheduleEntry same-day/midnight-crossing/zero-length/empty-weekday/disabled/full-day, Codable round-trip, SettingsStore round-trip + corruption fallback, ScheduleTrigger ON/OFF transitions, no re-emit on repeated polls, overlapping-entry stable order, disabled no-op, start/stop with stream lifetime preserved (S7.11 invariant), persistence sanity. Total project: 309 → **337 tests, all PASS**.

### V2-06 — External display connected trigger — ✅ **SHIPPED in S11 (2026-04-30)**

- **Surfaced**: S8b research (2026-04-27). KYA Issue #235; also Amphetamine ships it.
- **User signal**: laptop-at-desk workflow — *"plugged into monitor → keep awake"* is a real pattern, especially for MacBook Air/Pro users who close the lid.
- **Shipped scope (S11)**: `DisplaySource` protocol + `NSScreenSource` adapter (`NSScreen.screens` filtered through `CGDisplayIsBuiltin`, observing `NSApplication.didChangeScreenParametersNotification`) + `MockDisplaySource` + `ExternalDisplayTrigger` registered as the 5th default trigger. Vote `wantsAwake=true` when ≥1 external display attached; `reason: "Display: <localizedName ?? External Display>"` mirrors S10 friendly format. Settings → Triggers → External Display section with live status row. Smoke scenario 20 covers the no-monitor branch automatically; "monitor attached" path covered by 9 unit + 2 coordinator tests + owner manual smoke (handoff step 7).
- **Effort actual**: 4 commits, ~398→409 tests (+11), smoke 19→20.
- **Out of scope (deferred to v1.3+)**: clamshell-aware refinement, per-display whitelist (UUID via `CGDisplayCreateUUIDFromDisplayID`), `LATTE_TEST_MOCK_DISPLAY_COUNT` env-var injection (decided against — production code stays free of test-only branches; physical-attach simulation is owner manual smoke territory).
- **Future polish (NSScreenSource debounce)** — adapter currently forwards every `didChangeScreenParametersNotification` raw; resolution-change-on-wake can fire several within milliseconds. The trigger's `lastVote == wantsAwake` guard already swallows same-state bursts, so this is theoretical only. If telemetry surfaces spurious flicker, add a 100 ms debounce in `NSScreenSource` before yielding to the continuation. Surfaced by S11 4th simplify-pass (2026-04-30).
- **Spec**: see [docs/design/06-display-trigger.md](design/06-display-trigger.md).

---

## P2 candidates (cleanup / hygiene)

### V2-13 — Extract per-trigger config forms out of `TriggersTab.swift` — ✅ **shipped in v1.2** (S13, 2026-04-30)

- **Surfaced**: S11 4th simplify-pass (2026-04-30). File was 958 lines, over the 800 ceiling.
- **Outcome**: 6 forms (`AppTriggerConfigForm` + `AppRow` / `WiFiTriggerConfigForm` / `CalendarTriggerConfigForm` + `CalendarPickerRow` / `FocusTriggerConfigInfo` / `ScheduleTriggerConfigForm` + `ScheduleEntryRow` + `WeekdayChip` / `ExternalDisplayTriggerConfigForm`) moved to a single sibling file `Sources/UI/Settings/TriggerConfigForms.swift` (799 LOC). `TriggersTab.swift` now 161 LOC (TriggersTab + TriggerSection dispatcher only). Forms changed from `private struct` to default-internal access; helpers (`AppRow`, `CalendarPickerRow`, `ScheduleEntryRow`, `WeekdayChip`) stay file-private to the new file. Behaviour unchanged: 423 tests still PASS.
- **Decision note**: kept to a single extracted file rather than 6 per-trigger files because the xcodeproj is explicit-reference (no synced groups) — each new file costs 4 pbxproj edits. Single-file split is the minimum churn that gets both files under the 800 ceiling. Future re-split if either file drifts past the ceiling again.

### V2-10 — Drop `Theme.Colors.accentAwake` static alias — ✅ **shipped in v1.0** (commit `05f8c2d`)

- **Surfaced**: S6 design polish session (and re-noted in S7-family handoff).
- **Original state**: `Theme.Colors.accentAwake` was a 1-line forwarder. Confirmed 0 call sites in source/tests at S8b.
- **Outcome**: alias deleted; no migration needed.

### V2-11 — Icon Composer / dark / tinted variants

- **Surfaced**: S7.11 (only single light variant landed). 05-icon-spec §6.1 / §7 lists these as optional follow-ups.
- **Action**: open `icon-master-1254.png` in Icon Composer (Xcode 15+), generate dark + tinted layers, drop into `AppIcon.appiconset/`.
- **Effort**: ~1 h owner-side. Pure cosmetic; not gating ship.

### V2-12 — macOS 13/14/15 matrix smoke

- **Surfaced**: S7. Deferred to S9 (TestFlight beta).
- **Reason**: dev box is macOS 26 Tahoe only. TestFlight gives multi-OS coverage for free via beta testers.
- **Action**: gather feedback from 3-5 beta testers across the 3 prior macOS majors. Triage any P1 surfaced, defer P2/P3.

### V2-30 — Cross-project macOS smoke harness — **SHIPPED in S8c (2026-04-28)**

- **Status**: 🟢 v0.1 operational. Latte's deferred D/E/F smoke now runs via harness in <1 min. 5 scenarios + 1 marketing-prep PASS.
- **Location**: `~/dev/smoke-harness/`
- **Architecture (built)**:
  ```
  ~/dev/smoke-harness/
  ├── run.sh                       # entry: takes --project <path>
  ├── lib/
  │   ├── log.sh                   # smoke_info/warn/error/ok/step + smoke_record JSONL
  │   ├── reset_prefs.sh           # defaults delete + tccutil reset
  │   ├── launch_app.sh            # open + wait via lsappinfo
  │   ├── quit_app.sh              # AppleScript quit + SIGTERM fallback
  │   ├── capture_screenshot.sh    # full-screen, fail-soft when no permission
  │   ├── capture_menubar.sh       # top 32px strip
  │   ├── read_log.sh              # log show predicate wrapper
  │   ├── verify_assertion.sh      # pmset -g assertions check
  │   ├── defaults_helper.sh       # read/write user defaults
  │   └── appearance.sh            # Light/Dark mode toggle
  ├── templates/config.yml.template
  └── README.md
  ```
- **Latte's per-project layout**:
  ```
  Latte/.smoke/
  ├── config.yml                   # bundle_id, app_path, screenshots_dir
  ├── scenarios/
  │   ├── 01-onboarding.sh
  │   ├── 02-toggle-cycle.sh
  │   ├── 03-icon-states.sh        (auto-captures 6 menubar PNGs across styles × modes)
  │   ├── 04-launch-at-login.sh
  │   ├── 05-calendar-picker.sh    (smoke-F empty-selection edge case)
  │   └── 06-marketing-prep.sh     (sets demo state for owner manual capture; auto-captures onboarding welcome)
  ├── artifacts/                   (gitignored)
  └── reports/                     (gitignored)
  ```
- **Run**: `~/dev/smoke-harness/run.sh --project ~/Documents/Claude/Projects/Latte`
- **What got fixed during S8c (fix-first per memory feedback)**:
  - `pgrep -f bundle_id` → `lsappinfo info -only pid -app bundle_id` (process name ≠ bundle id on macOS)
  - `screencapture` exit-on-failure → fail-soft warn (Screen Recording permission optional)
  - Scenario 5 false-positive alive check fixed
  - Python plistlib import failure (homebrew 3.14 expat ABI mismatch) → pure bash + xxd
- **Still owner-only**: Calendar TCC prompt, SMAppService roundtrip, Apple Dev entitlement install. macOS sandboxing limits automation here permanently.
- **Next app to wire**: copy `~/dev/smoke-harness/templates/config.yml.template`, write 3-5 scenarios. ~30 min.

---

---

## Pending owner-revisit (decided as default in S8, may change later)

### V2-20 — Bundle ID prefix revisit

- **Decided in S8 (2026-04-27)**: `com.parkbyeongjun.latte` as default reverse-DNS based on owner's name.
- **Why deferred**: owner asked to ship with a sensible default and revisit later. No domain ownership was required for the default choice.
- **When to revisit**: before App Store Connect record creation (Phase E). Once submitted to App Store, bundle ID is **immutable** for the app's lifetime — Apple does not allow renaming. Final lock-in is at submission.
- **Alternatives considered**:
  - `com.hightempier.latte` — based on owner's gmail handle. Reasonable nickname-style.
  - `com.bjpark.latte` / `kr.bjpark.latte` — shorter; needs owner-controlled domain (`bjpark.com` / `bjpark.kr`) to be defensible.
  - `app.latte.mac` / `com.latte.app` — needs owner to buy `latte.app` or `latte.com` domain (`latte.app` is currently registered; `.app` TLD requires HTTPS).
- **Action when revisiting**: re-run the same sweep done in S8 — `project.yml` (3 spots), `Sources/Core/{Logging,PowerAssertion,SettingsStore}.swift` (3 spots), `docs/design/{01-PRD,02-architecture,04-data-model}.md`, `docs/QA_LOG.md`, `docs/site/privacy.html`, `docs/store/*-url.txt`. Single grep: `grep -rn "com.parkbyeongjun.latte" .`. Re-run `xcodegen generate` + full test suite.

### V2-21 — Git author identity revisit

- **Decided in S8 (2026-04-27)**: `git config --global user.email "hightempier18@gmail.com"` + `git config --global user.name "박병준"`.
- **Why deferred**: owner asked to ship with a sensible default and revisit later. Past S7-family commits (8 commits, `8592098`..`f1888dc`) plus the docs-only `87d1eab` remain authored under the system `parkbyeongjun@bagbyeongjun-ui-MacBookAir.local` username — **not rewritten** because rewriting published commit history is destructive and out of scope.
- **When to revisit**: before first push to a public GitHub repo (Phase B1 deployment, or earlier if owner wants to push the private repo to GitHub). For App Store Connect, the git author has no impact — Apple only cares about the App Store Connect account email + the developer team.
- **Action when revisiting**: just re-run `git config --global user.email <new>` + `git config --global user.name <new>`. Future commits pick it up; past commits stay as-is.

### V2-22 — GitHub Pages URL / hosting revisit

- **Decided in S8 (2026-04-27)**: `bj-park` GitHub username + `latte` repo name. URLs default to `https://bj-park.github.io/latte/` and `https://bj-park.github.io/latte/privacy.html`.
- **Why deferred**: owner asked to ship with a sensible default and revisit later. The actual `bj-park/latte` repo on GitHub has not been created yet — these URLs are aspirational until Phase B1 GitHub Pages setup runs.
- **When to revisit**:
  - Before App Store submission (Phase E). The Privacy URL **must** return HTTP 200 at App Store submission — verify with `curl -sI <url>` immediately before submitting.
  - If owner wants to split site into a separate `latte-site` repo (cleaner separation; `docs/site/README.md` Option B describes this).
  - If owner buys a custom domain (e.g., `latte.app`, `getlatte.app`) — update `docs/site/CNAME` (create new), update DNS, update `docs/store/{support,marketing,privacy}-url.txt`.
- **Action when revisiting**: sweep `bj-park` and `latte` references the same way as V2-20 — files involved are `docs/site/README.md`, `docs/store/{support,marketing,privacy}-url.txt`. The HTML in `docs/site/index.html` + `privacy.html` does not embed the URL itself, so they don't need touching unless adding a `<link rel="canonical">` tag for SEO.

---

## Won't-do (intentional non-goals)

- **Telemetry / analytics SDK** — PRD §7.4 explicitly forbids in v1; no plan to revisit until justified by support load.
- **iCloud sync of trigger settings** — out of v1 scope; would require CloudKit container + multi-device conflict resolution. Re-evaluate post-v1.0 ship.
- **Cross-device (iOS companion)** — gated on Year-1 net revenue ≥ ₩2,000만 per PRD §6.7. Not even on the v2 list yet.
