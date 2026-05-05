# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S28** — Smoke harness rebuild gate + feature-presence assertion (2026-05-05). Same-day continuation of S27. Closes the **S27 stale-binary infrastructure discovery** without touching Latte source. Step A added the `xcodebuild build -configuration Release` rebuild gate to `~/dev/smoke-harness/run.sh` (cross-project, owner-local) so the harness no longer runs scenarios against a pre-existing stale `Build/Products/Release/Latte.app`; gate is config-driven (3 optional `build_*` keys) and includes a `--no-build` escape hatch. Step B added `~/dev/smoke-harness/lib/assert_binary_type.sh` (cross-project, owner-local) — a `nm \| swift-demangle \| grep` wrapper that asserts a Swift type symbol is present in the running binary. Per-scenario assertion calls landed in 4 scenarios (`18-schedule`, `20-external-display`, `21-shortcut-recorder`, `22-activity-log`) so a stale or feature-stripped binary FAILs the scenario with a clear diagnostic instead of falsely PASSing on URL routing + window capture. Step C (S8d Pages) deferred — owner has no decision yet on GitHub username / `gh` vs web UI / SSH key status. |
| **Theme** | "S27 owner-confirmed P-issue claims rest on the new binary, not the v1.2 binary owner had been running for 5 days. Two infrastructure gaps caused the stale-binary class of false positive: (1) `xcodebuild test` rebuilds the test bundle but not the standalone Release `.app`, so smoke runs after `xcodebuild test` could be against any prior Release build; (2) smoke scenarios verify URL routing + window capture only — neither introspects whether the feature under test is even compiled into the binary. S28 closes both: gate the harness on source-vs-binary mtime (cheap, deterministic, no penalty when up to date) and add per-scenario `assert_binary_type` calls that grep the demangled symbol table for the type implementing the feature. The `nm \| swift-demangle \| grep` primitive is the cheapest "is feature X compiled in?" check — works without running the app, without NSAccessibility, without source-side instrumentation. Acceptable floor: catches "type was removed entirely" but not "type's body was emptied or render no-op'd"; the latter is owner-manual-smoke territory anyway. **Cross-project tooling commit split**: harness-side changes (run.sh / new lib helper / README) live in `~/dev/smoke-harness/` (owner-local, not git-tracked); Latte-side changes (config keys + scenario assertion calls) commit here. Future repo readers see only the per-project knobs; the cross-project plumbing serves the other 9+ macOS apps in the pipeline." |
| **Status** | ✅ **2 code commits** (`beae984` Step A — `.smoke/config.yml` build-gate keys, +9 lines; `7d10ef4` Step B — scenario assertion calls, +35 lines across 4 files) + this docs commit. **Tests 587/587 PASS in 9.08s** (no Latte source touched in S28). **Smoke 22/22 PASS** with rebuild gate active and 4 feature-presence assertions firing GREEN on fresh binary. **Negative test verified**: bogus pattern `\bLatte\.NoSuchTabZZZ\b` in scenario 22 fires the assertion red and FAILs the scenario with rc=1 and a clear "stale or feature-stripped binary" message. **Step A reverify** (3 cases): up-to-date binary → `rebuild = up to date` skip; touched source → `STEP rebuild (source newer than binary)` triggers + binary mtime updated to post-build; `--no-build` flag with stale source → `skipped (--no-build)` no rebuild + binary unchanged. Working tree clean (excluding `.claude/`). |
| **Tail commit** | `7d10ef4` (Step B) + this docs wrap commit. Step A = `beae984`. |

