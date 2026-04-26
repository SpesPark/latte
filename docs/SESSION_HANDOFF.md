# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 7 + 7.5 + 7.6 + 7.7 + 7.8 + 7.9 of ~10 (six S7-family sessions same calendar day) |
| **Theme** | Test coverage + QA gate (S7); Per-trigger config UI (S7.5); UX rewrite after owner smoke (S7.6); App trigger friendly names (S7.7); pickable filter + installed-only seed (S7.8); trigger lifecycle / watched-list reevaluate (S7.9) |
| **Date** | 2026-04-26 |
| **Status** | ✅ Completed. 255/255 tests passing. S7 cleared the 80% coverage gate on `Sources/Core/**` and `Sources/Triggers/**` (live-system adapter classes excluded; rationale codified in `02-architecture.md` §13 v0.9 + `docs/QA_LOG.md`). S7.5 landed Phase 1.5.A — Settings → Triggers now offers an inline configuration form per trigger. S7.6 owner smoke surfaced two defects (P1 state-mismatch + P2 UX); both fixed by retiring the DisclosureGroup-with-Toggle-in-label structure in favor of a Section-per-trigger layout. S7.7 owner re-smoke against S7.6 build surfaced one defect (P2: App trigger row showed raw bundle IDs + no purpose copy); fixed by extending `WorkspaceSource` with `displayInfo(for:)`, curated displayName table, and rewriting `AppTriggerConfigForm` to render real app icons + friendly names. **S7.8 owner re-smoke against S7.7 build surfaced three connected complaints — pre-loaded curated defaults populate apps the owner doesn't have installed; "Add from running apps" Menu items show names without icons; the same Menu lists every running process. Fixed at the root: `WorkspaceSource` gains `pickableRunningBundleIDs` (filters `.regular` activation policy + excludes self) and `isInstalled(_:)`; `AppTrigger.init` runs a one-shot installed-only curated seed gated on the new `hasSeededAppDefaults` flag (idempotent across re-launches, respects users who explicitly cleared their list); legacy "fall back to all 6 curated when raw is empty" getter behaviour removed; UI Menu items render with real app icons or SF Symbol category fallback (`video.fill` / `bubble.left.and.bubble.right.fill`).** EKCalendar picker and per-Focus selection remain deferred as Phase 1.5.B / Apple-API-blocked respectively. |

### What was accomplished

1. **Coverage baseline**
   - `xcodebuild test -enableCodeCoverage YES` → `xcrun xccov view --report --json` → per-file analysis script (in `/tmp/Latte_S7_round*.xcresult`).
   - Initial 4 gaps identified:
     - `Core/SettingsStore` 75.2% — never exercised `double` accessors or any "wrong-type-stored" fallback path.
     - `Core/PowerAssertion` 29.6% — only the Mock had been exercised; real IOKit class was untouched by tests.
     - `Triggers/WiFiTrigger` 60.2% — `start()`/`stop()`/`requestPermissionIfNeeded()`/setters never called.
     - `Triggers/CalendarTrigger` 52.0% — same pattern.

2. **Gap-closing tests** (3 files modified, 1 new)
   - `Tests/SettingsStoreTests.swift` (+6 tests): `testDoubleRoundTrip`, `testBoolTypeMismatchFallsBackToDefault`, `testStringTypeMismatchReturnsNil`, `testIntegerTypeMismatchFallsBackToDefault`, `testDoubleTypeMismatchFallsBackToDefault`, `testDataTypeMismatchReturnsNil`. Both `InMemory` and `UserDefaults` impls run them via the parametrized `SettingsStoreContractTests` base — so each test fires twice (12 new test runs).
   - `Tests/PowerAssertionTests.swift` (NEW, 6 tests): direct tests against the real `PowerAssertion`, exercising `IOPMAssertionCreateWithName` / `IOPMAssertionRelease` from the test process. Covers initial state, IOKit type-key distinction (`kIOPMAssertionTypeNoDisplaySleep` vs `kIOPMAssertionTypeNoIdleSleep`), activate→deactivate, idempotent re-activate with same mode, mode-change replacement, and inactive-deactivate no-op.
   - `Tests/WiFiTriggerTests.swift` (+4 tests): `testIsEnabledSetterPersists`, `testPermissionStatusReflectsSource`, `testStartEvaluatesImmediatelyAndStopCancels`, `testRequestPermissionIfNeededDelegatesToSource`.
   - `Tests/CalendarTriggerTests.swift` (+4 tests): `testIsEnabledSetterPersists`, `testPermissionStatusReflectsSource`, `testStartPollsAndStopCancels`, `testCalendarSettingsTypedSetters` (covers clamping at write-time for lead/trailing minutes, both bounds).

