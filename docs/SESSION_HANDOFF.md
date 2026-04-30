# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S15** — same-day continuation of S14 (2026-05-01). C-3 deferred items B + C + D + F shipped + 8th simplify-pass. |
| **Theme** | "Polish the Activity history shipped in S14 by working through 4 of the 7 §10 deferred items, in the same TDD-RED → GREEN → simplify-pass cadence as prior sessions." |
| **Status** | ✅ **4 feat commits + 1 simplify-pass commit + 1 doc commit this session.** **442 → 468 tests** (+26). **Smoke unchanged at 22 scenarios** (file-format contract still holds; user-visible UX flows are owner manual smoke step 8). Working tree clean. Test run ~7.0 s. |
| **Tail commit** | (post doc-sync commit forthcoming after this file lands) |

### Commit chain (S15 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S15 (C-3 polish)         (S15 #6)
4343d2a        chore: 8th simplify-pass follow-through (S15)           (S15 #5)
0dfb9d2        feat: click-row → jump to trigger config (D)            (S15 #4)
86bc5b1        feat: CSV/JSON export from Activity tab (C)             (S15 #3)
6a55c02        feat: per-trigger filter for Activity tab (B)           (S15 #2)
0b59e67        feat: customisable activity retention window (F)        (S15 #1)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `0b59e67` | **F — customisable retention window**. `ActivityLogStore.retention` becomes mutable via `setRetention(_:)`; shrink GCs entries that no longer fit + flushes on the spot, grow is a no-op for existing entries. New `SettingsKey.activityRetentionDays` (range 1…90, default 14) + `AppEnvironment.activityRetentionDays` published mirror with `didSet` → `Task { await store.setRetention(...) }`. ActivityTab Stepper in a new "Retention" Section. New static `ActivityLogStore.retentionDayRange` + `currentRetention()` test hook. | +8 |
| 2 | `6a55c02` | **B — per-trigger filter UI**. New `ActivityFilter` enum (`.all` / `.only(triggerId)`) with `apply(to:)` filter, `triggerIdsObserved(in:)` for dynamic picker domain. ActivityTab gains a Picker Section above charts; both 24h bar + heatmap consume the filtered stream. Heatmap title + frame size now follow `environment.activityRetentionDays` (no more hard-coded "Last 14 days"). | +5 |
| 3 | `86bc5b1` | **C — CSV/JSON export**. New pure `ActivityLogExporter` enum: `csv(from:)` returns ISO8601-timestamped string; `jsonData(from:)` returns pretty-printed bytes with the same `secondsSince1970` Double coder as the on-disk log so a re-import round-trips losslessly. ActivityTab gains an "Export" Section (visible only when `entries.isEmpty == false`) with two buttons; NSSavePanel side-effect kept at the host so `ExportButtons` remains a pure SwiftUI primitive. Filename suggestion `latte-activity-YYYY-MM-DD.{csv,json}` (UTC). | +7 |
| 4 | `0dfb9d2` | **D — click-row → trigger config jump**. New `SettingsRoute` value type (tab + optional `focusedTriggerId`) + `SettingsURLHandler.parseRoute(_:)`; legacy `parse(_:)` retained as thin wrapper. ActivityTab "Currently active" rows are `Button`s with chevron affordance + accessibility hint. `SettingsRoot` owns `@State focusedTriggerId`; on click flips `selection = .triggers` and propagates the binding. `TriggersTab` uses `ScrollViewReader` + `.id(trigger.id)` per `TriggerSection` and an `.onChange(of: focusedTriggerId)` to scroll-to + clear (one-shot reset so a second click on the same trigger re-scrolls). LatteApp deep-link path migrated to `parseRoute`; `SettingsWindowController` accepts `focusedTriggerId: String?` and re-emits via `NotificationCenter.default.post(name: .settingsRequestFocusTrigger, object: id)` for the already-open-window path. | +5 |
| 5 | `4343d2a` | **8th simplify-pass on S15 commits 1-4**. APPROVE-WITH-NITS (0 CRIT/HIGH, 2 MED, 5 LOW). All addressed: MED-1 ActivityTab reloads on retention change (`.onChange`) so a grow recovers older history without a tab bounce; MED-2 `reload()` flips `isLoading = true` at entry; LOW-3 DST caveat documented on `splitByHourWithDate`; LOW-4 `parse(_:)` doc clarified as thin wrapper; LOW-5 `86_400` literal collapsed into `ActivityLogStore.secondsPerDay` (4 call sites unified); LOW-7 `TriggerFilterPicker` label helper extracted to `ActivityFilter.label(for:)` — drops `.capitalized`'s locale sensitivity, kebab-case → Title-Case. LOW-1 (HourlyBucket O(n²)) deferred — bounded 24×6=144. | +1 |
| 6 | this commit | **Doc sync**: ROADMAP row 14 (S15) prepended; v2-backlog "Shipped in v1.3.1 (S15)" entry added with all 4 deferred items + still-deferred list; 09-c3-activity-history.md §12 "As shipped — v1.3.1" filled with deferred design decisions resolved during ship; this file rewritten. Memory: NEW `project_latte_v1_3_1.md` for S15 ship summary; `MEMORY.md` index 7 → 8 lines. | 0 |

### Patterns reaffirmed this session

- **Simplify-pass cadence is now 8 passes deep** (S10 / S10.1 / S11 / S11 / S12 / S13 / S14 / S15). All APPROVE or APPROVE-WITH-NITS — never architectural concerns. **Standing ritual after each batch of feature commits**: code-reviewer agent ~3 min + follow-through commit ~10 min.
- **Pure-helper extraction pays off twice**: `ActivityFilter` and `ActivityLogExporter` both stayed pure (no AppKit, no FS), which (a) made TDD-RED cheap (12 tests in 5 minutes) and (b) made the simplify-pass's LOW-7 fix a one-liner (extract label helper to the existing public type). Same pattern as S14's `AwakeSegment.merge`.
- **Legacy-API-as-shim**: `SettingsURLHandler.parse(_:)` survived D as a thin wrapper around `parseRoute(_:)`. Considered `@available(*, deprecated)` and dropped — there are no callsites pending migration; the dual API minimises churn. Same dual-API pattern as `HotKeyRegistrar.register(handler:)` (S12 default-impl shim).
- **Cross-tab plumbing via shared `@State` in SettingsRoot**: `focusedTriggerId` flows from ActivityTab → SettingsRoot @State → TriggersTab Binding. The deep-link path uses a NotificationCenter post for already-open-window re-emit. Avoids EnvironmentObject explosion.
- **Single source of truth for unit conversions**: `ActivityLogStore.secondsPerDay` collapsed 4 sites of raw `86_400`. Pattern to copy whenever a magic literal repeats ≥3×.

---

## Next-session entry points (priority order)

Per S14 handoff structure — same items, with v1.3.1 progress folded in.

1. **Owner UI smoke 8-step** — steps 6 + 7 + step 8 still pending. **Step 8 expanded for v1.3.1**: enable WiFi trigger → toggle Wi-Fi off/on → open Settings → Activity tab → verify entries appear → **also try the new filter Picker (B), Export buttons (C), click a "Currently active" row (D), and the Retention Stepper (F)**. Smoke 22 covers file-format only; this verifies the user-visible polish flows.
2. **Owner-blocked S8d** (~5 min Pages deploy: pick 5-7 PNGs / `deploy_pages.sh <url>` / Settings → Pages 1-click / curl validate). **PNG candidate set may now expand to 7+** — Activity tab Charts is now significantly richer (filter + retention + export buttons all visible).
3. **Owner-blocked S8.5** ($99/yr Apple Dev Program enrollment, 1-2 days approval).
4. **Owner-blocked S9** (App Store Connect metadata; depends on 8.5).
5. **C-7 Quick presets path decision** (08-spec is decision-ready — pick path A/B/C and proceed).
6. **V2-06 deferred refinements**: clamshell-aware lid detection, per-display whitelist (UUID-based), NSScreenSource debounce.
7. **C-3 still-deferred** (per 09-c3 §10): multi-day comparison view, live polling refresh, iCloud sync, user-customisable Charts colours.
8. **B1.2 deferred refinements** (small scope; spec needs re-read first).
9. **V2-22 GitHub remote** — repo push, CI execution, gh-pages branch enable. Owner action.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -13
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 468 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL 후 — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 468/468 tests PASS in ~7 s. Smoke 22/22 PASS in ~5 min.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 14 (S15) for full context if needed.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (8-line index) → drill into `project_latte_v1_3_1.md` for S15 detail; v1.3 (S14) lives in `project_latte_v1_3.md`.
4. **Don't** re-read S1-S11 memory entries — consolidated into `project_latte_v1_0.md` + `project_latte_v1_1.md` + `project_latte_v1_2.md` during S13.

---

## Owner-side pending (unchanged from S14, with PNG count noted)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-7 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. **Activity tab Charts now richer** (filter + retention + export visible). | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program 가입 | Account/payment owner-only | $99/yr + 1-2 days approval |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## C-3 v1.3.1 owner-visible behavior reference (for step 8 smoke)

```
Settings → Activity (4th tab)
  ├─ Show: [All triggers ▾]                     ← NEW (B) per-trigger filter
  ├─ Last 24 hours      [stacked bar, color per trigger]
  ├─ Last <N> days      [heatmap, days × hours]  ← N = retention setting
  ├─ Currently active                            ← rows now clickable buttons (D)
  │  └─ ▸ wifi  "Office-5G"  >                  ← chevron → jumps to Triggers tab
  ├─ Retention                                   ← NEW (F)
  │  └─ Keep history for [14] days  - +
  └─ Export                                      ← NEW (C, hidden when no entries)
     └─ [Export CSV…]  [Export JSON…]            ← NSSavePanel

Deep links:
  latte://settings/activity                      ← unchanged
  latte://settings/triggers?focus=wifi           ← NEW (D)

File: ~/Library/Application Support/Latte/activity-log.json
  ├─ Schema unchanged (privacy contract preserved)
  └─ jq-friendly (or use the new in-app Export → CSV)

Spec: docs/design/09-c3-activity-history.md (§1-§12)
```
