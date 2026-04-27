# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 8b — v1.0 scope expansion + smoke fix-first iteration (2026-04-27) |
| **Theme** | S8b research preamble → v1.0 scope expansion (5 features) → 4 rounds of smoke fix-first based on owner feedback |
| **Status** | ✅ Code-side complete; owner verified P1/P2/P3/P4 fixes pass. Tail commit `31389cd`. 288/288 tests green. Owner-side smoke (D/E/F/screenshots/Pages) **deferred to S8c** pending smoke-harness automation. |
| **Tail commit** | `31389cd fix: S8b smoke #4 — defer Focus trigger to v1.x + WiFi/Calendar immediate-reflect` |

### What S8b accomplished (11 commits)

**Phase 1 — Research preamble (1 commit)**

| Commit | Theme |
|---|---|
| `56603f6` | S8a-final + S8b research preamble (4 parallel agents, 45-min market scan, 4 of 5 recommendations applied; owner kept $2.99 aggressive entry, banned subscription as durable PRD guardrail) |

**Phase 2 — v1.0 scope expansion (5 commits)**

Owner asked to ship aggressively. Tier S + selected Tier A items landed:

| Commit | Item | Tests |
|---|---|---|
| `05f8c2d` | V2-01 menu-bar awake visualization + V2-10 `accentAwake` cleanup | 263 → 267 (+4) |
| `6109859` | Launch at Login (SMAppService) | 267 → 274 (+7) |
| `7decb84` | V2-04 EKCalendar list picker | 274 → 279 (+5) |
| `2da1f3d` | First-run onboarding wizard | 279 → 284 (+5) |
| `a4a3ce9` | Docs catch-up (PRD/v2-backlog/ROADMAP/store + V2-11 owner guide) | 284 |

**Phase 3 — Smoke fix-first (4 commits)** — owner ran the new build through the §S8b smoke checklist; each round surfaced a P1 that was fixed before moving on:

