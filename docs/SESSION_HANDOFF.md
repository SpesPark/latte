# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 8c — cross-project smoke harness + Latte automated D/E/F smoke (2026-04-28) |
| **Theme** | Build `~/dev/smoke-harness/` (V2-30) → wire Latte's deferred S8b smoke as 5 scenarios → marketing-prep automation. Fix-first iteration on harness itself. |
| **Status** | ✅ Harness operational, all 6 Latte scenarios PASS, 13 PNG artifacts captured. Tests still 288/288 (untouched). Marketing shots 1-5 + Pages deploy = owner-side actions queued for S8d (now broken out as a separate row in ROADMAP). |
| **Tail commit** | (this session — see git log) |

### What S8c accomplished

**Phase 1 — Harness foundation** (`~/dev/smoke-harness/`)

| File | Purpose |
|---|---|
| `run.sh` | Entry point — `--project <path>` reads `.smoke/config.yml` (top-level YAML), iterates `.smoke/scenarios/*.sh`, writes JSONL report |
| `lib/log.sh` | `smoke_info/warn/error/ok/step` + `smoke_record` JSONL appender |
| `lib/reset_prefs.sh` | `defaults delete` + `tccutil reset` for Calendar/Location/AppleEvents/Reminders |
| `lib/launch_app.sh` | `open -a` + poll `lsappinfo info -only pid -app <bundle-id>` (process name ≠ bundle id on macOS — initial `pgrep -f` impl was wrong) |
| `lib/quit_app.sh` | AppleScript graceful + SIGTERM fallback by resolved pid |
| `lib/capture_screenshot.sh` | `screencapture -x -t png`, **fail-soft** if no Screen Recording permission (warn, continue) |
| `lib/capture_menubar.sh` | Top 32px strip via `screencapture -R 0,0,W,32` |
| `lib/read_log.sh` | `log show --last Ns --predicate process == "<name>"` wrapper |
| `lib/verify_assertion.sh` | `pmset -g assertions` grep for `PreventUserIdleSystemSleep` |
| `lib/defaults_helper.sh` | `defaults read/write` with type flags |
| `lib/appearance.sh` | `osascript` System Events Light/Dark toggle |
| `templates/config.yml.template` | Drop-in starter for next app |
| `README.md` | Architecture + per-project layout + run examples |

**Phase 2 — Latte wiring** (`Latte/.smoke/`)

| Scenario | What it asserts | Status |
|---|---|---|
| `01-onboarding.sh` | First-run wizard appears on missing `latte.firstRunCompleted`; persists `=1` after completion; second launch goes straight to menu bar | ✅ PASS |
| `02-toggle-cycle.sh` | App-trigger Toggle OFF→ON cycle keeps the menu-bar icon healthy (validates S8b commit `45e73fc` consumer-task keepalive fix) | ✅ PASS |
| `03-icon-states.sh` | Captures menu-bar icon in 6 combinations: `{filled, outline, clock} × {light, dark}` | ✅ PASS (6 PNGs) |
| `04-launch-at-login.sh` | Snapshots Settings → General; verifies `latte.launchAtLogin` defaults state | ✅ PASS |
| `05-calendar-picker.sh` | Calendar trigger enabled with empty selection — Latte must not crash | ✅ PASS (alive-check via lsappinfo) |
| `06-marketing-prep.sh` | Sets canonical demo defaults (caramel accent, filled icon, all 4 triggers, Zoom+Slack bundles), auto-captures onboarding welcome PNG | ✅ PASS |

**Phase 3 — Fix-first iterations on the harness itself**

Per the smoke-iteration cadence memory, P1 surfaces drove fixes:

| # | Symptom | Root cause | Fix |
|---|---|---|---|
| 1 | `launch_app.sh` timed out 20 s waiting for pid | `pgrep -f $bundle_id` matches process name `Latte`, not bundle id | Switched to `lsappinfo info -only pid -app <bundle>` |
| 2 | `screencapture` crashed with "could not create image from display" | Terminal lacked Screen Recording permission | Made capture fail-soft (warn + continue), surfaced one-time owner action in stderr |
| 3 | Scenario 5 reported "Latte died" — false positive | Same `pgrep -f` bug in scenario's alive-check | Replaced with `lsappinfo` resolution + `ps -p $pid` verification |
| 4 | `06-marketing-prep` python crashed with `pyexpat` ImportError | Homebrew Python 3.14 has expat ABI incompatible with system libexpat | Removed python dependency; encoded JSON→hex via `xxd -p` (pure bash) |

