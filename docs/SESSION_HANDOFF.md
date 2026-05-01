# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S19** — first owner-driven manual smoke session after the v1.x autonomous backlog drain (2026-05-02). Three P-issues surfaced and shipped: Wi-Fi caption non-breaking-hyphen fix; C-7 built-in seed-then-mutable redesign; Delete button in preset edit sheet. Two simplify-passes (12th + 13th). |
| **Theme** | "Owner-driven manual smoke turns into a UX polish ship cycle. Fix-first per P1 with same TDD-RED → GREEN → simplify-pass cadence as the prior 11 passes." |
| **Status** | ✅ **3 feat commits + 2 simplify-pass commits + 1 fix commit this session.** **538 → 548 tests** (+10). **Smoke unchanged at 22** (UX redesigns covered by owner manual smoke step 6). Working tree clean. Test run ~8.4s. |
| **Tail commit** | `992a161` (chore: 13th simplify-pass follow-through) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S19 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S19              (S19 #7)
992a161        chore: 13th simplify-pass follow-through        (S19 #6)
c7d734c        feat: Delete button in preset edit sheet         (S19 #5)
c4c9894        chore: 12th simplify-pass follow-through         (S19 #4)
efb134e        feat: drop hard-coded built-in popover ForEach   (S19 #3)
7c97c60        feat: builtinSeeds + migration (TDD RED→GREEN)   (S19 #2)
11789c3        fix: non-breaking hyphen in Pause caption (P1)   (S19 #1)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `11789c3` | **Wi-Fi caption non-breaking hyphen fix**. `Pause triggers` caption "Ignore Calendar / App / Wi-Fi / Schedule votes." was wrapping mid-word at the hyphen on the popover width ("wi-/fi"). SwiftUI treats `-` as a soft break point. Replaced with `\u{2011}` (U+2011 NON-BREAKING HYPHEN); wrap now falls only on whitespace boundaries. | 0 |
| 2 | `7c97c60` | **C-7 built-in seed-then-mutable migration (RED→GREEN)**. New `RecurringQuickPreset.builtinSeeds()` returns the three legacy `QuickPreset` rows (until 5 PM / 11 PM / midnight) as `RecurringQuickPreset` values with stable hard-coded UUIDs (replay-safe writes), every-day weekdays (`{1...7}`), matching target hours 17/23/0. Midnight uses hour 0 — `nextOccurrence` lookahead naturally rolls forward. New `seedBuiltinPresetsIfNeeded(in:)` migration handles three launch-time cases via the new `SettingsKey.didSeedBuiltinPresets` sentinel: fresh install / v1.7 upgrader / returning user. | +9 |
| 3 | `efb134e` | **Popover wiring — drop hard-coded ForEach**. `MenuBarRoot.swift` drops `ForEach(QuickPreset.allCases)` and the separate built-in `VStack`. The recurring section now wraps in `if !activePresets.isEmpty` — owner-cleared state shows a clean popover (no empty divider, no zero-row VStack). `AppEnvironment.init` runs `seedBuiltinPresetsIfNeeded` BEFORE the recurring list read. `QuickPreset` + `QuickPresetRow` deprecated via doc-comment, retained for API stability + existing nextOccurrence/minutes regression tests. | 0 |
| 4 | `c4c9894` | **12th simplify-pass follow-through**. APPROVE — 0 CRIT/HIGH/1 MED/2 LOW. MED-1 doc reworded "Two pre-sentinel cases" → "Three launch-time cases" matching §11 table; LOW-1 alignment whitespace on builtinSeed*ID constants normalised; LOW-2 `…ResEED…` test method casing typo renamed. Bonus regression test pinned the third launch-time case (sentinel-true + non-empty → no-op). | +1 |
| 5 | `c7d734c` | **Delete button in preset edit sheet**. Owner-reported: right-click Delete on the General list is too easy to miss. Added bottom-leading destructive Delete button to `RecurringQuickPresetSheet`; only renders in edit mode (`onDelete != nil`). Confirmation dialog ("Delete <label>? This preset will be removed from the popover.") protects against accidental click on the already-`.destructive` button. Right-click Delete preserved unchanged. | 0 |
| 6 | `992a161` | **13th simplify-pass follow-through**. APPROVE-WITH-NITS — 0 CRIT/HIGH/1 MED/2 LOW. MED-1 raw user label interpolated into confirm dialog title — added `confirmTitleLabelCap = 40` + `displayLabelForConfirm` computed var (trims whitespace, falls back to "this preset" for empty, ellipsis-truncates >40 chars). LOW-1 explicit init kept (memberwise-redundant nit deferred); LOW-2 `if onDelete != nil` style accepted. | 0 |
| 7 | this commit | **Doc sync**: ROADMAP row 18 (S19) prepended; v2-backlog "Shipped in v1.8 (S19)" entry added with patterns block; 08-c7 spec §11 (built-in seed-then-mutable redesign) written; SESSION_HANDOFF rewritten. Memory: NEW `project_latte_v1_8.md`; `MEMORY.md` index 11 → 12 lines. | 0 |

### Patterns established this session

- **U+2011 non-breaking hyphen for SwiftUI wrap-control**. When a tight caption contains a word-internal hyphen ("Wi-Fi") that SwiftUI's autowrap might break, replace `-` with `\u{2011}` (NON-BREAKING HYPHEN). Wrap then falls only on whitespace boundaries. Cheap, no test (UI-only).
- **Stable hard-coded UUIDs for replay-safe seed migrations**. When a migration writes a fixed list, hard-code each item's UUID so two `builtinSeeds()` calls return equal arrays. Avoids the trap where `UUID()` per call would make the migration write a different list on every (theoretical) re-run. Idempotent migration is the goal; stable UUIDs guarantee it.
- **Sentinel-gated migration with three launch-time cases**. A single Bool sentinel (`didSeedBuiltinPresets`) is the **only** state that distinguishes "never migrated" from "user emptied list". Without it, `if list.isEmpty: seed` would resurrect deletions. Migration logic must enumerate three cases: fresh install (sentinel false + empty → seed), upgrader (sentinel false + non-empty → preserve, set sentinel only), returning user (sentinel true → guard returns).
- **Bottom-leading destructive sheet button + confirmationDialog**. macOS pattern for unrecoverable user-data actions in sheets: destructive button on the bottom-leading edge, visually separated from the right-side Cancel/Save axis. `confirmationDialog` adds an extra safety beat — even though `Button(role: .destructive)` already declares intent, owner-data deletion warrants the extra click.
- **Cap user-supplied strings before owner-facing dialog interpolation**. A confirm dialog title that interpolates `\(initial?.label ?? "...")` will crash visually (off-screen, clip, wrap awkwardly) if the user typed a 200-char label. 40-char cap + ellipsis + whitespace-trim + fallback-for-empty handles all corruption modes.
- **Standing simplify-pass ritual is now 13 passes deep** (S10 / S10.1 / S11×2 / S12 / S13 / S14 / S15 / S16 / S17 / S18 / S19×2). All APPROVE or APPROVE-WITH-NITS. Code-reviewer agent ~3 min + follow-through commit ~10 min. The `displayLabelForConfirm` computed var in S19 #6 is a textbook example: a one-line `MED` finding from the agent prevented a real owner-facing UX defect under unusual input.

---

## Next-session entry points (priority order)

1. **Continue owner UI smoke 8-step** — Step 7 (Activity tab Chart colours + live polling) and Step 8 (any remaining surface) still pending. v1.7's three Chart-colour pickers + Reset button + 300ms-debounced live polling are unverified by manual smoke; v1.8's seed-then-mutable migration adds the full editable list to Step 6 verification.
2. **Owner-blocked S8d** (~5 min Pages deploy: pick 5-9 PNGs / `deploy_pages.sh <url>` / Settings → Pages 1-click / curl validate). PNG candidate set is even richer post-S19 — popover can show 0..N recurring rows depending on owner customisation, sheet has Delete button, Pause caption now wraps cleanly.
3. **Owner-blocked S8.5** ($99/yr Apple Dev Program enrollment, 1-2 days approval).
4. **Owner-blocked S9** (App Store Connect metadata; depends on 8.5).
5. **C-3 still-deferred** (joint design with B1.2): iCloud sync of activity history + iCloud chord sync — schema integration risk if shipped solo.
6. **V2-06 still-deferred** (no further v1.x scope): lid-closed-only mode, per-display position requirement.
7. **B1.2 still-deferred** (per 07-spec §1): per-action chords, iCloud sync of chord (joint with C-3 iCloud), false-negative chord-reserved indicator.
8. **C-7 still-deferred**: Path B (`.until(Date)` enum) + Path C (`@Published activeQuickPreset` aside) — both **retired** per 08-spec §10. The seed-then-mutable redesign in §11 is now the canonical C-7 model.
9. **V2-22 GitHub remote** — repo push, CI execution, gh-pages branch enable. Owner action.

The v1.x feature backlog stays **functionally exhausted** post-S19. What changed: this session's work was owner-reported during manual smoke rather than autonomous-cycle deferred. Future owner-driven sessions will continue this pattern — surface UX issues during use, fix-first, ship.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -16
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 548 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 548/548 tests PASS in ~8.4s. Smoke 22/22 PASS in ~5 min.

**Note**: S16-S19 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 18 (S19) for full context if needed.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (12-line index) → drill into `project_latte_v1_8.md` for S19 detail; v1.7 (S18) lives in `project_latte_v1_7.md`; older entries in `project_latte_v1_6.md` / `project_latte_v1_5.md` / `project_latte_v1_3_1.md` / `project_latte_v1_3.md`.
4. **Don't** re-read S1-S11 memory entries — consolidated into `project_latte_v1_0.md` + `project_latte_v1_1.md` + `project_latte_v1_2.md` during S13.

---

## Owner-side pending (richest PNG set yet)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-9 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. **Popover** can show duration presets + 0..N recurring rows (3 seeded by default, all editable / deletable post-S19). **Activity tab** has 3 charts + chart-colour pickers. **General tab** has Custom-presets editor with Delete button in the edit sheet (S19). **Triggers tab** has whitelist UI. **About → Status** shows `(clamshell)` tag. **Pause caption** wraps cleanly post-S19 fix. | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program 가입 | Account/payment owner-only | $99/yr + 1-2 days approval |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## v1.8 owner-visible behavior reference (for step 6 smoke)

### Popover render after S19 redesign

```
Click menu bar icon → Popover appears
  ├─ [header: state / mode / power]
  ├─ ── divider ──
  ├─ Pause triggers toggle
  │   └─ caption: "Ignore Calendar / App / Wi‑Fi / Schedule votes."   ← non-breaking hyphen
  ├─ ── divider ──
  ├─ Section 1 — Duration presets (5/15/30/1h/2h/5h/Indefinitely + Custom)
  ├─ ── divider ──   (only if ≥1 active preset)
  ├─ Section 2 — Recurring presets (0..N, weekday-filtered)
  │   ├─ "Until 5 PM"                  (seeded, every day)
  │   ├─ "Until 11 PM"                 (seeded, every day)
  │   ├─ "Until midnight"              (seeded, every day)
  │   └─ ...user-defined presets...    (only on configured weekdays)
  ├─ ── divider ──
  ├─ Turn off button
  └─ Settings… / Quit footer
```

### Custom-presets editor (General Settings tab) post-S19

```
Settings → General → "Custom presets" section:
  ┌────────────────────────────────────────┐
  │ Until 5 PM                          ›  │   ← seeded, tap to edit
  │ 17:00 · Every day                      │
  ├────────────────────────────────────────┤
  │ Until 11 PM                         ›  │
  │ 23:00 · Every day                      │
  ├────────────────────────────────────────┤
  │ Until midnight                      ›  │
  │ 00:00 · Every day                      │
  └────────────────────────────────────────┘
  [ Add preset… ]

  ↑ Right-click any row → context menu: Edit… / Delete (existing)

Add/edit sheet (S19 — Delete button added):
  ┌────────────────────────────────────────┐
  │ Edit preset                            │
  ├────────────────────────────────────────┤
  │ Label  [ Until 5 PM                  ] │
  │ Time   [ 17 ] : [ 00 ]                 │
  │ Days   [Sun][Mon][Tue][Wed][Thu][Fri][Sat]
  ├────────────────────────────────────────┤
  │ [Delete]                [Cancel] [Save] │   ← Delete is bottom-leading, red
  └────────────────────────────────────────┘

Delete button → confirmation dialog:
  "Delete Until 5 PM?"
  "This preset will be removed from the popover."
  [Delete (red)]    [Cancel]
```

### First-launch migration (seed-then-mutable)

```
First app launch ever:
  AppEnvironment.init →
    settings.didSeedBuiltinPresets is false
    settings.recurringQuickPresets is empty
  ⟹ write 3 seeds + flip sentinel to true
  ⟹ popover shows 3 seeded rows + duration presets

User deletes all 3 (right-click Delete or Sheet Delete button) →
  recurringQuickPresets = []
  sentinel stays true
  ⟹ popover shows duration presets only, no divider

App quits + relaunches →
  AppEnvironment.init reads sentinel=true → guard returns
  recurringQuickPresets stays []
  ⟹ owner-cleared state survives restart
```