| Commit | P-series | Fix |
|---|---|---|
| `aa42e90` | P1-1 + P1-2 | Universal steam awake icon (initial fix) + Settings Toggle ON now requests permission like bootTriggers does |
| `45e73fc` | P2-1 + P2-2 | **Per-style** awake glyph (owner: filled/outline/clock should each look distinct) + **coordinator consumer-task keepalive** (real root cause: cancelling consumer Task terminates the AsyncStream's storage even when continuation isn't finished, so subsequent yields are silently dropped) |
| `acea09a` | P3-2 + Focus diagnostic | Onboarding-only first launch via NSApplicationDelegateAdaptor (boot logic moved out of MenuBarRoot's `.task`); menu-bar icon hidden via `MenuBarExtra(isInserted:)` while wizard is up + structured info logs added to FocusTrigger.evaluate for owner-side diagnosis |
| `31389cd` | P4-1 + P4-2 | **Defer Focus trigger to v1.x** (V2-03b) — Apple Communication Notifications entitlement gates reliable read; FocusTrigger no longer registered with coordinator. WiFi/Calendar config forms now immediately re-evaluate after settings commit (V2-02 closed for these triggers). |

### v1.0 scope at S8b end

| Trigger | v1.0? | Notes |
|---|---|---|
| Calendar | ✅ | Headline differentiator. EKCalendar picker shipped (V2-04). |
| App | ✅ | Curated defaults + running-apps picker (S7-family). |
| Wi-Fi | ✅ | Inverse mode + immediate-reflect on commit (S8b P4-2). |
| Focus | ❌ deferred to v1.x | V2-03b in `docs/v2-backlog.md`. Re-enable after Apple Dev Program + Communication Notifications entitlement. |

| Other v1.0 features (S8b) | Status |
|---|---|
| Menu-bar awake-state visualization (V2-01) | ✅ per-style paired SF Symbols |
| Launch at Login (SMAppService) | ✅ Settings → General → Behavior toggle |
| First-run onboarding wizard | ✅ 3 steps (welcome / picker / done), shown on first launch only |
| `Theme.Colors.accentAwake` cleanup (V2-10) | ✅ removed |

### Apple Developer Program — status

**Owner explicit choice (S8b)**: defer Apple Developer Program enrollment until needed. Not blocking S8b code work. Will resume in S8.5 per ROADMAP.

**V2-03b dependency**: Focus trigger re-enable depends on:
1. Apple Dev Program enrolled ($99/yr, 1-2 day approval)
2. `com.apple.developer.usernotifications.communication` entitlement provisioned (may require App Review justification — Apple sometimes rejects)
3. ~1 h code work to uncomment + re-test

If Apple rejects the entitlement → drop Focus permanently; Calendar/App/WiFi already cover the wedge.

---

## Decisions still pending owner approval

- **None blocking S8c.** All P1-P4 smoke findings resolved.
- **Smoke harness scope** confirmed as Option B (build harness next session before continuing manual smoke). Setup expected ~4-6 h.

---

## Known issues / debt

- **Focus trigger silently does nothing on macOS without Communication Notifications entitlement** — V2-03b documented; coordinator no longer registers it so users can't accidentally enable a non-functional feature. Re-enable after Apple Dev Program.
- **Swift 6 strict-concurrency warnings** in `AppTrigger.swift` and `FocusTrigger.swift` (`Task { @MainActor in onChange(...) }` capturing non-Sendable closures) — existing pre-S8b warnings, not blocking. Add to v1.x cleanup as V2-30.
- **Owner-side smoke unfinished** — S7.11 regression smoke + new S8b smoke items D/E/F (icon × 3 styles × light/dark, Launch at Login external reconciliation, Calendar picker delete-edge-case) still need verification. Will be automated via the smoke harness in S8c.

---

## Files changed this session (cumulative)

### Source code
```
A  Sources/Core/LaunchAtLoginManager.swift            (V2 expansion #2)
A  Sources/UI/Onboarding/OnboardingState.swift        (V2 expansion #4)
A  Sources/UI/Onboarding/OnboardingView.swift
A  Sources/UI/Onboarding/OnboardingWindowController.swift
M  Sources/App/AppEnvironment.swift                   (LaunchAtLogin + onboarding wiring + .shared singleton + Focus disable)
M  Sources/App/LatteApp.swift                         (manager.isAwake observation + AppDelegate boot + isInserted hiding)
M  Sources/UI/MenuBar/MenuBarIconStyle.swift          (V2-01 paired symbols)
M  Sources/UI/Theme/Theme.swift                       (V2-10 accentAwake removed)
M  Sources/UI/Settings/GeneralTab.swift               (Launch at Login toggle)
M  Sources/UI/Settings/TriggersTab.swift              (V2-04 picker UI + Toggle ON requests permission + WiFi/Calendar immediate-reflect)
M  Sources/Triggers/CalendarTrigger.swift             (CalendarSummary + availableCalendars)
M  Sources/Triggers/TriggerCoordinator.swift          (consumer-task keepalive root-cause fix)
M  Sources/Triggers/Trigger.swift                     (MockTrigger.stop no longer finishes continuation)
M  Sources/Triggers/FocusTrigger.swift                (diagnostic logs)
```

### Tests
```
A  Tests/LaunchAtLoginTests.swift
A  Tests/OnboardingStateTests.swift
M  Tests/MenuBarIconStyleTests.swift                  (paired-symbol assertions)
M  Tests/CalendarTriggerTests.swift                   (V2-04 contract tests)
M  Tests/TriggerCoordinatorTests.swift                (Toggle OFF→ON cycle regression)
M  Tests/AppEnvironmentTests.swift                    (Three default triggers, Focus deferred)
```

### Docs
```
M  docs/design/01-PRD.md                              (v0.3 → v0.4, v1.0 scope expansion section)
M  docs/v2-backlog.md                                 (V2-01/04/10 marked shipped, V2-03b NEW for Focus deferral, ship-order reshuffled)
M  docs/SESSION_HANDOFF.md                            (this file)
M  docs/QA_LOG.md                                     (S8b smoke checklist for D/E/F)
M  ROADMAP.md                                         (row 8 split further; v1.1 changelog entry)
M  docs/site/index.html                               (S8b research-driven headline)
M  docs/store/description-en.md                       (3 triggers, no Focus)
M  docs/store/description-ko.md
M  docs/store/subtitle-en.txt                         (Q4 ASO research)
M  docs/store/subtitle-ko.txt
M  docs/store/keywords-en.txt
M  docs/store/keywords-ko.txt
A  docs/store/V2-11-icon-variants-guide.md            (owner guide)
```

---

## How to resume

```bash
cd ~/Documents/Claude/Projects/Latte
git status         # should be clean
git log --oneline -8
xcodebuild test -scheme Latte -destination "platform=macOS,arch=arm64" 2>&1 | tail -3
# Expected: 288/288 tests pass
```

Latest Release build is at:
```
~/Library/Developer/Xcode/DerivedData/Latte-hcfmwngrrkeynehkwodtxrrnyxyq/Build/Products/Release/Latte.app
```

---

## Next session entry point

**Theme**: S8c — smoke harness setup (Option B) + automated Latte smoke completion.

### Pre-session prerequisites (none — all owner blockers resolved at S8b end)

### Plan (in order)

#### 1. Build smoke-harness (~4-6 h)

Owner-confirmed scope (Option B). Architecture:

```
~/dev/smoke-harness/
├── run.sh                    # Claude entry point — takes a project path
├── lib/
│   ├── reset_prefs.sh        # defaults delete <bundle>; tccutil reset
│   ├── launch_app.sh         # open + wait for window
│   ├── capture_screenshot.sh # screencapture → /tmp/smoke/<name>.png
│   ├── read_log.sh           # log show predicate wrapper
│   ├── verify_assertion.sh   # pmset -g assertions check
│   └── apple_script_click.sh # NSAccessibility click helper (best-effort)
└── templates/
    └── xcuitest-target/      # Boilerplate that installs into a project
```

Per-project config:
```
Latte/.smoke/
├── config.yml                # bundle ID, settings keys, expected triggers
└── scenarios/
    ├── 01-onboarding.sh
    ├── 02-toggle-cycle.sh
    ├── 03-icon-states.sh
    ├── 04-launch-at-login.sh
    └── 05-calendar-picker.sh
```

Goal: from any future macOS project Claude can run `~/dev/smoke-harness/run.sh --project <path>` and get a structured report (screenshots + state diffs + log highlights). For 10+ apps owner is planning, the upfront cost amortises after ~2 apps.

#### 2. Apply harness to Latte (~1 h)

Wire `Latte/.smoke/` config + scenarios. Re-run the deferred S8b smoke items D/E/F via the harness. Capture screenshots automatically.

#### 3. Marketing screenshot capture (~30 min if harness automates; ~90 min manual)

Per `docs/store/screenshot-guide.md` — 5 shots at 2880×1800, plus a new 6th for the onboarding wizard step 2. If harness can drive the app, screenshots become a deterministic pass.

#### 4. App Store preview video (~1-2 h, owner-side)

30-s video, captured with QuickTime or scripted via the harness. Plan in `docs/SESSION_HANDOFF.md` of the prior S8b commit.

#### 5. GitHub Pages deploy (~30 min)

Per `docs/site/README.md` Option A. URLs validated with curl.

#### 6. S8b commit closure + S8.5 handoff

When all the above is done, write a `feat: session 8c — smoke harness + Latte automated smoke + Pages live` commit and overwrite this handoff for S8.5 entry (Apple Dev Program enrollment becomes the next gate).

### Cannot-start-without checks

- 288/288 tests still pass on `main` (verify with `xcodebuild test`).
- `~/dev/` exists and is writable (default).

If both pass, S8c starts.

---

## Recap quick stats (S8b end)

- **Tests**: 263 (S8b start) → 288 (S8b end), all passing.
- **Commits**: 11 on top of `87d1eab`. Tail: `31389cd`.
- **Triggers in v1.0**: Calendar / App / Wi-Fi (Focus deferred to v1.x via V2-03b).
- **New v1.0 features**: V2-01 menu-bar awake viz, V2-04 EKCalendar picker, V2-10 cleanup, Launch at Login, first-run onboarding wizard.
- **PRD version**: 0.4. ROADMAP changelog: `1.1` entry added.
- **Owner-side action remaining**: none for S8b code; S8c handles the rest via harness.
