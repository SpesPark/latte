# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S24** — Step 8 owner-driven Activity-tab manual smoke (2026-05-05). **Three P-issues** all in `Sources/UI/Settings/ActivityTab.swift`. One fix commit + this doc-sync. |
| **Theme** | "Step 8 surfaced that the S23 P-issue-5 Export fix never actually worked, then surfaced two pre-existing flickers that prior sessions never noticed because no one had paged through the tab with intent. Owner called Export removal after three failed fix attempts; the two flickers split into a fixed one (`.task` re-fire on every tab re-entry) and a deferred one (cold-start empty-state frame on first-ever entry). Diagnostic lesson of the day: `os.Logger.info` is filtered out by `log stream` defaults, so a working closure with info-level logs looks identical to a non-firing one. Always pass `--info --debug` first, before suspecting the closure." |
| **Status** | ✅ **1 fix commit** (`0e13546`) + this docs commit. **Tests 581 → 574** (-7, all from removed `ActivityLogExporterTests.swift`). Smoke unchanged at 22 (export was never harness-covered). Working tree clean (excluding `.claude/`). |
| **Tail commit** | `0e13546` (feat: Activity tab — remove non-functional Export + eliminate spinner / re-entry flickers — S24 / P-issues 1+2+3) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S24 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF + ROADMAP wrap for S24                          (S24 #2)
0e13546        feat: ActivityTab — remove Export + eliminate spinner / re-entry      (S24 #1)
               flickers (P-issues 1+2+3)
```

### What landed this session (3 P-issues)

| P# | Resolution path | Tests Δ |
|---|---|---|
| P1 | Activity tab Export CSV / Export JSON **removed entirely**. Owner called this after three fix attempts: S23 P-issue-5 (inline-as-Section-rows + `.buttonStyle(.bordered)`) failed; S24 attempt 1 (move buttons OUT of Form into a footer `HStack` to bypass Form Section row tap-handling) failed; S24 attempt 2 (`NSApp.activate(ignoringOtherApps: true)` + `panel.level = .modalPanel` to handle menu-bar-app modal restoration) failed. NSSavePanel never appeared on owner's machine and `[activity] export tap` info-level log never emitted on `subsystem == "com.parkbyeongjun.latte"` even after raising the log-stream filter to `--info --debug`. Strong evidence: Button action closure itself never fires in any of the three configurations. Removed `Sources/Core/ActivityLogExporter.swift` (only consumer was ActivityTab), `Tests/ActivityLogExporterTests.swift` (-7 tests), Export buttons / footer / `export(_:as:)` / VStack wrapper / `import AppKit` + `import UniformTypeIdentifiers` from ActivityTab.swift. | -7 |
| P2 | Spinner-only frame on cold load. `@State private var isLoading = true` initial value caused a 1-2 frame "ProgressView only" render at the top of an otherwise mostly-empty Form before charts were inserted on `await store.snapshot(...)` return. Owner perceived this as Activity-tab flicker on first entry. Removed `isLoading`, the `if isLoading { ProgressView() }` branch, and the `showSpinner` parameter on `reload(...)`. Layout transitions empty-state → charts directly without the dramatic spinner-only intermediate frame. | 0 (UI-only) |
| P3 | Scroll-position re-entry flicker. SwiftUI `.task` cancels on view disappear and re-fires on every re-appear, so every Activity-tab re-entry re-ran `reload()` even when the snapshot was identical. The redundant `entries = await store.snapshot(...)` triggered a Swift Charts re-render of the bar / heatmap / daily-totals views, and the NSScrollView under `.formStyle(.grouped)` briefly resettled — owner reported "previous scroll position flashes for a few frames before the live render takes over" on every tab re-entry (showed bottom region when previously at bottom; showed retention region when previously at top). Gate first-time load with `@State private var hasLoaded = false`; subsequent re-entries skip reload. Incremental updates flow through `.onReceive(.activityLogDidAppend)` and the retention `.onChange`. Owner-confirmed flicker eliminated post-fix. | 0 (UI-only) |

### Patterns reinforced this session

- **`os.Logger.info` requires `log stream --info` to surface** (P-issue-1 diagnostic) — info-level logs are filtered by default; without the flag a working closure looks indistinguishable from a non-firing one. **First diagnostic step when an action closure logs nothing: re-run the stream with `--info --debug`** before suspecting the closure itself.
- **Subsystem case sensitivity in `log stream` predicates** (P-issue-1 diagnostic) — `com.parkbyeongjun.Latte` (capital L) and `com.parkbyeongjun.latte` (lowercase l) are different subsystems for filtering purposes; always verify the actual subsystem string from `LatteLog.subsystem` against the filter rather than reproducing it from memory.
- **Three failed fix attempts is the right time to remove a feature** (P-issue-1 redesign) — when each attempt addressed a different theory (Form Section row swallowing → footer relocation → menu-bar app modal restoration) and none surfaced even an action-closure log, the closure isn't firing for a reason the fix attempts aren't reaching. Cost-benefit gates removal: feature was niche (raw activity-log export to CSV/JSON), tab retains value without it (filter / charts / retention picker / chart colors / live polling / click-row jump), so removal is cleaner than continuing to ship broken.
- **`@State` initial values that drive a layout branch produce a guaranteed flicker frame on every view (re-)creation** (P-issue-2) — `isLoading = true` initial render → reload await → false render is two distinct visual states even when the await is sub-frame-fast, because SwiftUI commits at least one frame between state mutations. If the initial state branch's layout differs dramatically from the post-load layout, owner perceives flicker. Remove the loading-only branch and render the entries-driven layout from frame 0; live updates flow through notifications.
- **`.task { await reload() }` re-fires on every tab re-entry** (P-issue-3) — TabView (macOS) cancels `.task` on disappear and restarts on appear. Even when data is unchanged, writing back to `@State` triggers a SwiftUI body re-evaluation that can resettle NSScrollView under `.formStyle(.grouped)`, surfacing as scroll-position flicker. Gate first-time load with a `hasLoaded` flag; subsequent updates flow through `.onReceive` notification listeners and explicit `.onChange` reloads.
- **Single-load gate + notification-driven incremental updates is the cleanest data lifecycle for a TabView child** (P-issue-3 implication) — load the snapshot once when the tab is first opened, then reflect mutations via NotificationCenter posts. The tab can be switched away and re-entered as many times as the user wants without triggering redundant fetches or layout side effects.

### What was checked but not changed

- Activity tab: filter chips / 24h chart / 14d heatmap / DailyTotals chart / Currently active list / retention Picker / chart colour pickers / live polling / click-row jump — owner-confirmed all working in Step 8 manual smoke.
- General / Triggers / About tabs — unchanged from S23 ship state, no new owner-side issues surfaced.

### What was deferred to a later session

- **P-issue-4 (cold-start flicker)** — first-ever Activity tab entry after launching the app briefly shows the entries-empty chart-placeholder state ("Trigger fires will appear here") for 1-2 frames before the snapshot resolves and charts populate. Owner classified this as out-of-scope for S24. Likely fix path: hoist `entries` to a parent-owned cache (`AppEnvironment` or a `SettingsRoot @State`) so the snapshot is preloaded before ActivityTab is first rendered. Alternative: keep ActivityTab self-owned but render a chart-skeleton frame instead of the empty-state placeholder during the first await suspension.
- **Step 6 region 7** (B1.2 ⌘⇧L global hotkey, optional) carried over from S22 / S23 handoffs.

---

## Next-session entry points (priority order)

1. **P-issue-4 cold-start flicker fix** — hoist `entries` to parent or render chart skeleton during cold load. Smallest-scope owner-impact follow-up.
2. **Step 6 region 7** (B1.2 ⌘⇧L global hotkey, optional) if owner wants to close out Step 6 entirely.
3. **Owner-blocked S8d** (~5 min Pages deploy).
4. **Owner-blocked S8.5** (Apple Dev Program — applied 2026-05-02).
5. **Owner-blocked S9** (App Store Connect; depends on S8.5).
6. **C-3 still-deferred** (joint design with B1.2): iCloud sync of activity history + iCloud chord sync.
7. **V2-06 still-deferred**: lid-closed-only mode, per-display position requirement.
8. **B1.2 still-deferred** (per 07-spec §1): per-action chords, iCloud sync of chord, false-negative chord-reserved indicator.
9. **C-7 still-deferred**: Path B + Path C — both retired.
10. **V2-22 GitHub remote**.
11. **S22 P-issue-4 revisit** (low-priority): NSEvent.addLocalMonitor on popover-show to wire ⌘, / ⌘Q via direct key event handling rather than SwiftUI `.keyboardShortcut(...)`. Defer until owner explicitly requests, or a future macOS changes popover focus handling.

The v1.x feature backlog stays **functionally exhausted**, minus the cold-start flicker follow-up. S24 is a P-issue-driven UX-polish series — no version bump, still v1.9.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -8
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 574 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 574/574 tests PASS in ~9s. Smoke 22/22 PASS in ~6:14.

**Diagnostic stream for Activity-tab follow-up**: `/usr/bin/log stream --predicate 'subsystem == "com.parkbyeongjun.latte" AND category == "activity"' --info --debug --style compact` (S24 lesson: `--info --debug` flags are mandatory or info-level logs are silently filtered).

**Note**: S16-S24 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 23 (S24) for the most recent session, row 22 (S23) for the immediately prior session.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (now 14-line index) → drill into `project_latte_v1_9.md` for the S24 section (continues S20+S21+S22+S23).
4. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (unchanged from S22 / S23)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-9 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program — applied 2026-05-02 | Awaiting Apple review | 1-2 days |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## v1.9 owner-visible behavior reference (post-S24)

- Activity tab no longer offers Export CSV / Export JSON (feature removed S24 — non-functional across multiple fix attempts).
- Activity tab no longer flashes a spinner-only frame on first entry (S24 P-issue-2).
- Activity tab no longer flashes the previous scroll position on every tab re-entry (S24 P-issue-3 — first-load gate).
- Activity tab still briefly shows the empty-state placeholder ("Trigger fires will appear here") on the first-ever entry per app launch — known issue, deferred (S24 P-issue-4 next session).
- Recurring Quick presets render an active marker (left coffee-accent stripe + right checkmark) on the picked preset row, not on Custom (S23 P-issue-2 + P-issue-3).
- All three popover row types (duration / custom / recurring preset) show consistent left stripe + right checkmark when active (S23 P-issue-3 universal stripe).
- "Until X" caption shows the target wall-clock minute (e.g. "12:00 AM" for midnight preset), never one minute before due to whole-minute precision (S23 P-issue-1).
- Activity tab Retention is a Picker (1 day / 1 week / 2 weeks / 1 month / 2 months / 3 months), not a Stepper. Switching retention does not collapse the chart sections (S23 P-issue-4).

Carryover from earlier sessions (unchanged):

- v1.0~v1.8 owner-visible feature set (5 trigger types, custom presets, activity log, theme customisation, etc.)
- S22 fixes: pause-all snooze caption, Turn off "big red button" (disables all triggers), HeaderView caption gates, cross-trigger pause-lift auto-recovery, recurring presets light-mode visuals.
