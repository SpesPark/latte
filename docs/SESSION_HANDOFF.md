# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S21** — autonomous post-S20 polish (2026-05-02). Single-commit refactor: 15th simplify-pass extracts the duplicated `appearance.bestMatch(...) == .darkAqua` predicate from three sites into a shared `NSAppearance.isDarkAqua` extension. Smoke 22/22 + 554/554 tests verified post-refactor. |
| **Theme** | "Continue the standing simplify-pass ritual when no owner-driven defects are queued. The 15th pass MED finding from S20 is the lone meaningful improvement after 14 prior passes — codebase is otherwise tight." |
| **Status** | ✅ **1 refactor commit + smoke validation this session.** **Tests unchanged at 554** (no behavior change, no new tests). **Smoke 22/22 PASS** in ~6:30. Working tree clean. |
| **Tail commit** | `254978f` (chore: 15th simplify-pass — extract NSAppearance.isDarkAqua) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S21 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S21                          (S21 #2)
254978f        chore: 15th simplify-pass — extract NSAppearance.isDarkAqua (S21 #1)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `254978f` | **15th simplify-pass — extract `NSAppearance.isDarkAqua`**. MED finding from a fresh code-reviewer pass over the post-S20 surface area: the `appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua` predicate appeared verbatim in three places — `Theme.foam` (line 31), `Theme.cup` (line 44), and `CoffeeAccent.color` (line 93). Three-copy DRY violation. Added a small `extension NSAppearance { var isDarkAqua: Bool { bestMatch(...) == .darkAqua } }` at the top of `Theme.swift`; all three providers now read `appearance.isDarkAqua` directly. Future appearance-name changes are now a one-line edit. Pure refactor — no behavior change. 554/554 tests still PASS in 8.47s. | 0 |
| 2 | this commit | **Doc sync**: ROADMAP row 20 (S21) prepended; SESSION_HANDOFF rewritten for S21; `project_latte_v1_9.md` memory appended with S21 follow-up section; `MEMORY.md` index entry refreshed. | 0 |

### Patterns reinforced this session

- **Standing simplify-pass ritual is now 15 passes deep** (S10 / S10.1 / S11×2 / S12 / S13 / S14 / S15 / S16 / S17 / S18 / S19×2 / S20 / S21). All APPROVE or APPROVE-WITH-NITS. The S21 pass distilled three identical 1-line predicates into one extension property — exactly the kind of low-noise DRY win that owner-driven feature work tends to leave on the table because the cognitive cost-per-finding rises after each pass.
- **`NSAppearance.isDarkAqua` extension as the canonical isDark probe** — the project now has a single named place to change if the appearance-name set ever needs to grow (e.g. `accessibility*` variants, `darkAqua` only). Use it in new dynamic-NSColor providers from S22 onward.

### What was checked but not changed

- **Dead-code grep**: `QuickPreset` enum + `QuickPresetRow` view are both deprecated by S19 #2 doc-comments but intentionally retained — `QuickPreset` for the `QuickPresetTests` regression coverage of `nextOccurrence` / `minutes` math, `QuickPresetRow` for "API stability until v2.0" per its own doc-comment. Owner-documented decisions; no removal.
- **Test fixture duplication**: 4 test files each carry their own `Calendar(identifier: .gregorian) + TimeZone(identifier: "UTC")` fixture. Extraction marginal — leaving alone.
- **Doc staleness**: ROADMAP row 19 + v2-backlog v1.9 entry + MEMORY.md index all reflect S20 ship state correctly. No drift.

---

## Next-session entry points (priority order)

1. **Continue owner UI smoke 8-step** — Step 6 (popover light + dark) and Step 7 (Settings 4-tab light + dark) need verification post-S20 P1+P2 fixes. Step 8 (Activity tab Charts + colour pickers + live polling) still has zero manual smoke since v1.7 ship.
2. **Owner-blocked S8d** (~5 min Pages deploy: pick 5-9 PNGs / `deploy_pages.sh <url>` / Settings → Pages 1-click / curl validate). Richest PNG set yet — light-mode cappuccino cup with visible steam, 460×420 Settings 4-tab fit, popover/sheet/Pause-caption polish.
3. **Owner-blocked S8.5** ($99/yr Apple Dev Program — **applied 2026-05-02 per owner**, awaiting 1-2 day approval).
4. **Owner-blocked S9** (App Store Connect metadata; depends on 8.5).
5. **C-3 still-deferred** (joint design with B1.2): iCloud sync of activity history + iCloud chord sync — schema integration risk if shipped solo.
6. **V2-06 still-deferred** (no further v1.x scope): lid-closed-only mode, per-display position requirement.
7. **B1.2 still-deferred** (per 07-spec §1): per-action chords, iCloud sync of chord (joint with C-3 iCloud), false-negative chord-reserved indicator.
8. **C-7 still-deferred**: Path B (`.until(Date)` enum) + Path C (`@Published activeQuickPreset` aside) — both **retired** per 08-spec §10. The seed-then-mutable redesign in §11 is now the canonical C-7 model.
9. **V2-22 GitHub remote** — repo push, CI execution, gh-pages branch enable. Owner action.

The v1.x feature backlog stays **functionally exhausted** post-S20. S21 added pure-polish on top — no version bump, still v1.9.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -16
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 554 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 554/554 tests PASS in ~8.5s. Smoke 22/22 PASS in ~6:30.

**Note**: S16-S21 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 20 (S21) for the most recent session; row 19 (S20) for v1.9 ship context.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (13-line index) → drill into `project_latte_v1_9.md` (now contains both S20 ship + S21 follow-up section); v1.8 (S19) lives in `project_latte_v1_8.md`; older entries in `project_latte_v1_7.md` / `project_latte_v1_6.md` / `project_latte_v1_5.md` / `project_latte_v1_3_1.md` / `project_latte_v1_3.md`.
4. **Don't** re-read S1-S11 memory entries — consolidated into `project_latte_v1_0.md` + `project_latte_v1_1.md` + `project_latte_v1_2.md` during S13.

---

## Owner-side pending (unchanged from S20)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-9 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. PNG candidates unchanged from S20 wrap. | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program — **applied 2026-05-02** | Awaiting Apple review | 1-2 days |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## v1.9 owner-visible behavior reference (unchanged from S20 wrap)

(See git history of this file for the v1.9 popover / Settings / CoffeeCupView render diagrams — content unchanged from prior wrap, omitted here to keep this file focused on S21 deltas.)
