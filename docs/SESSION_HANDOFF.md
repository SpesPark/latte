# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S23** — resumed owner-driven manual smoke continuation (2026-05-03 → 2026-05-04). **Five P-issues** total across A1 (Step 6 region 6, Recurring Quick presets), A3 (Step 7, Settings 4-tab light + dark). Three popover correctness + two Activity-tab UX. Three-commit chain (3 fix + 0 doc-sync; this file lands as the 4th doc-sync). |
| **Theme** | "Owner-driven verification of S22's deferred surfaces uncovered 5 P-issues that unit tests + my own pixel-counting code review never would have caught. P-issue-3 is the standout — DurationPickerRow's stripe `Rectangle().fill(isActive ? accent : Color.clear)` was code-equivalent to RecurringQuickPresetRow's working version, but rendered as 0px in the live popover. Only owner manual smoke + my own screencap diff could falsify it. SwiftUI rendering correctness can't be verified by reading the source." |
| **Status** | ✅ **5 fix commits across 3 batched commits.** **Tests 570 → 581** (+11 net: P-issue-1 +1, P-issue-2 +5, P-issue-3 +0 (UI-only, no unit-testable surface), P-issue-4 +5, P-issue-5 +0 (UI + AppKit panel)). **Smoke 22/22 PASS** post-each-fix. Working tree clean (excluding `.claude/`). |
| **Tail commit** | `3c61efc` (feat: Activity tab — retention Picker + clickable Export buttons — S23 / P-issue-4 + P-issue-5) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S23 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S23                                   (S23 #4)
3c61efc        feat: retention Picker + clickable Export buttons (P-issue-4 + 5)    (S23 #3)
d4a9647        feat: popover active-marker correctness (P-issue-2 + P-issue-3)      (S23 #2)
a82fd86        fix: recurring/quick preset minutes round up (P-issue-1)             (S23 #1)
```

### What landed this session (5 P-issues)

| P# | Resolution path | Tests Δ |
|---|---|---|
| P1 | `a82fd86`. `RecurringQuickPreset.minutes(from:)` `.rounded()` → `.rounded(.up)` so `endsAt = now + minutes*60` is never before the wall-clock target. Same change to `QuickPreset.minutes` for parallelism (dead code post-S19 but tests remain). Cup may stay awake up to ~60s past target; matches "Until X = at least until X" mental model. Caption stops showing "11:59 PM" for "Until 0:00 AM" picks. Regression test `testMinutesRoundsUpWhenSecondsFractional` (Mon 23:00:31 → midnight preset → 60 min). | +1 |
| P2 | `d4a9647`. Picking a recurring preset routed the active checkmark to the Custom row instead of the picked preset (preset-derived `.minutes(N)` is not in `AwakeDuration.presets`, so `isUnlistedCustomDuration` triggered). Fix: new `@Published activeRecurringPresetID: UUID?` on `AwakeManager`; `activate(for:reason:fromRecurringPreset:)` overload (default nil keeps existing API stable); `publishDerived` clears for every non-`.awakeUserTimed` state and on any non-preset activation. `MenuBarRoot` wires preset row's `isActive` to `manager.activeRecurringPresetID == preset.id` and ANDs `activeRecurringPresetID == nil` into Custom row's `isActive`. 5 lifecycle regression tests (set / clear-on-non-preset / clear-on-deactivate / preserve-on-shadow-vote / clear-on-indefinite). | +5 |
| P3 | `d4a9647` (batched with P2). Owner-reported via screencap: stripe `Rectangle().fill(isActive ? accent : Color.clear).frame(width: 3)` HStack-child rendered as 0px on `DurationPickerRow` and `CustomDurationRow` despite identical-looking code in `RecurringQuickPresetRow` which DID render. Suspected SwiftUI layout-identity quirk where dynamic fill on Color.clear-baseline Rectangle inside HStack didn't propagate the accent through the diff. Fix: refactor stripe rendering across **all three popover row types** to use `.overlay(alignment: .leading) { Capsule().fill(accent).frame(width: 3).padding(...) }` — drawn independently of HStack layout. HStack child becomes `Color.clear.frame(width: 3)` for layout reservation only. Capsule (rounded ends) replaces Rectangle for softer finish. Also added `.foregroundStyle(isActive ? .primary : .secondary)` on the duration/custom Text for visual consistency with the preset row. | 0 (UI-only) |
| P4 | `3c61efc`. Retention Stepper UX disorienting — each +/- click triggered a re-fetch that flipped `isLoading = true`, collapsing every chart Section to a spinner row; form re-laid out twice per click. Owner: "그래프로 갑자기 이동해서 정신없고 편의성이 떨어져." Fix: replace `RetentionStepper` (1-day step) with `RetentionPicker` (.menu pulldown, 6 preset windows: 1 day / 1 week / 2 weeks / 1 month / 2 months / 3 months — all within `ActivityLogStore.retentionDayRange = 1...90`). Picker uses `Binding(get: nearestPreset(to:), set: ...)` so pre-S23 stored values (e.g. `22`) display as nearest preset. Plus: `reload(showSpinner: Bool = true)` opt-out — retention-change re-fetch passes `showSpinner: false` so chart sections stay rendered while snapshot swaps atomically. 5 helper tests (exact-match / legacy-value-tiebreak-toward-smaller / range-clamp / presets-within-retention-range / non-empty-labels). | +5 |
| P5 | `3c61efc` (batched with P4). Owner: "export button 동작 안해." Root cause: previous `ExportButtons` wrapper rendered both buttons inside an `HStack` as a single Form Section row — SwiftUI Form Section row tap-handling can swallow Button events when buttons sit inside an HStack child. Fix: inline the two buttons directly into the Section as separate rows (deleted wrapper). `.buttonStyle(.bordered)` so they read as deliberate actions. Added `LatteLog.activity.info` at three points (button tap / panel runModal return / file-write completion) for owner Console-app verification of the sandbox PowerBox path. No `files.user-selected.read-write` entitlement needed — NSSavePanel grants temporary write access on macOS 13+. | 0 (UI + AppKit panel) |

### Patterns reinforced this session

- **Whole-minute precision + minute-boundary targets need round-up not round-to-nearest** (P-issue-1) — `endsAt = now + minutes*60` lands in the previous minute up to half the time when target is on a minute boundary. For wall-clock-target durations (recurring presets), `.rounded(.up)` matches the "Until X = at least until X" mental model and prevents the time-of-day-only formatter from rendering "11:59 PM" for a midnight pick.
- **Marker indirection via dedicated published state** (P-issue-2) — when a derived value (`.minutes(N)`) collides with multiple UI consumers ("is this the Custom row?" vs "is this a preset row?"), don't try to inverse-derive identity from the value. Add a separate published field that captures the activation source. Cleared deterministically in `publishDerived` for non-target states.
- **`activate(...)` API extension via default-nil parameter is backward-compatible** (P-issue-2) — adding `fromRecurringPreset: UUID? = nil` to a `public func activate(for:reason:)` keeps every existing caller working AND makes the marker explicit at the new call site. Default-nil also serves as the "clear marker" semantic for non-preset paths — single `activeRecurringPresetID = presetID` line covers both set and clear.
- **SwiftUI HStack child Rectangle().fill(...) rendering is unreliable across siblings** (P-issue-3) — code-equivalent stripes between three popover row types rendered correctly in one and as 0px in the other two. Suspected SwiftUI layout-identity / diffing quirk on Color.clear baseline. **Use `.overlay(alignment:)` for active-marker stripes** — drawn outside HStack layout, no identity issues.
- **Source-equivalent ≠ render-equivalent in SwiftUI** (P-issue-3) — `diff` showed near-identical code between three row implementations; only owner manual smoke + screencap diff falsified the assumption that they would render the same. Code review of pixel-correctness for SwiftUI is fundamentally limited; visual verification is the only reliable confirmation path.
- **Don't reuse `isLoading` for incremental UI refresh** (P-issue-4) — when a setting change re-fetches data the user is currently viewing, flipping `isLoading = true` hides the existing render and forces a re-layout. Prefer atomic-swap (snapshot in background, replace `entries` when ready). The spinner is for the cold-load path, not the warm-refresh path. Opt-out parameter (`reload(showSpinner: Bool = true)`) keeps both paths cleanly separated.
- **Preset Picker beats Stepper for ranges with no obvious "next" value** (P-issue-4) — Stepper is for fine-grained adjustments where ±1 has clear meaning (volume, font size). For retention windows, the user has no mental model for "what does day 22 vs day 23 mean" — they think in periods (week, month, quarter). Preset Picker forces the design to expose the periods directly, removes spam clicks, gives each click a deliberate weight.
- **Form Section row tap-handling swallows nested HStack Button events** (P-issue-5) — SwiftUI Form on macOS treats Section content as discrete rows; a row containing `HStack { Button A; Button B }` may receive the tap at the row level and not propagate it to the nested buttons. Inline buttons as separate Section rows OR add `.buttonStyle(.bordered)` (which makes the framework treat them as standalone controls). Symptom looks like dead UI — owner thinks "the button doesn't work" not "the row eats my click".
- **Add diagnostic logging at click + side-effect boundaries when fixing dead UI** (P-issue-5) — when a button is unresponsive, log at: (a) the button action callback (verify click registers), (b) the AppKit modal call (verify panel opens), (c) the file write (verify side effect lands). Owner can verify via Console.app which boundary failed without you guessing. Even if the fix lands and works, the logs document the working path for future regression triage.
- **xcodegen drift: new test files don't auto-register** (S23 housekeeping) — `project.yml` uses `Tests/` glob, but adding a new test file requires `xcodegen generate` to refresh `Latte.xcodeproj`. Otherwise xcodebuild shows the file in source but doesn't compile/run it (silent — test count just doesn't increase). **Re-run `xcodegen generate` after every new test file**.

### What was checked but not changed (Step 7 verification)

- General tab (light + dark) — coffee tone presets, cup body/stroke (S22 P-issue-1 + P-issue-2), foam (S20 P2), menu-bar icon style picker, Custom presets list, Launch at Login, Activate at Launch — owner-confirmed OK.
- Triggers tab (light + dark) — 4 trigger rows + ExternalDisplay disclosure, per-trigger sub-forms, noir accent (S22 P-issue-3) — owner-confirmed OK.
- About tab — owner-confirmed OK.

### What was deferred to a later session

- **Step 6 region 7** (B1.2 ⌘⇧L global hotkey) — optional per S22 handoff, owner skipped during S23 region 6 push.
- **Step 8** (Activity tab manual smoke deeper pass) — Step 7-C surfaced the two Activity P-issues. Owner can re-verify Charts + Currently active + per-trigger filter + colour pickers in a focused Step 8 pass next session, on top of the new Picker + working Export buttons.

---

## Next-session entry points (priority order)

1. **Step 8 — Activity tab focused manual smoke** on top of S23 P-issue-4 + P-issue-5 fixes. Verify: retention Picker swaps without form jump; Export CSV / JSON buttons fire (Console.app: `[activity]` logs at tap / panel-return / file-write); per-trigger filter; chart colour pickers; live polling; click-row jump.
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

The v1.x feature backlog stays **functionally exhausted**. S23 is a P-issue-driven UX-polish series — no version bump, still v1.9.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -8
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 581 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 581/581 tests PASS in ~9s. Smoke 22/22 PASS in ~6:14.

**Note**: S16-S23 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 22 (S23) for the most recent session.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (now 14-line index) → drill into `project_latte_v1_9.md` for S23 section (continues S20+S21+S22).
4. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (unchanged from S22)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-9 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program — applied 2026-05-02 | Awaiting Apple review | 1-2 days |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## v1.9 owner-visible behavior reference (post-S23)

- Recurring Quick presets render an active marker (left coffee-accent stripe + right checkmark) on the picked preset row, not on Custom.
- All three popover row types (duration / custom / recurring preset) show consistent left stripe + right checkmark when active.
- "Until X" caption shows the target wall-clock minute (e.g. "12:00 AM" for midnight preset), never one minute before due to whole-minute precision.
- Activity tab Retention is a Picker (1 day / 1 week / 2 weeks / 1 month / 2 months / 3 months), not a Stepper. Switching retention does not collapse the chart sections.
- Activity tab Export CSV / Export JSON buttons fire NSSavePanel and write the chosen file via sandbox PowerBox.

Carryover from earlier sessions (unchanged):

- v1.0~v1.8 owner-visible feature set (5 trigger types, custom presets, activity log, theme customisation, etc.)
- S22 fixes: pause-all snooze caption, Turn off "big red button" (disables all triggers), HeaderView caption gates, cross-trigger pause-lift auto-recovery, recurring presets light-mode visuals.
