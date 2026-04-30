# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S18** — same-day continuation of S17 (2026-05-01, **4th autonomous-cycle session of the day**: S15 → S16 → S17 → S18). C-3 live polling + chart-colour prefs + C-7 recurring presets + 11th simplify-pass. |
| **Theme** | "Close out v1.x deferred backlog. Three deferred items shipped (C-3 live polling + C-3 chart colours + C-7 recurring presets) + standing simplify-pass ritual. Same TDD-RED → GREEN → simplify-pass cadence as the prior 10 passes." |
| **Status** | ✅ **3 feat commits + 1 simplify-pass commit + 1 doc commit this session.** **494 → 538 tests** (+44). **Smoke unchanged at 22** (new flows are owner manual smoke step 6/7 territory). Working tree clean. Test run ~8.5 s. |
| **Tail commit** | (post doc-sync commit forthcoming after this file lands) |

### Commit chain (S18 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S18              (S18 #5)
f56e10e        chore: 11th simplify-pass follow-through (S18)  (S18 #4)
0693f3a        feat: C-7 per-day-of-week recurring presets     (S18 #3)
67b18b3        feat: C-3 user-customisable chart colours       (S18 #2)
54f7d7a        feat: C-3 live polling refresh                  (S18 #1)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `54f7d7a` | **C-3 live polling refresh**. `TriggerCoordinator.recordActivity` posts `Notification.Name.activityLogDidAppend` on every recordActivity site (vote ON / vote OFF / user-explicit `stop(_:)` with active vote). `ActivityTab` listens via `.onReceive` and reloads the snapshot, debounced 300 ms via `liveReloadTask`. Stop with no active vote suppresses (no spurious refresh); nil store suppresses (no phantom data). FIFO actor ordering guarantees the append commits before any subscriber's snapshot returns. Resolves the "Live polling (refresh while tab open)" deferred item in 09-c3 §10. | +5 |
| 2 | `67b18b3` | **C-3 user-customisable Activity chart colours**. New pure `ActivityChartPalette` (triggerOrder + defaultHex + `color(for:overrides:)` + encode/decode for SettingsStore round-trip). Defaults match v1.3 palette so a user who never touches the picker sees no visual change. New `Color(hex:)` and `Color.hexString` SwiftUI extensions for sRGB hex round-trip. New `SettingsKey.activityChartColors` stores `[String: String]` (triggerId → "#RRGGBB"); empty map removes the key. `AppEnvironment.activityChartColors` @Published mirror. ActivityTab gains "Chart colours" Section: 6 ColorPickers + Reset button (only shown when at least one override is set). HourlyAwakeChart now derives chart domain/range from the palette. | +15 |
| 3 | `0693f3a` | **C-7 per-day-of-week recurring presets**. New `RecurringQuickPreset` (Codable, Equatable, Identifiable, Sendable): id / label / targetHour / targetMinute / weekdays:Set<Int>. Pure helpers: `isActiveOn(date:)`, `nextOccurrence(after:)` (today + 7 days ahead, skipping inactive weekdays), `minutes(from:)` (clamped ≥1, mirrors built-in QuickPreset). New `SettingsKey.recurringQuickPresets` + `AppEnvironment.recurringQuickPresets` @Published mirror. MenuBarRoot popover renders user presets after the built-in QuickPresets, filtered by today's weekday. New "Custom presets" Section in General Settings tab: list with tap-to-edit + context-menu delete + "Add preset…" button → sheet (TextField + hour/minute pickers + 7 weekday chips). Pure `RecurringPresetWeekday` helper (Weekdays / Weekends / Every day / Never special-cases). | +23 |
| 4 | `f56e10e` | **11th simplify-pass** on commits 1-3. APPROVE-WITH-NITS (0 CRIT/HIGH, 1 MED, 4 LOW). All 5 actionable findings addressed: LOW-1 stale `HourlyAwakeChart.triggerDomain` doc/test name fixed; LOW-2 ActivityTab live-reload Task switched from `try?+guard` to `do/catch`; LOW-3 dropped dead `userInfo` payload on `.activityLogDidAppend`; LOW-4 `Color(hex:)` whitespace-tolerance latent defect fixed; MED-1 `nextOccurrence` doc tightened. | +1 |
| 5 | this commit | **Doc sync**: ROADMAP row 17 (S18) prepended; v2-backlog "Shipped in v1.7 (S18)" entry added with C-3 still-deferred (iCloud sync) + C-7 still-deferred (Path B/C retired); 09-c3 spec §14 written; 08-c7 spec §10 written; SESSION_HANDOFF rewritten. Memory: NEW `project_latte_v1_7.md`; `MEMORY.md` index 10 → 11 lines. | 0 |

### Patterns reaffirmed this session

- **Simplify-pass cadence is now 11 passes deep** (S10/S10.1/S11/S11/S12/S13/S14/S15/S16/S17/S18). All APPROVE or APPROVE-WITH-NITS. **Standing ritual after each batch of feature commits**: code-reviewer agent ~3 min + follow-through commit ~10 min.
- **Notification + actor FIFO ordering for live UI updates**: when an actor mutation needs to drive a UI refetch, post a `Notification.Name` synchronously from the @MainActor caller *after* dispatching the actor task. By the time a subscriber's reload `await`s a snapshot, FIFO actor ordering guarantees the mutation has committed. No race, no userInfo payload needed for the canonical "just refetch" consumer pattern.
- **`do/catch` over `try?+guard` for cancellation propagation**: `Task.sleep` throwing `CancellationError` is a single mechanism — converting cancellation to a silent return is cleaner than a `try?` that swallows the error followed by a redundant `Task.isCancelled` check.
- **Empty-map-removes-key invariant for SettingsStore**: when storing a `[K: V]` dictionary, return nil from `encode` for an empty dictionary so the caller can clear the key. Preserves "absent = never customised" — a future migration that needs to distinguish "user explicitly cleared" from "never touched" can't be retro-fitted if we wrote `{}` data.
- **Pure helpers anchor chart consistency**: `ActivityChartPalette.triggerOrder` is the single source of truth for the 6-trigger render order — `HourlyAwakeChart` reads it directly, so legend/swatch drift between palette and chart is impossible. Better than parallel statics that need cross-reference comments.
- **8-candidate weekday lookahead**: for a "next occurrence on a configured weekday" helper, iterate `0...7` (today + 7 days). The worst case is "today is the right weekday but target time just passed" — needs offset 7 (a full week forward). Off-by-one trap: doc comment says "up to 7 days" but the loop checks 8 candidates.
- **UTC-anchored DateComponents in tests** (reaffirmed from S17): all `RecurringQuickPreset` fixtures build dates via `Calendar(identifier: .gregorian)` with `TimeZone(secondsFromGMT: 0)` so weekday assertions are deterministic across CI hosts.
- **Special-case the common patterns**: `RecurringPresetWeekday.summary(for:)` collapses {2,3,4,5,6} → "Weekdays" and {1,7} → "Weekends" before falling through to the comma-separated path. Owner-visible string stays readable for the 80% case at zero ergonomic cost.

---

## Next-session entry points (priority order)

1. **Owner UI smoke 8-step** — steps 6 + 7 + 8 still pending. **Step 6 expanded for v1.7**: also verify Custom presets section in General Settings (add a "Until 6 PM, Mon-Fri" preset + verify it appears in the popover only on weekdays). **Step 7 expanded for v1.7**: Activity tab — verify Chart colours section ColorPickers; change wifi colour, observe HourlyAwakeChart redraw; click Reset and verify defaults restore. **Step 7 live-polling**: with Activity tab open, toggle a trigger off/on and verify the snapshot updates within ~1 s.
2. **Owner-blocked S8d** (~5 min Pages deploy: pick 5-9 PNGs / `deploy_pages.sh <url>` / Settings → Pages 1-click / curl validate). PNG candidate set is now the **richest yet** — popover has up to 4 sections (presets / custom / quick presets / recurring presets), Activity tab has 3 charts + chart-colour pickers, General tab has custom-presets editor, Triggers tab has whitelist UI, About tab shows clamshell-tagged reasons.
3. **Owner-blocked S8.5** ($99/yr Apple Dev Program enrollment, 1-2 days approval).
4. **Owner-blocked S9** (App Store Connect metadata; depends on 8.5).
5. **C-3 still-deferred** (joint design with B1.2): iCloud sync of activity history + iCloud chord sync — schema integration risk if shipped solo.
6. **V2-06 still-deferred** (no further v1.x scope): lid-closed-only mode, per-display position requirement.
7. **B1.2 still-deferred** (per 07-spec §1): per-action chords, iCloud sync of chord (joint with C-3 iCloud), false-negative chord-reserved indicator.
8. **C-7 still-deferred**: Path B (`.until(Date)` enum) + Path C (`@Published activeQuickPreset` aside) — both **retired** per 08-spec §10. No further v1.x C-7 scope.
9. **V2-22 GitHub remote** — repo push, CI execution, gh-pages branch enable. Owner action.

The v1.x feature backlog is **functionally exhausted** — all autonomous-cycle deferred items have shipped. The only remaining v1.x deferrals are joint-design (iCloud sync for both C-3 + B1.2) or owner-decision (B1.2 per-action chords). Next code work needs owner direction (new feature ask, joint iCloud design pass, or owner-blocked S8d/S8.5 unblocking).

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -16
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 538 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 538/538 tests PASS in ~8.5 s. Smoke 22/22 PASS in ~5 min.

**Note**: S16-S18 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 17 (S18) for full context if needed.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (11-line index) → drill into `project_latte_v1_7.md` for S18 detail; v1.6 (S17) lives in `project_latte_v1_6.md`; older entries in `project_latte_v1_5.md` / `project_latte_v1_3_1.md` / `project_latte_v1_3.md`.
4. **Don't** re-read S1-S11 memory entries — consolidated into `project_latte_v1_0.md` + `project_latte_v1_1.md` + `project_latte_v1_2.md` during S13.

---

## Owner-side pending (richest PNG set yet)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-9 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. **Popover** can show 4 sections (7 duration presets + Custom + 3 quick presets + N recurring presets, weekday-filtered). **Activity tab** has 3 charts + chart-colour pickers. **General tab** has Custom-presets editor. **Triggers tab** has whitelist UI. **About → Status** shows `(clamshell)` tag. | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program 가입 | Account/payment owner-only | $99/yr + 1-2 days approval |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## v1.7 owner-visible behavior reference (for step 6/7 smoke)

### Popover render with recurring presets

```
Click menu bar icon → Popover appears
  ├─ [header: state / mode / power]
  ├─ ── divider ──
  ├─ Pause triggers toggle
  ├─ ── divider ──
  ├─ Section 1 — Duration presets (7 + Custom)
  ├─ ── divider ──
  ├─ Section 2 — Quick presets (3, C-7 Path A v1.6)
  │  └─ Section 2a — Recurring presets (N, weekday-filtered, NEW v1.7)
  │       ├─ "Until 6 PM"          (only visible Mon-Fri if so configured)
  │       └─ "Until 8 PM Tue/Thu"  (only visible Tue + Thu)
  ├─ ── divider ──
  ├─ Turn off button
  └─ Settings… / Quit footer
```

### Custom-presets editor (General Settings tab)

```
Settings → General → "Custom presets" section:
  ┌────────────────────────────────────────┐
  │ Until 6 PM                          ›  │   ← tap to edit
  │ 18:00 · Weekdays                       │
  ├────────────────────────────────────────┤
  │ Until 8 PM Tue/Thu                  ›  │
  │ 20:00 · Tue, Thu                       │
  └────────────────────────────────────────┘
  [ Add preset… ]

Add/edit sheet:
  Label  [ TextField                          ]
  Time   [ HH ] : [ MM (5-min stride) ]
  Days   [Sun][Mon][Tue][Wed][Thu][Fri][Sat]   ← chips, tap to toggle
                              [Cancel] [Add]   ← disabled if label empty or 0 days
```

### Activity tab — Chart colours section

```
Settings → Activity → "Chart colours" section:
  wifi              [color picker]
  calendar          [color picker]
  focus             [color picker]
  app               [color picker]
  schedule          [color picker]
  external display  [color picker]
                    [ Reset to defaults ]   ← only shown when ≥1 override is set
```

### Live polling refresh (with Activity tab open)

```
Trigger fires (vote ON or OFF, or user toggles trigger off in Triggers tab)
  → TriggerCoordinator posts .activityLogDidAppend
  → ActivityTab.scheduleLiveReload() debounces 300 ms
  → reload() refetches snapshot from ActivityLogStore actor
  → Charts redraw + Currently active list updates
```