### Commit chain (S28 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF + ROADMAP wrap for S28                                  (S28 #3)
7d10ef4        test(smoke): feature-presence assertion for scenarios 18/20/21/22 (Step B)    (S28 #2)
beae984        chore: smoke-harness rebuild gate config keys (Step A)                        (S28 #1)
```

### What landed this session

| Step | Resolution path | Tests Δ |
|---|---|---|
| A — Smoke harness rebuild gate (commit `beae984`) | `~/dev/smoke-harness/run.sh` (owner-local, not in this repo) gained: (1) optional rebuild stanza driven by 3 new YAML keys (`build_command`, `build_source_dir` defaults `Sources`, `build_binary_path` with `~` expansion) — empty `build_command` skips gate (preserves non-Xcode projects); (2) `--no-build` flag on `run.sh` for "use whatever's there" iteration on the harness itself; (3) mtime check via `find <source_dir> -type f -newer <binary> -print -quit \| grep -q .` returns the first newer source file in milliseconds and short-circuits — runs trigger rebuild, no hits skip; (4) explicit "binary missing" branch always rebuilds (covers first run); (5) `eval "$BUILD_COMMAND"` in a `cd "$project"` subshell so harness CWD doesn't drift; (6) fail-fast on rebuild error with exit 6 (before launching scenarios). README updated with "Required keys" + "Optional rebuild gate (recommended for Xcode projects)" tables and `--no-build` flag docs. **In this repo**: `.smoke/config.yml` gained the 3 keys (+9 lines). **Verified** 3 scenarios: up-to-date binary → "rebuild = up to date"; touched source file → "STEP rebuild (source newer than binary): xcodebuild ..." + post-rebuild mtime > source mtime + subsequent run is "up to date"; `--no-build` with stale source → "skipped (--no-build)" + binary mtime unchanged. Full smoke 22/22 PASS regression after gate landed. | 0 |
| B — Feature-presence assertion (commit `7d10ef4`) | New helper `~/dev/smoke-harness/lib/assert_binary_type.sh` (owner-local): takes `<binary-path> <demangled-pattern> [label]`, runs `nm "$bin" \| xcrun swift-demangle \| grep -cE "$pat"` (each `\| true`-guarded against `pipefail` no-match exit so the count drives the result), exits 0 on `count > 0` with `smoke_ok` log, exits 1 on `count == 0` with `smoke_error` "stale or feature-stripped binary". Exit codes 2/3/4 cover bad usage / missing binary / missing toolchain. **In this repo**: 4 scenarios gained an assertion call right after `set -euo pipefail` + log source, before any `reset_prefs`/`launch_app` work — so a stale binary fails fast with a clear diagnostic instead of mysteriously breaking later. Patterns chosen: `\bLatte\.ScheduleTrigger\b` (18), `\bLatte\.ExternalDisplayTrigger\b` (20), `\bLatte\.KeyboardShortcutCoordinator\b` (21), `\bLatte\.ActivityTab\b` (22). Word-boundary anchors prevent partial matches against demangled subsymbols. **Negative test**: temporarily replaced scenario 22's pattern with `\bLatte\.NoSuchTabZZZ\b`, ran `--scenario 22-activity-log`, harness output: `ERROR 22-activity-log: pattern '\bLatte\.NoSuchTabZZZ\b' NOT in Latte — stale or feature-stripped binary` + `ERROR scenario 22-activity-log FAILED rc=1` + `1 scenario(s) failed`. Pattern restored. Full smoke 22/22 PASS regression after assertions landed. | 0 |
| C — S8d Pages owner-blocked | Inspected pre-conditions: Latte main repo has no remote, staging worktree at `../latte-gh-pages-staging/` is on `gh-pages` branch with 1 commit and no remote, `scripts/{deploy_pages,validate_pages}.sh` are present and executable (S26 landed them), but `gh` CLI is **not installed** on this machine. Owner has 3 open decisions: (1) GitHub username (script default is `bj-park`, not confirmed); (2) `brew install gh` + `gh repo create` vs web-UI repo creation + manual `git remote add origin`; (3) SSH key registration status (alternative is `gh auth login` for HTTPS+token). Owner noted "1,2,3 결정된 거 없음" — defer to next session. Cold-start instructions (below) include the exact 4-step decision sequence that unblocks S8d once owner answers the three. | 0 |

### Patterns reinforced this session

- **`xcodebuild test` rebuilds the test bundle but not the standalone Release `.app`** (Step A) — confirmed in S27 discovery, codified in S28 rebuild gate. CI / smoke harnesses must run `xcodebuild build -configuration Release` explicitly when their scenarios target the Release `.app`. Without it, scenarios run against whatever the most recent `xcodebuild build -configuration Release` produced — which can be days or weeks stale.
- **mtime-based rebuild gate over unconditional rebuild** (Step A) — `find <source_dir> -type f -newer <binary> -print -quit \| grep -q .` runs in milliseconds for typical Swift projects (~50-500 files) and short-circuits at the first hit; "no source change" runs stay at full speed (no ~30s rebuild penalty). The "newer than binary mtime" semantic is more defensible than wall-clock thresholds because it follows what the source-control system records, not when the developer happened to run the harness.
- **`nm \| xcrun swift-demangle \| grep` is the cheapest "is feature X compiled in?" check** (Step B) — works without running the app, without NSAccessibility permission, without source-side instrumentation, without OSLog signposts. Trade-off: only catches "type was removed entirely" (rename to a different name, or `#if false` exclusion, or git revert wiping the file); does NOT catch "type's body was emptied or render no-op'd." That's an acceptable floor for closing the URL-routing-fallback false-positive class — owners can still hit the latter case but at least won't be surprised when a v1.2-era binary lacks a v1.9 type entirely.
- **Cross-project tooling commits split: harness changes go to owner-local tree, project-specific config goes in repo** (Steps A+B) — Latte's commits only touch `.smoke/config.yml` + 4 scenario files (44 lines added across them). The cross-project plumbing (`run.sh` rebuild gate logic, `lib/assert_binary_type.sh` helper, `README.md` docs) lives in `~/dev/smoke-harness/` which is owner-local and not git-tracked. Future Latte repo readers see only the per-project knobs (build keys + scenario assertion calls); the cross-project infrastructure serves the other 9+ macOS apps in the owner's pipeline. The split is also bisect-friendly — if a regression appears in a future Latte commit, `git bisect` is over a small surface; if the harness itself regresses, the bisect surface is the harness tree.

### What was checked but not changed

- 21-shortcut-recorder.sh / 18-schedule.sh / 20-external-display.sh / 22-activity-log.sh — read in full to identify the post-`set -euo pipefail` insertion point. No structural changes; all assertions inserted before the existing `reset_prefs.sh` invocation.
- ROADMAP rows 1-25 (S1-S26 history) — ROADMAP.md is over 38KB and exceeds the read-tool limit; updated only the S28 row insertion + header status + version row. Earlier history untouched.
- v1.x autonomous-coding backlog list — unchanged from S27. Owner-blocked: S8d Pages deploy, S8.5 Apple Dev Program (awaiting Apple), S9 ASC meta (depends on S8.5), V2-22 GitHub remote. Multi-session candidates needing owner direction: C-3 iCloud sync of activity history, B1.2 deferred (per-action chords / iCloud chord sync), V2-06 lid-closed-only mode + per-display position requirement.

### What was deferred to a later session

- **S22~S27 P-issue re-verification queue** — owner confirmed all 21 P-issue fixes against the fresh May 5 binary at the start of S28 ("다 잘 진행됨 / 다 존재"). Considered closed unless owner surfaces specific regressions in subsequent manual smoke. The S27 worry that some "fix confirmed" claims might have been "feature wasn't even in the binary owner was running" did not materialise — all 21 P-issues hold against the fresh binary.
- **Step C — S8d Pages owner-blocked walkthrough** — defer entirely to S29 / first owner-driven session because owner has no current decision on (1) GitHub username, (2) `gh` CLI vs web UI, (3) SSH key status. Pre-conditions ready: scripts present + executable, staging worktree on `gh-pages` with 1 initial commit, Latte main repo clean.
- **Default chord change for ⌘⇧L** — still tracked as "consider only if systematic collision evidence emerges" (S27 patterns memo). No new evidence in S28.

The v1.x autonomous-coding backlog after S28:
- Owner-blocked: S8d Pages deploy (one-command after the 3 decisions land), S8.5 Apple Dev Program (awaiting Apple), S9 ASC meta (depends on S8.5), V2-22 GitHub remote.
- Multi-session candidates that need owner direction: C-3 iCloud sync of activity history, B1.2 deferred (per-action chords / iCloud chord sync), V2-06 lid-closed-only mode + per-display position requirement.
- Single autonomous candidates that don't fit S28-style "infrastructure close-out": none currently identified.

---

## Next-session entry points (priority order)

**0. (HIGH) S8d Pages owner-blocked unlock** — Owner makes 3 decisions, then ~5 minutes of mechanical work:
   - **Q1**: GitHub username? Script default is `bj-park` (`gh repo create bj-park/latte`). Confirm or override.
   - **Q2**: `gh` CLI or web UI? `gh` path: `brew install gh` + `gh auth login` + `gh repo create <USER>/latte --public --source=. --remote=origin --push` (pushes main in one shot). Web path: https://github.com/new (Public, no README/license/gitignore — repo must be empty for `git push -u origin main` to work) + manual `git remote add origin git@github.com:<USER>/latte.git` + `git push -u origin main`.
   - **Q3**: SSH key registered to GitHub account? If no: either register one at https://github.com/settings/keys (preferred, persists) or use HTTPS clone URL + `gh auth login` token (works but re-auth on token expiry).
   - **Then**: `cd ../latte-gh-pages-staging && git remote add origin <repo-url> && git push -u origin gh-pages`. GitHub web → Settings → Pages → Source = `gh-pages` branch, `/ (root)`. Wait ~1 min for CDN. Run `scripts/validate_pages.sh https://<USER>.github.io/latte/` to confirm 200 + content-type + non-empty title on `/` and `/privacy.html`.
   - **Output**: `docs/site/{index,privacy}.html` live at `https://<USER>.github.io/latte/`. V2-22 (GitHub remote on main repo) lands as a side-effect of step Q2.

**1. (BLOCKER) Owner-blocked S8.5** (Apple Dev Program — applied 2026-05-02). 1-2 days awaiting Apple.

**2. (BLOCKER) Owner-blocked S9** (App Store Connect; depends on S8.5).

**3. (LOW) Smoke harness rebuild gate adoption in other projects** *(carried from S27 cross-project goal)* — once S28 is owner-validated on Latte (this session), apply the same `build_command` / `build_source_dir` / `build_binary_path` keys to the `.smoke/config.yml` of the next 1-2 projects in the pipeline. The harness `run.sh` change already supports them (no further harness-side work). Lift-and-shift effort per project: ~3 lines + verification run.

**4. (LOW) C-3 iCloud sync of activity history** + **B1.2 iCloud chord sync** — joint design (CloudKit + conflict resolution). Multi-session, requires owner direction on whether/when to start.

**5. (LOW) V2-06 still-deferred**: lid-closed-only mode, per-display position requirement.

**6. (LOW) B1.2 still-deferred** (per 07-spec §1): per-action chords, false-negative chord-reserved indicator (the iCloud part overlaps with C-3 #4 above).

**7. (LOW) Smoke scenario coverage extension** — S28 added `assert_binary_type` to the 4 scenarios where the S27 stale-binary discovery bit (`18`/`20`/`21`/`22`). Older scenarios (`01`-`17`, `19`) do not have assertions because their features are v1.0~v1.1 and stale-binary risk is lower. If owner wants symmetric coverage, ~10 scenarios would each gain one assertion line — half-hour effort. Not on the hot path; worth doing only if a future stale-binary recurrence shows up in scenario 13/15/16/17.

S28 is an infrastructure close-out session. v1.x version unchanged at v1.9.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -8

# S28 NEW: harness now rebuilds Release automatically — explicit step optional but cheap to verify
xcodebuild -scheme Latte -configuration Release build -quiet 2>&1 | tail -3
stat -f "%Sm  %N" ~/Library/Developer/Xcode/DerivedData/Latte-hcfmwngrrkeynehkwodtxrrnyxyq/Build/Products/Release/Latte.app/Contents/MacOS/Latte   # confirm mtime ≥ today

xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 587 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
                                         # Harness rebuild gate runs first; "rebuild = up to date" if nothing changed
```

**Expect**: 587/587 tests PASS in ~9s. Release binary mtime = today (gate auto-rebuilds if source touched). Smoke 22/22 PASS in ~6:14 with feature-presence assertions firing GREEN at the top of scenarios 18/20/21/22.

**Diagnostic stream (carry over from S24)**: `/usr/bin/log stream --predicate 'subsystem == "com.parkbyeongjun.latte" AND category == "activity"' --info --debug --style compact` (`--info --debug` flags are mandatory or info-level logs are silently filtered).

**Note**: S16-S28 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory. **S27 lesson still applies**: a flaky 13-soak-short failure right after `xcodebuild test` is the same zombie-residue pattern (Latte.app from xcodebuild's test runner left around) — kill + retry (or wait the smoke harness's own `quit_app` step) clears it.

**S28 NEW useful**:
- Harness `--no-build` flag bypasses the rebuild gate (escape hatch when iterating on harness itself or owner explicitly wants to test against a known-old binary).
- Helper `~/dev/smoke-harness/lib/assert_binary_type.sh <binary> <demangled-pattern> [label]` is callable directly for ad-hoc "is type X in this binary?" checks.
- The `nm \| xcrun swift-demangle` primitive lists every Swift type/method/closure symbol in the binary — useful for `grep -oE "Latte\.[A-Z][A-Za-z0-9]*" \| sort -u` when picking patterns for new scenarios.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 27 (S28) for the most recent session, row 26 (S27) for the immediately prior session.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (now 14-line index) → drill into `project_latte_v1_9.md` for the S20→S27 section + (after this session's wrap) the S28 entry.
4. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S28 update)

| # | What | Why blocked | Effort |
|---|---|---|---|
| **S22~S27 P-issue queue** | **CLOSED this session** — owner verified all 21 fixes against fresh May 5 binary ("다 잘 진행됨 / 다 존재") | Was: 5 days of manual smoke against v1.2-era stale binary | 0 (closed) |
| **Verify fresh binary** | **CLOSED this session** — owner confirmed 7 features visible | Was: stale-binary discovery in S27 wrap | 0 (closed) |
| **S8d Q1+Q2+Q3** | Owner decides: GitHub username, `gh` vs web UI, SSH key status. Then ~5 min mechanical work to push main + gh-pages + enable Pages + run `scripts/validate_pages.sh`. | Owner-only decision sequence | ~5 min after decisions |
| S8.5 | Apple Developer Program — applied 2026-05-02 | Awaiting Apple review | 1-2 days |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push (main branch) — auto-completed via S8d Q2 path | Same dependency chain as S8d | 0 marginal |

---

## v1.9 owner-visible behavior reference (post-S28, no behaviour change)

S28 changed no Latte runtime behaviour — only smoke harness infrastructure (rebuild gate) and per-scenario assertion calls. The reference list below is unchanged from S27 wrap.

- Activity tab no longer flashes the empty-state placeholder ("Trigger fires will appear here") on the first-ever entry per app launch (S25 P-issue-4 — pre-loaded at boot via `AppEnvironment.activityEntries`).
- Activity tab no longer offers Export CSV / Export JSON (feature removed S24 — non-functional across multiple fix attempts).
- Activity tab no longer flashes a spinner-only frame on first entry (S24 P-issue-2).
- Activity tab no longer flashes the previous scroll position on every tab re-entry (S24 P-issue-3 — first-load gate).
- Recurring Quick presets render an active marker (left coffee-accent stripe + right checkmark) on the picked preset row, not on Custom (S23 P-issue-2 + P-issue-3).
- All three popover row types (duration / custom / recurring preset) show consistent left stripe + right checkmark when active (S23 P-issue-3 universal stripe).
- "Until X" caption shows the target wall-clock minute (e.g. "12:00 AM" for midnight preset), never one minute before due to whole-minute precision (S23 P-issue-1).
- Activity tab Retention is a Picker (1 day / 1 week / 2 weeks / 1 month / 2 months / 3 months), not a Stepper. Switching retention does not collapse the chart sections (S23 P-issue-4).
- **S26 P1 / verified S27**: Popover footer ⌘Q quits Latte from inside the popover. Carbon-registered global awake-toggle chord (default ⌘⇧L, owner rebound to ⌘⌃L in S27) is unaffected (passes through). System ⌘⇧Q (log out) passes through.
- **S27**: ⌘, in popover passes through (no longer opens Settings — shortcut removed; mouse → Settings… footer button is the supported path).

Carryover from earlier sessions (unchanged):

- v1.0~v1.8 owner-visible feature set (5 trigger types, custom presets, activity log, theme customisation, etc.)
- S22 fixes: pause-all snooze caption, Turn off "big red button" (disables all triggers), HeaderView caption gates, cross-trigger pause-lift auto-recovery, recurring presets light-mode visuals.

---

## ⌘⇧L behaviour reference (read before next chord-related work)

Unchanged from S27 wrap. **`AwakeManager.toggle()` at line 683 ALREADY implements** "if caffeinate ON → Turn off (disable all triggers); if caffeinate OFF → Indefinitely activate" — no code change pending. Future ⌘⇧L-related work (e.g., per-action chords for B1.2 deferred) builds on this.

```
AwakeManager.toggle():
  if state.assertionHeld {
      process(.constraintDeactivate)
      postUserExplicitDeactivateIfTransitioned()  // disableAll()
  } else {
      process(.userActivate(.indefinite))
  }
```

Don't re-research this in a future session — the behaviour is correct, only the chord (default ⌘⇧L, owner-rebindable) is collision-prone.

---

## Smoke harness infrastructure reference (S28 NEW)

**Where the rebuild gate lives**: `~/dev/smoke-harness/run.sh` (owner-local, NOT git-tracked). Compares newest source mtime under `<project>/Sources` (or whatever `build_source_dir` says) to the binary mtime; rebuilds via `build_command` if any source is newer or binary is missing. `--no-build` flag skips the gate.

**Where the feature-presence helper lives**: `~/dev/smoke-harness/lib/assert_binary_type.sh` (owner-local, NOT git-tracked). Pattern: `nm <bin> \| xcrun swift-demangle \| grep -cE <pattern>` returns 0 with `smoke_ok` if count > 0, else 1 with `smoke_error` "stale or feature-stripped binary".

**Per-scenario assertion call template** (already in 18/20/21/22):

```bash
bash "$HARNESS_LIB/assert_binary_type.sh" \
  "$SMOKE_APP_PATH/Contents/MacOS/Latte" \
  '\bLatte\.YourTypeName\b' \
  "scenario-name-for-log" >/dev/null
```

Insert right after `set -euo pipefail` + `source "$HARNESS_LIB/log.sh"` so the assertion runs before `reset_prefs`/`launch_app`. A stale binary fails the scenario before any UI work happens, with the diagnostic visible in `harness/run.sh`'s output.

**Adoption checklist for the next macOS app** (V2-30 cross-project leverage):

```yaml
# .smoke/config.yml
build_command: xcodebuild -scheme <App> -configuration Release build -quiet
build_source_dir: Sources                                                # or wherever
build_binary_path: ~/Library/Developer/Xcode/DerivedData/<App>-<hash>/Build/Products/Release/<App>.app/Contents/MacOS/<App>
```

Then add `assert_binary_type` calls to scenarios that test specific features. Helper takes any Swift type pattern; `\bAppName\.TypeName\b` is the recommended form.
