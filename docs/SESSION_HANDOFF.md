# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S25** — S24-deferred P-issue-4 close-out (cold-start Activity-tab placeholder flicker) (2026-05-05). One fix commit + this docs commit. |
| **Theme** | "S24 deferred P-issue-4 was a single-symptom item but the fix path was non-trivial: an in-View `hasFirstSnapshot` two-flag gate (S25's first attempt) didn't actually eliminate the flicker because the actor's lazy first-load (disk read + JSON decode) is the real load-blocker, not just the actor hop. The fix that worked was the structural one — hoist `activityEntries` to AppEnvironment as `@Published Optional[T]` with three-state semantics (`nil` = loading, `[]` = loaded empty, non-empty = loaded) and pre-load it on the boot path parallel to `bootTriggers()`. ActivityTab becomes a dumb view reading from environment; the @State / @State / @State explosion of S24 collapses to a single Optional read." |
| **Status** | ✅ **1 fix commit** (`e79bed6`) + this docs commit. **Tests 574 → 574** (unchanged — pure refactor / state-source migration). Smoke unchanged at 22 (lazy-load contract preserved — `snapshot()` still doesn't create the file). Working tree clean (excluding `.claude/`). |
| **Tail commit** | `e79bed6` (feat: Activity tab — pre-load entries at boot to eliminate cold-start placeholder flicker — S25 / P-issue-4) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S25 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF + ROADMAP wrap for S25                          (S25 #2)
e79bed6        feat: Activity tab — pre-load entries at boot to eliminate cold-       (S25 #1)
               start placeholder flicker (P-issue-4)
```

### What landed this session (1 P-issue, multi-attempt)

| P# | Resolution path | Tests Δ |
|---|---|---|
| P-issue-4 | Cold-start placeholder flicker on first-ever Activity tab entry per app launch. **First attempt (in-session, abandoned before commit)**: in-View two-flag gate — `hasLoaded` (re-fire gate, set synchronously before await per S24's P-issue-3 protection) + new `hasFirstSnapshot` (placeholder gate, set only after `await reload()` resolves). Theory: avoid SwiftUI rendering the (`hasLoaded=true`, `entries=[]`) intermediate state between Task suspension and snapshot resumption. **Owner manual smoke confirmed flicker still present**. Diagnostic re-walk: actor's lazy first-load (`Data(contentsOf:url)` + `JSONDecoder.decode`) runs synchronously inside the actor hop on first call; SwiftUI commits at least one frame before the actor resumption can populate `entries`, regardless of how the in-View flags are sequenced. **Second attempt (shipped)**: hoist `activityEntries: [ActivityLogEntry]?` to `AppEnvironment` as `@Published`. Three-state semantics: `nil` = boot snapshot still resolving (only possible if user opens Settings within first tens of ms of launch — exceedingly rare), `[]` = loaded but no entries, non-empty = loaded with data. New `loadActivityEntriesEagerly()` (idempotent, guards on nil) called from `LatteAppDelegate.applicationDidFinishLaunching` in a parallel Task to `bootTriggers()`. New `refreshActivityEntries()` (always-fresh fetch) wired to retention `.onChange` and `.activityLogDidAppend` notification. ActivityTab refactored to a dumb view: removed `@State entries / hasLoaded / hasFirstSnapshot`, removed local `reload()`, body uses `if let entries = environment.activityEntries` 3-state branch. `liveReloadTask` debouncer retained but now calls `environment.refreshActivityEntries()`. API cleanup: dropped `store: ActivityLogStore?` parameter from ActivityTab init; SettingsRoot and SettingsWindowController follow transitively. **12th simplify-pass within S25**: `loadActivityEntriesEagerly` collapsed to `guard nil ... await refreshActivityEntries()` (eliminating duplicated cutoff math); ActivityTab body's branch tightened from explicit nil-check + Optional unwrap to `if let ... else if .isEmpty ... else ...`. Lazy-load contract preserved: `snapshot()` reads file but never creates it (smoke 22 PASSES). Owner-confirmed flicker eliminated post-fix. | 0 (refactor only) |

### Patterns reinforced this session

- **Actor lazy-init blocks first-frame rendering** (P-issue-4) — when an actor hop also triggers expensive synchronous work (disk read + JSON decode) on its first call, in-View async-gating flags can't hide the latency from SwiftUI; the only fix is to pre-load the actor's first call off the rendering path (eager init at app boot). The S25 first attempt's two-flag gate (`hasLoaded` + `hasFirstSnapshot`) failed because the gate was structurally inside the load latency, not before it.
- **Single-source-of-truth on `@Published Optional[T]` with three-state semantics** (P-issue-4) — `nil = loading`, `[] = loaded empty`, non-empty = loaded with data — collapses three concerns (in-flight, empty result, data ready) into one Optional read with `if let ... else if .isEmpty ... else ...`. Cleaner than separate `hasLoaded` + `entries` flags because state transitions are atomic at the @Published assignment.
- **Hoist async-loaded view state to a parent ObservableObject when load timing matters** (P-issue-4) — when a child view's `@State` is sourced from an async fetch and the fetch's first call has perceptible latency (actor lazy-init, network call, etc.), hoist to a parent that can pre-load before the child mounts. Child becomes a dumb view; the @State → @Published migration also frees the data for cross-view reuse (e.g. future menu-bar activity-summary surface).

### What was checked but not changed

- Activity tab: filter chips / 24h chart / 14d heatmap / DailyTotals chart / Currently active list / retention Picker / chart colour pickers / live polling (notification debouncer) / click-row jump — all still working post-refactor, owner-confirmed.
- Smoke 22 "activity-log: file absent on fresh launch" — eager pre-load reads file but doesn't create it, so the lazy-load contract is preserved. Verified PASSING twice during S25.
- General / Triggers / About tabs — unchanged from S24 ship state.

### What was deferred to a later session

- **Step 6 region 7** (B1.2 ⌘⇧L global hotkey, optional) carried over from S22 / S23 / S24 handoffs.
- **S22 P-issue-4 revisit** (low-priority): NSEvent.addLocalMonitor on popover-show to wire ⌘, / ⌘Q via direct key event handling rather than SwiftUI `.keyboardShortcut(...)`. Carry over.

The v1.x feature backlog is now **fully exhausted** — Activity-tab P-issues 1+2+3 (S24) and P-issue-4 (S25) all closed. No outstanding owner-side reports.

---

## Next-session entry points (priority order)

1. **Owner-blocked S8d** (~5 min Pages deploy) — first owner-blocking item now that v1.x P-issue queue is empty.
2. **Owner-blocked S8.5** (Apple Dev Program — applied 2026-05-02).
3. **Owner-blocked S9** (App Store Connect; depends on S8.5).
4. **Step 6 region 7** (B1.2 ⌘⇧L global hotkey, optional) if owner wants to close out Step 6 entirely.
5. **C-3 still-deferred** (joint design with B1.2): iCloud sync of activity history + iCloud chord sync.
6. **V2-06 still-deferred**: lid-closed-only mode, per-display position requirement.
7. **B1.2 still-deferred** (per 07-spec §1): per-action chords, iCloud sync of chord, false-negative chord-reserved indicator.
8. **C-7 still-deferred**: Path B + Path C — both retired.
9. **V2-22 GitHub remote**.
10. **S22 P-issue-4 revisit** (low-priority): NSEvent.addLocalMonitor on popover-show to wire ⌘, / ⌘Q via direct key event handling rather than SwiftUI `.keyboardShortcut(...)`. Defer until owner explicitly requests, or a future macOS changes popover focus handling.

S25 is a P-issue-driven UX-polish session — no version bump, still v1.9.

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

**Diagnostic stream (carry over from S24)**: `/usr/bin/log stream --predicate 'subsystem == "com.parkbyeongjun.latte" AND category == "activity"' --info --debug --style compact` (`--info --debug` flags are mandatory or info-level logs are silently filtered).

**Note**: S16-S25 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 24 (S25) for the most recent session, row 23 (S24) for the immediately prior session.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (now 14-line index) → drill into `project_latte_v1_9.md` for the S24 section + the S25 update.
4. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (unchanged from S22 / S23 / S24)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-9 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program — applied 2026-05-02 | Awaiting Apple review | 1-2 days |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## v1.9 owner-visible behavior reference (post-S25)

- Activity tab no longer flashes the empty-state placeholder ("Trigger fires will appear here") on the first-ever entry per app launch (S25 P-issue-4 — pre-loaded at boot via `AppEnvironment.activityEntries`).
- Activity tab no longer offers Export CSV / Export JSON (feature removed S24 — non-functional across multiple fix attempts).
- Activity tab no longer flashes a spinner-only frame on first entry (S24 P-issue-2).
- Activity tab no longer flashes the previous scroll position on every tab re-entry (S24 P-issue-3 — first-load gate).
- Recurring Quick presets render an active marker (left coffee-accent stripe + right checkmark) on the picked preset row, not on Custom (S23 P-issue-2 + P-issue-3).
- All three popover row types (duration / custom / recurring preset) show consistent left stripe + right checkmark when active (S23 P-issue-3 universal stripe).
- "Until X" caption shows the target wall-clock minute (e.g. "12:00 AM" for midnight preset), never one minute before due to whole-minute precision (S23 P-issue-1).
- Activity tab Retention is a Picker (1 day / 1 week / 2 weeks / 1 month / 2 months / 3 months), not a Stepper. Switching retention does not collapse the chart sections (S23 P-issue-4).

Carryover from earlier sessions (unchanged):

- v1.0~v1.8 owner-visible feature set (5 trigger types, custom presets, activity log, theme customisation, etc.)
- S22 fixes: pause-all snooze caption, Turn off "big red button" (disables all triggers), HeaderView caption gates, cross-trigger pause-lift auto-recovery, recurring presets light-mode visuals.