3. **Coverage result** (final, on `/tmp/Latte_S7_round3.xcresult`)

   | File | Cov% |
   |---|---|
   | Core/AwakeDuration | 100.0% |
   | Core/AwakeManager | 94.1% |
   | Core/Logging | 100.0% |
   | Core/PowerAssertion | 87.3% |
   | Core/SettingsStore | 100.0% |
   | Triggers/Trigger | 82.8% |
   | Triggers/TriggerCoordinator | 92.3% |
   | Triggers/AppTrigger | 98.5% |
   | Triggers/CalendarTrigger | 98.8% |
   | Triggers/FocusTrigger | 97.9% |
   | Triggers/WiFiTrigger | 96.5% |

   **GATE: PASS.**

4. **Documentation**
   - `docs/QA_LOG.md` (NEW) — coverage snapshot, owner-side smoke checklist (menu-bar UI / custom duration / coffee tone / icon style / triggers / quit hygiene), adapter exemption rationale, macOS-version matrix (deferred to S9 TestFlight).
   - `02-architecture.md` v0.8 → **v0.9**: §13 entry codifies the gate scope, the adapter-exemption list, and the PowerAssertion promotion.
   - `ROADMAP.md` v0.8 → **v0.9**: row 7 (Test coverage + QA) now 🟢 Done; row 8 marked 🟡 Next.

### Test count

178 → 195 → 227 → **229** (+34 net since S6 close: 12 SettingsStore parametrized doubles, 6 PowerAssertion, 8 WiFi, 6 Calendar in S7; +1 each for `AppTrigger.runningBundleIDs` and `WiFiTrigger.currentSSID` passthrough in S7.5). All passing.

### S7.5 added (Phase 1.5.A — per-trigger config UI)

5. **Trigger passthrough accessors** — `AppTrigger.runningBundleIDs: [String]` (delegates to `WorkspaceSource.runningBundleIDs`) and `WiFiTrigger.currentSSID: String?` (delegates to `WiFiSource.currentSSID`). Lets the Settings UI offer "Add from running apps" / "Add current network" without reaching past the trigger's public surface.

6. **TriggersTab rewrite** — each row is now a `DisclosureGroup`. Tapping the row expands a per-trigger config form, dispatched on `trigger.id`:
   - **`AppTriggerConfigForm`** — bundle-ID list with per-row remove, free-form text-field add (sanitized via `AppTriggerDefaults.sanitize`), and a nested `DisclosureGroup` showing current running apps not yet in the watched list.
   - **`WiFiTriggerConfigForm`** — radio-style mode picker (on-list vs inverse), SSID list with per-row remove, manual add (validated to ≤32 UTF-8 bytes), and a one-tap "Add current network: <ssid>" button when a current SSID exists and isn't already on the list.
   - **`CalendarTriggerConfigForm`** — lead/trail steppers (0–15 min) + "Exclude all-day events" toggle. Inline note explains that calendar-list selection ships in Phase 1.5.B (needs EventKit live access).
   - **`FocusTriggerConfigInfo`** — informational paragraph; `INFocusStatusCenter` doesn't expose stable per-Focus IDs to third parties in v1.

7. **Footer copy** updated from "Per-trigger configuration … lands in a future update" to a description of the new capability.

S7.5 architectural note: the `Trigger` protocol stays untouched. The two new accessors are concrete-class extensions, not protocol requirements — `TriggerCoordinator` and other consumers see no change.

### S7.6 added (UX rewrite — fix-first after owner smoke)

8. **`TriggersTab` rewritten end-to-end** — DisclosureGroup-with-Toggle-in-label retired; replaced with `Form { ForEach { TriggerSection } }`. Each `TriggerSection` is a standard macOS `Section` with:
   - **header**: icon + name + (live voting dot when applicable)
   - **single Toggle("Enable") row** — standalone control, no click-target collision possible
   - **inline config form** rendered conditionally on `isOn` (no separate `isExpanded` state)
   - **footer**: live "Voting awake — …" reason or permission-status hint copy

   Net effect: the P1 subtitle/Toggle state-sync bug logged as `S75-DEF-01` becomes structurally impossible (the Toggle is the only UI carrying enabled-state — there is no longer a parallel `subtitle` reading `trigger.isEnabled` from a different source).