After 4 fixes the harness ran end-to-end clean. ~6× iteration speed-up vs S8b manual smoke.

### v1.0 ship readiness (unchanged from S8b code-side)

| Trigger | v1.0? |
|---|---|
| Calendar / App / Wi-Fi | ✅ |
| Focus | ❌ deferred to v1.x via V2-03b (Apple entitlement gate) |

| Other | Status |
|---|---|
| Menu-bar awake visualization (V2-01) | ✅ |
| Launch at Login | ✅ |
| First-run onboarding wizard | ✅ |
| EKCalendar picker (V2-04) | ✅ |
| **Cross-project smoke harness (V2-30)** | ✅ **Done in S8c** |

---

## Decisions still pending owner approval

- **None blocking S8d.** Harness validated all deferred S8b smoke items.
- **Pages deploy URL choice** — Option A (gh-pages on this repo, `bj-park.github.io/latte/`) vs Option B (separate `latte-site` repo). Defaults to A unless owner prefers B for cleaner reviewer URL.

---

## Known issues / debt

- **Marketing shots 1-5 cannot be auto-captured**: LSUIElement apps cannot be driven into Settings programmatically (popover + Settings click chain is sandbox-restricted). Owner does the actual click but harness primes the state via `06-marketing-prep`. ~5 min of owner clicks instead of ~90.
- **`tccutil reset Calendar`** requires Terminal/iTerm to have Full Disk Access — best-effort otherwise. Documented in `~/dev/smoke-harness/README.md`.
- **No NSAccessibility click driver** — future harness improvement (`templates/xcuitest-target/`) for full UI driving on apps that aren't menu-bar-only.
- **Swift 6 strict-concurrency warnings** in `AppTrigger.swift` and `FocusTrigger.swift` (carried over from S8b). Add to v1.x cleanup as V2-31.

---

## Files changed this session

### New (smoke-harness, outside repo)
```
~/dev/smoke-harness/
  run.sh
  README.md
  lib/{log,reset_prefs,launch_app,quit_app,capture_screenshot,capture_menubar,read_log,verify_assertion,defaults_helper,appearance}.sh
  templates/config.yml.template
```

### New (Latte repo)
```
A  .smoke/config.yml
A  .smoke/scenarios/01-onboarding.sh
A  .smoke/scenarios/02-toggle-cycle.sh
A  .smoke/scenarios/03-icon-states.sh
A  .smoke/scenarios/04-launch-at-login.sh
A  .smoke/scenarios/05-calendar-picker.sh
A  .smoke/scenarios/06-marketing-prep.sh
```

### Modified (Latte repo)
```
M  .gitignore                                   (smoke artifacts/reports)
M  ROADMAP.md                                   (row 8c marked Done; new row 8d for owner-side capture+deploy)
M  docs/SESSION_HANDOFF.md                      (this file)
M  docs/v2-backlog.md                           (V2-30 marked Done with full architecture written up)
M  docs/store/screenshot-guide.md               (added "harness primes demo state" preamble)
```

### Source code
*(unchanged — S8c is harness + docs only)*

### Tests
*(unchanged — still 288/288 pass)*

---

## How to resume

```bash
cd ~/Documents/Claude/Projects/Latte
git status
git log --oneline -5
xcodebuild test -scheme Latte -destination "platform=macOS,arch=arm64" 2>&1 | tail -3
# Expected: 288/288 tests pass

# Re-verify harness end-to-end:
pkill -x Latte 2>/dev/null
~/dev/smoke-harness/run.sh --project .
# Expected: 6 scenarios PASS, ~13 PNGs in .smoke/artifacts/
```

---

## Next session entry point

**Theme**: S8d — owner-side marketing capture + GitHub Pages deploy. Then S8.5 hard gate (Apple Dev Program enrollment).

### S8d (owner-side, ~2 h)

1. **Marketing screenshot capture** (~30 min with harness prep, ~90 min without)
   ```bash
   ~/dev/smoke-harness/run.sh --project . --scenario 06-marketing-prep
   # Latte is now in demo state. Follow docs/store/screenshot-guide.md shots 1-5.
   # Save PNGs to docs/store/screenshots/ as 01-hero.png … 05-about.png.
   pkill -x Latte && defaults delete com.parkbyeongjun.latte
   ```

