# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 6 of ~10 |
| **Theme** | Build verification + post-build smoke fixes + custom duration α + coffee tone customization |
| **Date** | 2026-04-26 |
| **Status** | ✅ Completed. Build/test green (195/195), Settings window opens, design polish iterated to owner approval, custom duration row works, coffee tone picker (5 presets) with live preview is wired end-to-end through 7 views. Two commits: `feat: session 6 — green build + post-build polish + custom duration α` (3d5839a) and `feat: coffee tone customization — 5 presets + Settings preview` (this session's second commit). |

### What was accomplished

1. **Toolchain stood up**
   - Xcode 26.4.1 (Build 17E202) installed; license accepted.
   - `xcodebuild -runFirstLaunch` ran the missing component install (`CoreSimulator.framework` plug-in load).
   - `brew install xcodegen` → 2.45.4.
   - `xcodegen generate` produced `Latte.xcodeproj` from `project.yml` cleanly. No source-glob misses — `path: Sources` and `path: Tests` already capture every S5 file.

2. **Build green: 4 fixes** (all minimal, no architectural changes)

   | File | Symptom | Fix |
   |---|---|---|
   | [`Sources/Intents/AwakeIntents.swift`](../Sources/Intents/AwakeIntents.swift) | 9 Swift 6 strict-concurrency warnings on `static var title/description/openAppWhenRun` (App Intents framework) | `static var` → `static let` (protocol getter requirement is satisfied; mutability not needed) |
   | [`Sources/Intents/AwakeIntents.swift`](../Sources/Intents/AwakeIntents.swift):23 | `error: expect a compile-time constant literal` on `@Parameter(default: 30, inclusiveRange: (1, 24 * 60))` | `(1, 24 * 60)` → `(1, 1440)` (App Intents macros require literal) |
   | [`Sources/UI/MenuBar/MenuBarRoot.swift`](../Sources/UI/MenuBar/MenuBarRoot.swift):6 | `'openSettings' is only available in macOS 14.0 or newer` (we deploy macOS 13) | Removed `@Environment(\.openSettings)`; added `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` fallback. Works on both macOS 13 and 14+. |
   | [`Sources/Triggers/WiFiTrigger.swift`](../Sources/Triggers/WiFiTrigger.swift):181, [`Sources/Triggers/FocusTrigger.swift`](../Sources/Triggers/FocusTrigger.swift):160 | 5 test failures: trigger emits OFF vote on first evaluation when condition is false | Added 1-line guard: `if lastVote == nil && !wantsAwake { return }`. Now matches `AppTrigger.start` semantic (silence = "no opinion"; only emit on transitions or first ON). |

3. **Test failures fixed: autoclosure async** (Tests/, 14 sites across 4 files)
   - All call sites of `XCTAssertNil(await task.value, ...)` failed under Swift 6: autoclosure parameters can't host `await`.
   - Bulk-rewritten via `perl -i -pe 's/XCTAssertNil\(await task\.value(.*?)\)$/do { let _v = await task.value; XCTAssertNil(_v$1) }/g'` across `WiFiTriggerTests.swift`, `FocusTriggerTests.swift`, `CalendarTriggerTests.swift`, `AppTriggerTests.swift`.

4. **Verification**
   - Build: ✅ `** BUILD SUCCEEDED **`
   - Tests: ✅ `Executed 178 tests, with 0 failures (0 unexpected) in 1.877s` across all 18 test suites.
   - Launch: ✅ `Latte.app` starts (PID confirmed); arm64 Mach-O binary at `~/Library/Developer/Xcode/DerivedData/Latte-fkobqyixcisqmicfcisyrcpgeolp/Build/Products/Debug/Latte.app`.

5. **Post-build smoke surfaced two real bugs + a polish wish-list — fixed in a second pass**

   **Bug A: Settings window did not open.** `Settings { }` SwiftUI scene + `SettingsLink` (and both `Selector(("showSettingsWindow:"))` / `showPreferencesWindow:`) silently no-op for `LSUIElement` apps because the menu/responder chain isn't there. Fix: new [`Sources/UI/Settings/SettingsWindowController.swift`](../Sources/UI/Settings/SettingsWindowController.swift) hosts `SettingsRoot` in a real `NSWindow` via `NSHostingController`, owned as a singleton. `LatteApp` no longer declares `Settings { }`; `MenuBarRoot.openSettings()` calls `SettingsWindowController.shared.show(...)` directly with the `AppEnvironment` (now read via `@EnvironmentObject`).

   **Bug B: Accent color showed as system blue (or invisible) in Canvas.** `Color.accentColor` on macOS follows the user's system tint regardless of the asset-catalog `AccentColor`; `Color.primary` is not always resolved against current appearance inside `Canvas`; `Color("AccentColor")` lookup silently returned transparent on macOS 26 in some paths. Fix: `Theme.Colors.accentAwake` and the new `Theme.Colors.cupStroke` are now built from explicit `NSColor(name:dynamicProvider:)` with hand-tuned light/dark sRGB values. Final accent is espresso brown — light: `(0.42, 0.24, 0.08)`, dark: `(0.62, 0.40, 0.18)` (iterated to owner approval; previous caramel `(0.85, 0.65, 0.30)` was "too light"). `Theme.swift` now imports `AppKit`. `CoffeeCupView` strokes use `cupStroke`; the liquid uses `accentAwake`.

   **Polish (A + B + D from the design wish-list)**
   - [`Sources/UI/MenuBar/DurationPickerRow.swift`](../Sources/UI/MenuBar/DurationPickerRow.swift) — hover state (6% primary, rounded), 3pt leading caramel accent bar on active row, checkmark switched from monochrome to caramel.
   - [`Sources/UI/MenuBar/MenuBarRoot.swift`](../Sources/UI/MenuBar/MenuBarRoot.swift) — divider opacity 0.5, Turn-off button dimmed 0.45 when inactive, Settings…/Quit footer foreground `.secondary`.
   - `Resources/Assets.xcassets/AccentColor.colorset/Contents.json` — light + dark variants (kept for the global app accent setting; menu-bar accent uses the in-code `NSColor`-based one).

   **Custom duration α** — new [`Sources/UI/MenuBar/CustomDurationRow.swift`](../Sources/UI/MenuBar/CustomDurationRow.swift). Inline expandable row under the 7 presets: collapsed shows "Custom… ⌄"; expanded shows a `Stepper` (1–1440 min, step 5) and a "Start" button. Animation is `.animation(.easeInOut(duration: 0.18), value: isExpanded)` scoped to the row's own `VStack` (initially scoped via `withAnimation` block — fixed after observing sibling rows getting pulled into the layout transaction).

6. **Coffee tone customization** (added at the very end of the session, after the user asked "can the coffee color be a setting?")

   New customization surface — five hand-picked tones (Espresso default / Caramel / Mocha / Latte / Noir), each with light + dark sRGB pairs resolved through `NSColor(name:dynamicProvider:)`:

   - [`Sources/UI/Theme/CoffeeAccent.swift`](../Sources/UI/Theme/CoffeeAccent.swift) — 5-case enum carrying the color matrix. `displayName` + `shortDescription` for the picker. Tolerant `decode(_ raw: String?)` returns `.default` (espresso) on nil/empty/unknown. The previous static `Theme.Colors.accentAwake` is now a compat alias pointing to `.default.color`.
   - [`Sources/Core/SettingsStore.swift`](../Sources/Core/SettingsStore.swift) — new `SettingsKey.coffeeAccent`.
   - [`Sources/App/AppEnvironment.swift`](../Sources/App/AppEnvironment.swift) — `@Published var coffeeAccent: CoffeeAccent`, hydrated on init, write-through with equality short-circuit (matches the `menuBarIconStyle` pattern).
   - **7 views switched from the static accent to `environment.coffeeAccent.color`**: `HeaderView` (passes through), `CoffeeCupView` (now takes a `liquidColor` parameter, default `.default.color`), `DurationPickerRow`, `CustomDurationRow`, `GeneralTab` status dot, `TriggersTab` voting indicator, `AboutTab` hero cup.
   - [`Sources/UI/Settings/GeneralTab.swift`](../Sources/UI/Settings/GeneralTab.swift) — Appearance section gains:
     1. A "Preview" `LabeledContent` row at the top with a 36pt `CoffeeCupView` whose liquid is `environment.coffeeAccent.color`. This was the user's specific ask: the menu-bar popover closes when Settings takes focus, so without an in-window preview the user couldn't *see* the live color change while choosing a tone.
     2. A "Coffee tone" `Picker` (`.menu` style) listing all 5 cases with a 12pt color dot + display name + short description per row.

   **Tests added — 17, all passing (total 195/195)**:
   - [`Tests/CoffeeAccentTests.swift`](../Tests/CoffeeAccentTests.swift) — 12 tests: case order, raw-value stability, displayName/shortDescription uniqueness + non-empty, default = espresso, tolerant decode (nil / empty / unknown / case-sensitivity), color non-crashing for every case.
   - [`Tests/AppEnvironmentTests.swift`](../Tests/AppEnvironmentTests.swift) — +5: defaults to espresso, hydrate from store, fallback on garbage, write-through, equal-value didSet short-circuit.
   - [`Tests/SettingsStoreTests.swift`](../Tests/SettingsStoreTests.swift):119 — required-keys list updated to include `latte.coffeeAccent` (the existing exhaustive-keys assertion would otherwise fail).

7. **Documentation**
   - **`ROADMAP.md`** v0.5 → **v0.6** → **v0.7** → **v0.8**: each version captures one logical pass (build-green / post-build-hardening / coffee-tone-customization). Session 7 = test coverage + QA still marked next.
   - **`docs/design/02-architecture.md`** v0.5 → **v0.6** → **v0.7** → **v0.8**: §13 changelog has all three passes with rationale. New types (`SettingsWindowController`, `CustomDurationRow`, `CoffeeAccent`, `Theme.Colors.cupStroke`) all listed with the *why*, not just the *what*.
   - **`docs/SESSION_HANDOFF.md`**: this file, overwritten for session 7 entry.

### What was *not* done (intentionally deferred)

- **Manual menu-bar smoke checklist** — already walked: menu opens, cup animates (foreground + background), Turn-off works, custom duration starts at user-set minute count, **Settings window opens**, accent/liquid/checkmark all use the chosen `coffeeAccent`, hover state OK, divider subtle, expand animation localized to its own row, **Coffee tone picker switches the live preview cup and (after re-opening the popover) the menu-bar elements instantly**. Owner approved.
- **Per-trigger config UI** (calendar/bundle/SSID pickers) — still pending, hand off to S7 or S8.
- **Static `Theme.Colors.accentAwake` cleanup** — now a 1-line alias to `CoffeeAccent.default.color`. Could be removed entirely with a small refactor pass; not worth doing in S7 (coverage focus).
- **Coverage report** — we know all tests pass, but `xcodebuild` was not run with `-enableCodeCoverage YES`. The 80% coverage gate (PRD §10) is the S7 entry point.
- **macOS 13 / 14 / 15 matrix testing** — local box is macOS 26 (Tahoe) only. Multi-version smoke happens in S7.
- **App icon PNG**, **Apple Developer Program enrollment**, **bundle ID rename**, **filesystem rename** `Caffeinated-Clone/ → Latte/` — all owner-side, not S7-blocking but S8-blocking.

---

## Next session entry point

**Theme**: Test coverage + QA (session 7 of ~10)

**Goal**: Get to ≥80% line coverage on `Sources/Core/**` and `Sources/Triggers/**` per PRD §10. Run a clean manual smoke checklist on the live app. Log any QA findings as known issues.

### Pre-session prerequisites (owner)

- [ ] **Manual smoke from S6 still owed.** When you have 5 minutes, click through the running app and confirm the checklist below — most of it can be answered in one sitting. If anything is broken, log it as a fix-first task; otherwise check the boxes and S7 starts clean.

  **S6 Smoke checklist** (Latte already launched in S6 — should still be in your menu bar; if not, `open ~/Library/Developer/Xcode/DerivedData/Latte-fkobqyixcisqmicfcisyrcpgeolp/Build/Products/Debug/Latte.app`):
  - [ ] Menu-bar icon visible (default `cup.and.saucer.fill`).
  - [ ] Click → menu opens (header, four duration rows, Turn off, Settings…, Quit).
  - [ ] Pick a duration → cup view animates (steam particles drift up, liquid fills).
  - [ ] Switch to another app → cup keeps animating (TimelineView active).
  - [ ] Settings → General → Appearance → switch to "Outlined cup" → menu-bar icon updates *instantly*.
  - [ ] Settings → Triggers → toggling a trigger off does **not** fire a permission prompt for already-disabled triggers.
  - [ ] Quit → process exits cleanly; no power assertion leaked (verify with `pmset -g assertions | grep -i caffeinate` showing nothing).

### To-do (in order)

#### A. Coverage baseline (~30 min)

1. `xcodebuild test -scheme Latte -destination "platform=macOS,arch=arm64" -enableCodeCoverage YES` — capture coverage profile.
2. `xcrun llvm-cov report` (or `xcrun xccov view --report`) on the resulting `.xcresult` — extract per-file coverage for `Sources/Core/**` and `Sources/Triggers/**`.
3. Identify any file under 80%. The likely gaps:
   - `AwakeManager` — `@MainActor` lifecycle + signal handler paths
   - `TriggerCoordinator` — `cooldown` / `snooze` paths
   - `Logging.swift` — typically 0% (subsystem definitions only — exempt with rationale, or log as documented gap)
   - The "real source" classes (`CoreWLANSource`, `INFocusSource`, `EKEventSource`, `NSWorkspaceSource`) — these are exempt because they require live system services; coverage targets the *protocol consumers*, not the adapters.

#### B. Add tests to close gaps (~60 min)

4. For each <80% file, add focused unit tests. Prefer Swift Testing (`import Testing` + `@Test`) for new files per `~/.claude/rules/swift/testing.md`; existing XCTest files stay XCTest.
5. Re-run coverage. Iterate until `Core/` and `Triggers/` are both ≥80%.

#### C. Manual QA matrix (~30 min)

6. Run the same smoke checklist as the prerequisite section above, but on **a known-clean build** (after coverage tests pass).
7. If owner has access to a macOS 13 or 14 machine, smoke there too. Otherwise log as "untested on macOS 13/14" and hand to TestFlight (S9) for matrix coverage.
8. Log any defects in a new `docs/QA_LOG.md`. Triage by severity: P1 (blocks ship), P2 (ship with workaround), P3 (cosmetic).

#### D. Wrap (~15 min)

9. Bump `02-architecture.md` to v0.7 only if any structural change was needed to close coverage gaps.
10. Bump `ROADMAP.md` row 7 to 🟢 Done (or 🟡 In progress if coverage <80% remains).
11. Overwrite `docs/SESSION_HANDOFF.md` for session 8 entry — App Store prep (metadata, screenshots, Privacy Policy).
12. Commit as `feat: session 7 — coverage to 80%+ + QA pass`.

### Cannot-start-without checks

- Latte.app should already be in the menu bar from the S6 launch. If you've rebooted, just re-launch via the path above.
- Re-read [`02-architecture.md` §13](design/02-architecture.md#13-document-change-log) v0.6 entry for the exact build fixes — useful if any test starts failing again, you'll know what changed.
- No new toolchain or owner action required for S7. All prerequisites are already satisfied from S6.

---

## Decisions still pending owner approval

**None for session 7.** S7 is mechanical (coverage + smoke). Decisions resume in S8 (App Store metadata, pricing, support email, etc.).

---

## Known issues / debt

| Issue | Impact | Plan |
|---|---|---|
| Repo root folder still named `Caffeinated-Clone/` | Cosmetic | Owner renames to `Latte/` before first external push |
| Bundle ID `com.example.latte` is placeholder | Cannot ship | Owner provides real reverse-domain before S8 |
| App icon PNG not produced | Cannot ship | Spec written ([05-icon-spec.md](design/05-icon-spec.md)) — owner produces between S6 and S8 |
| No Apple Developer Program enrollment | Cannot submit | Owner enrolls before S8 |
| `INFocusStatusCenter` does not expose Focus IDs | Per-Focus filtering can't ship in v1 | Documented as Phase 1.5 follow-up ([04 §4.5](design/04-data-model.md#45-focus-mode-trigger)) |
| Trigger config UI (calendar/bundle/SSID pickers) not built | Triggers tab still placeholder for *config*; vote status is live | S7 *may* add basic pickers; otherwise S8 |
| `AwakeManager.installSignalHandlers()` uses `.shared` from `@convention(c)` | Best-effort cleanup only | Acceptable for menu-bar utility |
| Local box is macOS 26 (Tahoe) only | macOS 13/14 smoke happens in TestFlight (S9) | Document and accept risk |
| `Logging.swift` likely 0% coverage by design | Logger subsystems aren't behavior to test | Either exempt explicitly or test that subsystems exist |

---

## Files changed this session

**Commit 1 — `feat: session 6 — green build + post-build polish + custom duration α` (3d5839a)**

Already documented in the previous version of this file; covers build green (4 fixes + 14 test sites), `SettingsWindowController`, `NSColor`-based dynamic accent + cupStroke, `DurationPickerRow` polish, divider/Turn-off/footer polish, `CustomDurationRow`. ROADMAP v0.5 → v0.7, 02-architecture v0.5 → v0.7.

**Commit 2 — `feat: coffee tone customization — 5 presets + Settings preview` (this commit)**

```
M  ROADMAP.md                                     (v0.7 → v0.8)
M  docs/SESSION_HANDOFF.md                        (this file)
M  docs/design/02-architecture.md                 (v0.7 → v0.8; §13 coffee-tone entry)

A  Sources/UI/Theme/CoffeeAccent.swift            (5-case enum + sRGB matrix + dynamic NSColor)
M  Sources/Core/SettingsStore.swift               (+ SettingsKey.coffeeAccent)
M  Sources/App/AppEnvironment.swift               (+ @Published coffeeAccent mirror)
M  Sources/UI/Components/CoffeeCupView.swift      (+ liquidColor parameter)
M  Sources/UI/MenuBar/HeaderView.swift            (passes environment.coffeeAccent.color)
M  Sources/UI/MenuBar/DurationPickerRow.swift     (accent bar/checkmark via env)
M  Sources/UI/MenuBar/CustomDurationRow.swift     (accent via env)
M  Sources/UI/Settings/GeneralTab.swift           (Preview row + Coffee tone Picker; status dot via env)
M  Sources/UI/Settings/AboutTab.swift             (hero cup liquidColor via env)
M  Sources/UI/Settings/TriggersTab.swift          (voting indicator + subtitle accent via env)

A  Tests/CoffeeAccentTests.swift                  (12 new tests)
M  Tests/AppEnvironmentTests.swift                (+5 tests for coffeeAccent mirror)
M  Tests/SettingsStoreTests.swift                 (added latte.coffeeAccent to required-keys list)
```

`Latte.xcodeproj/` is regenerated from `project.yml` per session via `xcodegen generate`; ignored via `.gitignore` (`*.xcodeproj`).

`Latte.xcodeproj/` is regenerated from `project.yml` per session via `xcodegen generate`; ignored via `.gitignore` (`*.xcodeproj`).

---

## How to resume

1. Confirm Latte.app is still in the menu bar (or re-launch from the DerivedData path).
2. Walk the S6 smoke checklist (5 min).
3. Read [ROADMAP.md](../ROADMAP.md) — orientation.
4. Read this file's **§To-do** section.
5. From the repo root: `xcodebuild test -scheme Latte -destination "platform=macOS,arch=arm64" -enableCodeCoverage YES` to capture the coverage baseline. Work A → D.