9. **`AppTriggerConfigForm`** — "Add from running apps" went from a nested `DisclosureGroup` to a SwiftUI `Menu` (each candidate bundle ID is a `Button`). Eliminates the second nested-disclosure hit-target ambiguity.

10. **`WiFiTriggerConfigForm`** — mode picker upgraded from `.radioGroup` to `.segmented` style for a clearer binary on-list / inverse choice.

11. **Outer ForEach** — `id: \.offset` → `id: \.id`. SwiftUI now tracks each `TriggerSection` by trigger identifier rather than ordinal position; safer if the trigger registration order ever changes.

S7.6 has zero protocol or model changes. `Sources/Core/**`, `Sources/Triggers/**`, `Trigger`, `TriggerCoordinator`, `AppEnvironment`, `SettingsStore` — all untouched. Pure SwiftUI restructure of one file.

### S7.7 added (App trigger UX friendly names — fix-first after second owner smoke)

12. **`AppDisplayInfo` Sendable struct** — bundle ID + display name + optional PNG-encoded icon data. Defined alongside `WorkspaceSource` in `Sources/Triggers/AppTrigger.swift`. PNG bytes (not `NSImage`) so the type stays `Sendable` and the protocol stays platform-agnostic; the UI converts via `NSImage(data:)` at render time.

13. **`WorkspaceSource.displayInfo(for:)` requirement** — new method on the existing live-system adapter abstraction. Mockable by all consumers; the `Trigger` protocol itself is unchanged.

14. **`NSWorkspaceSource.displayInfo(for:)`** — real adapter implementation. Resolution priority:
    1. Currently running → `NSRunningApplication.localizedName` + `.icon` (downsampled to 64pt via private `pngData(from:)`).
    2. Installed bundle → `NSWorkspace.urlForApplication(withBundleIdentifier:)` + `Bundle.localizedInfoDictionary` / `infoDictionary` for the name + `NSWorkspace.icon(forFile:)` for the icon.
    3. Curated default name → `AppTriggerDefaults.displayName(for:)` (covers Zoom, Microsoft Teams, Webex, Discord, Slack, Google Meet — the same 6 IDs already in `AppTriggerDefaults.bundleIDs`).
    4. `nil`.

    Sits inside the `NSWorkspaceSource` class which is already on the adapter exemption list (§13 v0.9), so the new method + its inner closures + the private `pngData(from:)` helper are also exempt from the 80% gate.

15. **`MockWorkspaceSource.displayInfoLookup: [String: AppDisplayInfo]`** — stubbable per-bundle-ID override dict for tests; falls through to the curated table when no override is set, matches `nil` for unknown IDs.

16. **`AppTrigger.displayInfo(for:)` passthrough** — thin wrapper so `Sources/UI/Settings/TriggersTab` never reaches into the source layer directly.

17. **`AppTriggerConfigForm` rewrite** —
    - **Purpose copy** at the top: "Latte stays awake while any of these apps are running. Add the apps that must keep your Mac active — video meetings, presentations, long-running tools."
    - Each row uses new private `AppRow` view: real app icon (22pt) + friendly display name (body font, top) + bundle ID (caption font, tertiary, bottom — only shown when distinct from displayName).
    - "Add from running apps" Menu items now show display names sorted case-insensitively rather than raw bundle IDs.
    - Manual bundle-ID textfield collapsed under a `DisclosureGroup` labelled "Advanced — add by bundle ID" (closed by default). The DisclosureGroup label is purely a non-interactive caption + icon (S7.6 lesson respected — no Toggles or other tappable controls in the label).

18. **Tests** — `Tests/AppTriggerTests.swift` gains 6 new tests covering: the curated displayName mapping (all 6 entries), unknown ID returns nil, Mock fallback to curated table, Mock explicit override priority, Mock nil for unmapped IDs, AppTrigger passthrough composition. **229 → 235 tests, all pass. Coverage gate still PASS.**

S7.7 introduces one small additive protocol extension (`displayInfo(for:)` on `WorkspaceSource`); the `Trigger` protocol, `TriggerCoordinator`, persistence, and all other architecture layers are unchanged. Friendly resolution is purely a render-time concern — `SettingsStore.appTriggerBundleIDs` still stores `[String]` of bundle IDs.