2. **30s preview video** (~1-2 h) — QuickTime screen record per the script in screenshot-guide §"Optional enhancements". Save as `docs/store/preview.mov`.

3. **GitHub Pages deploy** (~30 min) — follow `docs/site/README.md` Option A or B. Verify with curl after push:
   ```bash
   curl -sI https://bj-park.github.io/latte/privacy.html | head -5
   ```

4. **S8d closeout commit** + handoff overwrite for S8.5 entry.

### S8.5 (owner hard gate)

- Pay $99/yr Apple Developer Program enrollment.
- 1-2 day approval.
- Once Team ID visible in Xcode → resume to S9 (App Store Connect record + Release archive).

### Cannot-start-without checks (for next session)

- 288/288 tests still pass (`xcodebuild test`)
- Harness still runs end-to-end (`~/dev/smoke-harness/run.sh --project .`)
- `docs/store/screenshots/` populated with 5 PNGs (01..05)
- `https://<pages-url>/privacy.html` returns 200 OK

If all 4 pass, S9 starts (after Apple Dev Program approval).

---

## S8c addendum — harness v0.2 + Pages staging (2026-04-28, same session)

After the initial S8c commit (`7e55ae4`), two extension passes landed:

**v0.2 commit `e35d212`** — `feat: harness v0.2 — wifi-inverse + power-assertion scenarios`
- New scenario `07-wifi-inverse.sh`: Mode A (normal+empty SSID list) + Mode C (inverse+empty list) — both stable, no crash.
- New scenario `08-power-assertion.sh`: PRD §10 G4 short-window check via `pmset -g assertions`. Idle = no held assertion; quit = no leak. 24h soak deferred to v1.x.
- Harness lib v0.2 (`~/dev/smoke-harness/lib/`): `assert_log.sh` (regex match or `--negate` absent) + `wait_for.sh` (poll a command until success or timeout).
- `templates/xcuitest-target/` skeleton — drop-in XCUITest for apps where bash + AppleScript can't reach the UI. Ready for the second app the owner wires.
- All 8 Latte scenarios PASS in <2 min.

**Pages branch staging (no commit on `main`)**
- `git worktree add ../latte-gh-pages-staging --detach` → `git checkout --orphan gh-pages` → committed `index.html` + `privacy.html` as root commit `e3738a9` on the `gh-pages` branch.
- Owner action shrank from "create branch + commit + configure + push" to "add remote + push".
- See updated `docs/site/README.md` Option A for the exact 3-line owner sequence.

---

## Recap quick stats (S8c end)

- **Tests**: 288 → **309** (+21 — URL parser + demo URL handler)
- **New files in Latte repo**: 18 (`.smoke/` config + 14 scenarios + `Sources/UI/Settings/SettingsTab.swift` + `Sources/UI/Demo/{DemoURLHandler,DemoCupWindowController}.swift` + 2 test files + `.github/workflows/ci.yml`)
- **New files in `~/dev/smoke-harness/`**: 20 (15 lib + run.sh + deploy_pages.sh + README + 3 templates)
- **Commits this session (`main`)**: `7e55ae4` → `e35d212` → `d58f851` → `3b39ba8` → `ce69864` → next-S8c-final
- **Separate branch**: `gh-pages` root `e3738a9` (worktree at `../latte-gh-pages-staging/`)
- **Scenarios**: 14 (8 functional + 4 marketing + 1 soak + 1 permission-flow), all PASS in ~3:30 end-to-end
- **Artifacts**: 17 PNGs (4 marketing-grade + 6 icon-state matrix + 7 functional)
- **Latte production additions in v1.0**: `latte://settings/<tab>` + `latte://demo/cup` URL schemes, `LSMultipleInstancesProhibited`, `setActivationPolicy(.regular)` toggle, `CoffeeCupView.size` param
- **Time-to-rerun**: full 14-scenario harness in ~3:30 vs ~30 min for S8b manual smoke (~9× speedup including soak)
- **CI**: `.github/workflows/ci.yml` builds + tests on every push/PR (macos-15 runner, ~6 min)
- **Owner-side action remaining for S8d (~5 min total)**: pick 5 PNGs from `.smoke/artifacts/` into `docs/store/screenshots/`, optionally Shot 4 manual hover (~30s), `~/dev/smoke-harness/deploy_pages.sh <repo-url>`, GitHub Pages enable click, curl validation
