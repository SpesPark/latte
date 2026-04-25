# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 7 of ~10 |
| **Theme** | Test coverage + QA gate |
| **Date** | 2026-04-26 |
| **Status** | ✅ Completed. 227/227 tests passing. All `Sources/Core/**` and `Sources/Triggers/**` files at ≥80% line coverage (lowest 82.8%, several at 100%) once live-system adapter classes (`EKCalendarSource`, `NSWorkspaceSource`, `INFocusSource`, `CoreWLANSource`) are excluded — that exemption is now formally documented in `02-architecture.md` §13 (v0.9) and `docs/QA_LOG.md`. PowerAssertion was promoted off the exemption list because IOKit `IOPMAssertion*` works in any test process without entitlements. |

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

178 → 195 → **227** (+32 net since S6 close: 12 SettingsStore parametrized doubles, 6 PowerAssertion, 8 WiFi, 6 Calendar). All passing.

### What's NOT done (intentional)

- **Owner-side manual smoke checklist** in `docs/QA_LOG.md` is checked-in but unchecked — Claude cannot drive the menu-bar UI. Owner runs through this and ticks lines (or logs defects in the same doc) before S8 starts in earnest. Gate for S8 is: zero P1 items in QA_LOG.
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
- **`Per-trigger config UI`** (calendar/bundle/SSID pickers) — still pending from S5; not on S8 path. Likely lands as a Phase 1.5 follow-up.

---

## Files changed this session

```
A  Tests/PowerAssertionTests.swift
M  Tests/SettingsStoreTests.swift
M  Tests/WiFiTriggerTests.swift
M  Tests/CalendarTriggerTests.swift
A  docs/QA_LOG.md
M  docs/design/02-architecture.md   (v0.9, §13 entry)
M  ROADMAP.md                        (v0.9; row 7 → done, row 8 → next)
M  docs/SESSION_HANDOFF.md           (this file, overwritten for S8)
~  Latte.xcodeproj                    (gitignored — re-run `xcodegen generate` after adding files)
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