### S7.8 added (App trigger pickable filter + installed-only seed — fix-first after third owner smoke)

19. **`WorkspaceSource.pickableRunningBundleIDs: [String]`** — second protocol extension (alongside `displayInfo(for:)` from S7.7). UI-only filter: real impl filters `runningApplications` to `activationPolicy == .regular` (Dock-visible apps) and excludes the current process via `Bundle.main.bundleIdentifier`. The unfiltered `runningBundleIDs` stays as-is — trigger lifecycle (start-snapshot intersection + `observeLifecycle` notifications) keeps tracking `.accessory` apps if the user manually adds one via Advanced.

20. **`WorkspaceSource.isInstalled(_:) -> Bool`** — third protocol extension. Real impl checks `NSWorkspace.urlForApplication(withBundleIdentifier:) != nil`. Used by `AppTriggerDefaults.installedDefaults(in:)` to filter the seed list.

21. **`SettingsKey.hasSeededAppDefaults`** — new persistence flag. Once set (after first-launch seed), prevents re-seeding even if the user clears their watched list — explicit-empty stays empty.

22. **`AppTrigger.seedInstalledDefaultsIfNeeded()`** — runs in `AppTrigger.init` (one place; not a public API). Logic: if flag unset and raw watched list is empty, write `AppTriggerDefaults.installedDefaults(in: source)` (curated 6 filtered to those `isInstalled`) and set the flag. If raw is non-empty (existing user, or test fixture set the list directly), skip seeding and just set the flag. Fully idempotent.

23. **Removed legacy fallback** — `SettingsStore.appTriggerBundleIDs` getter no longer returns all 6 curated IDs when raw is empty. Empty raw now means "watch nothing." The seeding mechanism is the single source of curated default population.

24. **`AppTriggerDefaults.symbolHint(for:)`** — new SF Symbol category mapping (video-call apps → `video.fill`, chat apps → `bubble.left.and.bubble.right.fill`). Fallback when neither a running-app icon nor an installed-bundle icon resolves.

25. **`AppTriggerDefaults.installedDefaults(in:)`** — `@MainActor` helper filtering `bundleIDs` by `source.isInstalled(_:)`.

26. **TriggersTab UI**:
    - `AppTriggerConfigForm.runningAppsMenu` uses `pickableRunningBundleIDs` (was `runningBundleIDs`). Items render via SwiftUI `Label { Text(name) } icon: { Image(nsImage:) }` when icon data is available; falls back to `Label(name, systemImage: symbolHint)` for curated category match; falls back to `Text(name)` only when neither icon nor symbol hint is available.
    - `AppRow.iconView` gains the same SF Symbol fallback layer (real icon → symbolHint → generic `app.fill`).
    - Empty-state copy refreshed: "No apps configured yet. Use 'Add from running apps' below to add the apps you want Latte to keep awake — or use 'Advanced' for an app that isn't running right now."

27. **Mock helpers**: `MockWorkspaceSource.pickableOverride: [String]?` and `installedOverride: Set<String>?` for explicit test control. Both default to using `runningBundleIDs` when nil.

28. **Tests** — 14 new tests covering: `symbolHint(for:)` × 2 (curated mapping + nil for unknown), Mock `isInstalled` × 3 (default to running, displayInfoLookup keys, override), `installedDefaults` × 2 (filter + empty when none installed), first-launch seeding × 4 (installed-only seed, empty seed sets flag, second-launch no-op, existing config skip), pickable × 3 (Mock default, override, AppTrigger passthrough). `testRequiredKeysExist` extended with the new SettingsKey. **235 → 249 tests, all pass. Coverage gate still PASS (AppTrigger 98.89% — up from 98.68% in S7.7 because the new tests cover the seeding logic; all gated files ≥80%).**

S7.8 introduces two additive protocol requirements + one persistence flag. The `Trigger` protocol itself, `TriggerCoordinator`, `AwakeManager`, and other architecture layers are unchanged.

### S7.9 added (Trigger lifecycle: Toggle OFF + watched-list edit deactivate the cup — fix-first after fourth owner smoke)

29. **`TriggerSection` Toggle now drives the live trigger lifecycle** — onChange spawns a `Task { @MainActor in … }` that calls `coordinator.start(trigger)` on ON or `coordinator.stop(trigger.id)` on OFF. Previously only `trigger.isEnabled = newValue` was set, leaving the live observation running and stale ON votes in the FSM. **Universal across all 4 triggers.**

30. **`AppTrigger.watchedSet` instance var** — replaces the closure-captured `let watched = …` snapshot. Set in `start()` from `settings.appTriggerBundleIDs`, cleared in `stop()`. `handleLaunch(bundleID:)` / `handleTerminate(bundleID:)` simplified to read it (lifecycle closures no longer carry the watched set as a parameter).

31. **`AppTrigger.reevaluateWatched()` public method** — re-reads `settings.appTriggerBundleIDs`, diffs against `watchedSet`, recomputes `matchingRunning = running ∩ watched`, and emits vote ON / OFF / re-emit-ON-with-fresh-reason on transition. Idempotent when nothing changed; no-op when the trigger is stopped (the next `start()` will read fresh data anyway). Called by `AppTriggerConfigForm.commit(_:)` after every add / remove so the live vote stream tracks the watched-list edits within one render pass.

32. **Stream lifecycle hardening** — removed `continuation.finish()` from `AppTrigger.stop()`. Finishing the `AsyncStream` permanently closed it, so any future `start()` could not deliver votes (consumer's `for await` would terminate, future `yield`s would silently drop). Stream is now long-lived for `AppTrigger`'s lifetime; the coordinator cancels its consumer Task on stop and recreates one on start, both subscribing to the same stream. Regression-tested by the new `testRestartAfterStopReEmitsInitialSnapshot`.

33. **Tests** — 6 new tests covering: reevaluate emits ON when adding a new match, OFF when removing the last match, no-op when settings unchanged, re-emits ON when set changes but stays non-empty (so vote reason updates), no-op when called while stopped, and stop+start cycle preserves the stream. Existing `testStopCancelsObservation` comment refreshed for the new lifecycle semantics. **249 → 255 tests, all pass. Coverage gate still PASS (AppTrigger 98.06% — slight drift from S7.8's 98.89% reflects the new reevaluate branches; well above the 80% gate).**

S7.9 introduces one small public method addition (`AppTrigger.reevaluateWatched()`) and one UI rewiring (Toggle → coordinator). The `Trigger` protocol surface, `TriggerCoordinator`, `AwakeManager`, persistence, and other layers are unchanged. WiFi / Calendar / Focus likely have the same "watched-list mutation doesn't reach the live trigger" pattern; deferred to S7.10 if owner re-smoke surfaces it. The Toggle fix already covers "disable this trigger entirely" universally.

### What's NOT done (intentional)

- **Owner-side manual smoke checklist** in `docs/QA_LOG.md` is checked-in but unchecked — Claude cannot drive the menu-bar UI. Owner runs through this (including the §S7.7 + §S7.8 + §S7.9 addendums covering App-trigger friendly names, pickable filter, installed-only seed, and trigger lifecycle / watched-list edit) and ticks lines (or logs defects in the same doc) before S8 starts in earnest. Gate for S8 is: zero P1 items in QA_LOG.
- **macOS 13/14/15 matrix smoke** — deferred to S9 (TestFlight). Dev box is macOS 26 only.
- **`AwakeManager` coverage** sits at 94.1% — the remaining 6% is mostly the two log-only paths in the IOKit power-source observer; not worth contorting tests to chase. Documented in 02 §13 v0.9.
- **`Trigger` protocol file** at 82.8% — the 5 missed lines are default-impl fallbacks for protocols that are always overridden by concrete types. Right at the gate; do not "improve" with pointless override tests.

---

## Decisions still pending owner approval

- **None blocking S8.** S7 introduced no architectural changes — only tests and a documentation/exemption clarification. Owner sign-off is not required to proceed with S8 setup, but **is** required before submission (G6).

---

## Known issues / debt

- **`Theme.Colors.accentAwake` static alias** still lingering as a 1-line forwarder to `CoffeeAccent.default.color`. Drop it in S10 cleanup pass; not worth the diff churn now.
- **`docs/QA_LOG.md` smoke checklist is unchecked** — see above. This is the only S7→S8 prerequisite.
- **EKCalendar list picker (Phase 1.5.B)** — Calendar config form ships with steppers + all-day toggle but no calendar-list selection (would need live `EKEventStore.calendars(for:)` + permission grant). Open as a follow-up; not S8-blocking.
- **Per-Focus selection** — Apple-API-blocked. Reassess when `INFocusStatusCenter` exposes stable third-party Focus identifiers.

---

## Files changed this session

```
S7 (commit 8592098):
A  Tests/PowerAssertionTests.swift
M  Tests/SettingsStoreTests.swift
M  Tests/WiFiTriggerTests.swift
M  Tests/CalendarTriggerTests.swift
A  docs/QA_LOG.md
M  docs/design/02-architecture.md   (v0.9, §13 entry)
M  ROADMAP.md                        (v0.9; row 7 → done, row 8 → next)
M  docs/SESSION_HANDOFF.md

S7.5 (commit c9042c0):
M  Sources/Triggers/AppTrigger.swift          (+ runningBundleIDs accessor)
M  Sources/Triggers/WiFiTrigger.swift         (+ currentSSID accessor)
M  Sources/UI/Settings/TriggersTab.swift      (DisclosureGroup rewrite + 4 config forms)
M  Tests/AppTriggerTests.swift                (+ testRunningBundleIDsPassThrough)
M  Tests/WiFiTriggerTests.swift               (+ testCurrentSSIDPassThrough)
M  ROADMAP.md                                 (v0.10)
M  docs/design/02-architecture.md             (v0.10)
M  docs/SESSION_HANDOFF.md

S7.6 (commit 47fc8ab):
M  Sources/UI/Settings/TriggersTab.swift      (Section-per-trigger rewrite — DisclosureGroup retired)
M  ROADMAP.md                                 (v0.11)
M  docs/design/02-architecture.md             (v0.11)
M  docs/QA_LOG.md                              (logged S75-DEF-01 + S75-DEF-02, both fixed-in-S7.6)
M  docs/SESSION_HANDOFF.md                    (this file)
~  Latte.xcodeproj                             (gitignored — re-run `xcodegen generate` after adding files)

S7.7 (commit 9130ccc):
M  Sources/Triggers/AppTrigger.swift          (+ AppDisplayInfo struct, + WorkspaceSource.displayInfo,
                                                + NSWorkspaceSource.displayInfo + pngData helper,
                                                + Mock.displayInfoLookup, + AppTrigger.displayInfo passthrough,
                                                + AppTriggerDefaults.displayName mapping)
M  Sources/UI/Settings/TriggersTab.swift      (AppTriggerConfigForm rewrite — purpose copy + AppRow with
                                                icon + display name + bundle ID secondary; running-apps Menu
                                                shows display names; manual input collapsed under Advanced
                                                DisclosureGroup)
M  Tests/AppTriggerTests.swift                (+ 6 displayInfo / curated-mapping / passthrough tests;
                                                229 → 235 tests)
M  ROADMAP.md                                 (v0.12)
M  docs/design/02-architecture.md             (v0.12, §13 entry)
M  docs/QA_LOG.md                              (logged S76-DEF-01 fixed-in-S7.7 + S7.7 smoke checklist
                                                addendum + post-S7.7 coverage snapshot)
M  docs/SESSION_HANDOFF.md

S7.8 (commit c60fef7):
M  Sources/Core/SettingsStore.swift           (+ SettingsKey.hasSeededAppDefaults)
M  Sources/Triggers/AppTrigger.swift          (+ WorkspaceSource.pickableRunningBundleIDs,
                                                + WorkspaceSource.isInstalled,
                                                + NSWorkspaceSource real impls (.regular filter, urlForApplication),
                                                + Mock.pickableOverride / installedOverride,
                                                + AppTriggerDefaults.symbolHint mapping,
                                                + AppTriggerDefaults.installedDefaults helper,
                                                + AppTrigger.init seed-on-first-launch,
                                                + AppTrigger.pickableRunningBundleIDs passthrough,
                                                ~ SettingsStore.appTriggerBundleIDs getter — removed
                                                  legacy "fall back to all 6 curated when empty" branch)
M  Sources/UI/Settings/TriggersTab.swift      (Menu uses pickableRunningBundleIDs + Label icon w/ SF Symbol
                                                fallback; AppRow iconView SF Symbol fallback; refreshed
                                                empty-state copy)
M  Tests/AppTriggerTests.swift                (+ 14 tests: symbol hint × 2, isInstalled × 3,
                                                installedDefaults × 2, first-launch seed × 4, pickable × 3;
                                                refreshed testDisabledTriggerNoOpOnStart comment;
                                                235 → 249 tests)
M  Tests/SettingsStoreTests.swift             (testRequiredKeysExist — added new SettingsKey rawValue)
M  ROADMAP.md                                 (v0.13)
M  docs/design/02-architecture.md             (v0.13, §13 entry)
M  docs/QA_LOG.md                              (logged S77-DEF-01..03 all fixed-in-S7.8 + S7.8 smoke
                                                checklist addendum + post-S7.8 coverage snapshot)
M  docs/SESSION_HANDOFF.md

S7.9 (this commit):
M  Sources/Triggers/AppTrigger.swift          (+ private var watchedSet — instance var replaces
                                                  closure-captured `let watched` in start();
                                                + public func reevaluateWatched() with ON/OFF/re-emit
                                                  transition logic;
                                                ~ handleLaunch(bundleID:) / handleTerminate(bundleID:)
                                                  signatures simplified — read watchedSet directly;
                                                ~ stop() — removed `continuation.finish()` so the
                                                  AsyncStream stays open across Toggle OFF→ON cycles;
                                                  watchedSet cleared too)
M  Sources/UI/Settings/TriggersTab.swift      (TriggerSection now takes coordinator; Toggle.onChange
                                                spawns Task that calls coordinator.start/stop on the
                                                live trigger — universal across all 4 triggers;
                                                AppTriggerConfigForm.commit calls trigger.reevaluateWatched
                                                after writing settings)
M  Tests/AppTriggerTests.swift                (+ 6 tests — 5 reevaluateWatched cases + 1 restart-after-stop
                                                regression; refreshed testStopCancelsObservation comment;
                                                249 → 255 tests)
M  ROADMAP.md                                 (v0.14)
M  docs/design/02-architecture.md             (v0.14, §13 entry)
M  docs/QA_LOG.md                              (logged S78-DEF-01..02 fixed-in-S7.9 + S7.9 smoke
                                                checklist addendum + post-S7.9 coverage snapshot +
                                                S7.10 candidate note)
M  docs/SESSION_HANDOFF.md                    (this file)
```

---

## How to resume

```bash
cd ~/Documents/Claude/Projects/Caffeinated-Clone
git log --oneline -3       # latest commit should be the S7 commit
xcodebuild test -scheme Latte -destination "platform=macOS,arch=arm64" \
  -enableCodeCoverage YES -resultBundlePath /tmp/Latte_S8_baseline.xcresult
xcrun xccov view --report /tmp/Latte_S8_baseline.xcresult | head -20
```

If the totals match S7 (227 tests, ≥80% on all gated files), proceed to the §"Next session entry point" section below. If not, that's S7 regression — investigate before starting S8 work.

---

## Next session entry point

**Theme**: App Store prep (session 8 of ~10)

**Goal**: Get to "ready to submit" state — App Store Connect record created, app metadata drafted, screenshots captured, Privacy Policy hosted, GitHub Pages landing page up. Submission button itself stays unpressed until S9 beta feedback is in.

### Pre-session prerequisites (owner — these are HARD blockers)

- [ ] **Apple Developer Program enrollment** (`$99/yr`, 1–2 day approval) → <https://developer.apple.com/programs/>. Without this, no App Store Connect access, no signing, no TestFlight.
- [ ] **App icon PNG** (1024×1024, no alpha, no rounded corners, no embedded shadows) per the brief in `docs/design/05-icon-spec.md`. Place at `Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png` (Asset Catalog auto-scales to other sizes).
- [ ] **Bundle ID prefix decision** (e.g., `com.parkbyeongjun.latte`, `com.hightempier.latte`). Replaces `com.example.latte` everywhere — `project.yml`, `Configuration/Latte.entitlements`, App Store Connect record. Pick one and stick with it; renaming after submission is painful.
- [ ] **Filesystem rename** `Caffeinated-Clone/` → `Latte/` (purely cosmetic but easier now than after the Git history grows further).
- [ ] **`docs/QA_LOG.md` smoke checklist** ticked (or P1 defects logged + S7-fix commit before S8).
- [ ] **Author identity for git commits** — currently shows the system username. Run once, before any push to GitHub:
  ```bash
  git config --global user.email "hightempier18@gmail.com"
  git config --global user.name "박병준"
  ```

### To-do (in order)

#### A. Renames & identity (~30 min, requires owner decisions)

1. Decide bundle ID prefix. Update:
   - `project.yml` → `targets.Latte.settings.base.PRODUCT_BUNDLE_IDENTIFIER`.
   - `Configuration/Latte.entitlements` if any keychain/iCloud entitlement embeds the prefix.
   - Re-run `xcodegen generate`.
2. Rename project folder `Caffeinated-Clone/` → `Latte/` (use `git mv` to preserve history; update any path-bound references in CLAUDE.md / memory files / scripts).
3. Drop the App Icon PNG into `Resources/Assets.xcassets/AppIcon.appiconset/` and verify the catalog references it (`Contents.json` → `1024x1024` slot).
4. Re-run the full test suite to make sure renames didn't break the build.

#### B. App Store Connect record (~60 min, owner-driven)

5. Sign in to App Store Connect → Apps → New App. Fill:
   - Platform: macOS
   - Bundle ID: as decided in step 1 (must match Xcode exactly)
   - SKU: anything stable, e.g., `latte-001`
   - Primary language: English (US)
   - User access: Full access (default)
6. App Information section:
   - Name: **Latte**
   - Subtitle (≤30 chars): e.g. *Smart caffeine for your Mac*
   - Category: Utilities (primary), Productivity (secondary)
   - Content rights: own all content, no third-party advertising
7. Pricing & Availability: $2.99 one-time, all territories where Apple permits.
8. App Privacy: declare data collection (none — Latte stores all settings locally in UserDefaults, no telemetry, no analytics in v1.0). Tick "No data collected" with rationale.

#### C. Screenshots & metadata (~90 min)

9. Capture marketing screenshots — required sizes per Apple guidelines (currently 2880×1800 / 2560×1600 for macOS). Suggested set:
   - Menu-bar dropdown with cup animation mid-fill, on a Big Sur+ desktop.
   - Settings → General with the Coffee tone Picker open and Preview cup visible.
   - Settings → Triggers showing all four triggers with vote indicators.
   - "About" tab to humanize the app.
10. Draft App Store description (≤4000 chars) and "What's New" (≤4000 chars). Lead with the differentiator: "Latte sleeps when you do — wakes for meetings, mutes when you're done." Avoid mentioning competitors by name.
11. Keywords (≤100 chars total, comma-separated): e.g., `caffeine,sleep,awake,meeting,zoom,focus,menu bar,utility,productivity`.
12. Support URL + Marketing URL: GitHub Pages (set up in step D).

#### D. GitHub Pages site for Privacy Policy + landing (~60 min)

13. Create branch `gh-pages` (or use a separate `latte-site/` repo). Drop a one-page `index.html` (Latte landing) and `privacy.html` (Privacy Policy — App Store requires a hosted URL for this).
14. Privacy Policy template covers: no data collection, all settings stored locally, no third-party analytics, no network calls in v1.0, contact email.
15. Verify both URLs serve over HTTPS (required by App Store).

#### E. Build for submission (~30 min)

16. Bump `MARKETING_VERSION` to `1.0.0` and `CURRENT_PROJECT_VERSION` to `1` in `project.yml`.
17. Archive build: `xcodebuild archive -scheme Latte -destination "platform=macOS,arch=arm64" -archivePath /tmp/Latte.xcarchive`.
18. Verify the archive opens cleanly in Xcode → Organizer.
19. **Do not click "Distribute App" yet** — that's S10 after beta feedback.

#### F. Wrap (~15 min)

20. Bump `02-architecture.md` to v1.0 once renames + bundle ID are in.
21. Bump `ROADMAP.md` row 8 → 🟢 Done, row 9 → 🟡 Next.
22. Overwrite `docs/SESSION_HANDOFF.md` for session 9 entry — TestFlight beta launch.
23. Commit as `feat: session 8 — App Store prep (metadata + screenshots + landing site)`.

### Cannot-start-without checks

- Apple Developer Program enrollment **complete** and Team ID known (Xcode → Settings → Accounts).
- App Icon PNG **delivered**.
- Bundle ID prefix **decided**.
- `docs/QA_LOG.md` smoke ticked OR P1 defects fixed.

If any of the above is still pending, **do not start S8**. Instead, defer S8 to a later date and use the time to finish the prerequisites — they cannot be done by Claude.

---

## Recap quick stats

- 227 tests, all passing.
- Core/ + Triggers/ all ≥80%.
- 0 P1 defects logged (smoke checklist still owed).
- 0 architectural changes since S6.
- Single commit for S7 (per `git-workflow.md` style).
