# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S17** — same-day continuation of S16 (2026-05-01, **3rd autonomous-cycle session of the day**: S15 → S16 → S17). C-7 Path A + B1.2 polish (J) + 10th simplify-pass. |
| **Theme** | "Ship the C-7 Quick presets owner-decision (Path A) + close out the last B1.2 deferred polish item — same TDD-RED → GREEN → simplify-pass cadence as the prior 9 passes." |
| **Status** | ✅ **2 feat commits + 1 simplify-pass commit + 1 doc commit this session.** **485 → 494 tests** (+9). **Smoke unchanged at 22** (new flows are owner manual smoke step 6 territory). Working tree clean. Test run ~7.4 s. |
| **Tail commit** | (post doc-sync commit forthcoming after this file lands) |

### Commit chain (S17 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S17 (C-7 + J + 10th simplify-pass) (S17 #4)
bd46fb8        chore: 10th simplify-pass follow-through (S17)                   (S17 #3)
86d2556        feat: B1.2 disabled-state UX cue on ShortcutRecorderField (J)    (S17 #2)
7252a0b        feat: C-7 Quick presets — Until 5/11 PM/midnight (Path A)        (S17 #1)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `7252a0b` | **A — C-7 Quick presets (Path A)**. Path D retired (C-3 already shipped in v1.3 + v1.5). New pure `QuickPreset` enum (`.until5PM` / `.until11PM` / `.untilMidnight`) with `nextOccurrence(after:)` + `minutes(from:)` helpers. Conversion to `.minutes(N)` happens at click time in MenuBarRoot — FSM unchanged. Already-passed targets roll to tomorrow. Midnight encoded as `targetHour=24` → next day's `startOfDay`. `min(1)` clamp guarantees no 0-min activation at boundary. New `QuickPresetRow` (distinct from `DurationPickerRow` so checkmark logic stays simple — preset rows never highlight; the active "Until X PM" session lights up the Custom row instead, per 08-spec §5 Path A trade-off). Test fixtures use UTC-anchored `DateComponents` (NOT raw epoch arithmetic) to avoid CI timezone drift. | +9 |
| 2 | `86d2556` | **J — B1.2 disabled-state UX refinement**. `ShortcutRecorderField` now `.opacity(0.5) + .disabled(true)` when `coordinator.isEnabled == false` (the displayed glyph was misleading — looked live, wasn't). Reset button gates on isEnabled too + `.help()` tooltip showing the default glyph. Inline secondary-fg hint `"Enable the shortcut above to record a different chord."` replaces the silent grey-out with an actionable nudge. The intentionally-deferred items in 07-spec §1 (per-action chords, iCloud sync, false-negative chord-reserved indicator) remain out of v1.x scope per spec. | 0 |
| 3 | `bd46fb8` | **10th simplify-pass** on S17 commits 1-2. APPROVE-WITH-NITS (0 CRIT/HIGH/MED, 3 LOW). 2 actionable addressed: LOW-1 misleading `testMinutesNeverReturnsZeroOrNegative` comment tightened (said "target == now to ms" but fixture was 1s before target); LOW-5 `ShortcutRecorderField.onChange(of: coordinator.isEnabled)` cancels mid-recording when toggle flips off (avoids "Press shortcut…" lingering behind dimmed widget). LOW-2 (midnight nil-fallback unreachable), LOW-3 (asymmetric ForEach id), LOW-4 (no explicit accessibilityLabel) all noted-only. | 0 |
| 4 | this commit | **Doc sync**: ROADMAP row 16 (S17) prepended; v2-backlog "Shipped in v1.6 (S17)" entry added; 08-c7 spec status flipped from "Decision-pending" to "**Path A shipped**", §9 "As shipped" filled with deferred design decisions. Memory: NEW `project_latte_v1_6.md`; `MEMORY.md` index 9 → 10 lines. SESSION_HANDOFF rewritten. | 0 |

### Patterns reaffirmed this session

- **Simplify-pass cadence is now 10 passes deep** (S10/S10.1/S11/S11/S12/S13/S14/S15/S16/S17). All APPROVE or APPROVE-WITH-NITS. **Standing ritual after each batch of feature commits**: code-reviewer agent ~3 min + follow-through commit ~10 min.
- **Owner-tolerable UX nits → ship Path A, document trade-off in spec §5/§9**: when the cleaner path costs 2× more effort and the nit is owner-tolerable per spec, the smaller path with documented trade-off is the good shipped-product call. The C-7 Path A "checkmark on Custom row instead of preset row" is the canonical example. Spec §11 / §9 patterns continue.
- **UTC DateComponents fixture pattern**: avoid raw `Date(timeIntervalSince1970: ...)` arithmetic — CI timezone bites. Build dates via `Calendar.date(from:)` with explicit `timeZone = TimeZone(secondsFromGMT: 0)`. Initial S17 tests had a 1_800_032_400 epoch that I assumed was 9 AM UTC but was actually 5 PM UTC — fixture refactor caught it before commit.
- **`.onChange(of: ...)` for cross-state UI cancellation**: when state X going false should cancel state Y in flight, prefer SwiftUI `.onChange` over polling or imperative chaining. Used in 10th simplify-pass LOW-5 fix on `ShortcutRecorderField`.
- **`targetHour=24` sentinel for "next-midnight" in calendar arithmetic**: hour=0..23 path uses `Calendar.dateComponents` + `.year/.month/.day/.hour`; hour=24 path uses `startOfDay(now) + 1 day`. Single Int property, two distinct semantic operations. Pattern to copy when next "next occurrence of X" helper lands.
- **Spec §1 deferred items are intentionally OOS**: when "small scope" J item is requested and the spec deferred list is all large-feature work (iCloud sync, per-action chords) or false-negative-prone (chord-reserved indicator), ship polish on the existing surface instead of forcing scope. The polish is owner-visible, the deferred list stays honest.

---

## Next-session entry points (priority order)

1. **Owner UI smoke 8-step** — steps 6 + 7 + 8 still pending. **Step 6 expanded for v1.6**: also click each of the 3 new "Until X PM" rows in the popover and verify activation + verify the active session lights up the Custom row (the documented Path A trade-off, not a bug). **Step 6 J check**: disable the keyboard shortcut toggle and verify the recorder field dims + shows "Enable the shortcut above to record a different chord."
2. **Owner-blocked S8d** (~5 min Pages deploy: pick 5-9 PNGs / `deploy_pages.sh <url>` / Settings → Pages 1-click / curl validate). PNG candidate set is now **fully built out** — popover has 3 sections (presets / custom / quick presets), Activity tab has 3 charts, Triggers tab has whitelist UI, About tab shows clamshell-tagged reasons.
3. **Owner-blocked S8.5** ($99/yr Apple Dev Program enrollment, 1-2 days approval).
4. **Owner-blocked S9** (App Store Connect metadata; depends on 8.5).
5. **C-3 still-deferred**: live polling refresh, iCloud sync, user-customisable Charts colours.
6. **V2-06 still-deferred** (no further v1.x scope): lid-closed-only mode, per-display position requirement.
7. **B1.2 still-deferred** (per 07-spec §1): per-action chords, iCloud sync of chord, false-negative chord-reserved indicator. All large or low-utility.
8. **C-7 still-deferred** (per 08-spec §9): Path B (`.until(Date)` enum), Path C (`@Published activeQuickPreset` aside) — both retired; per-day-of-week recurring presets is the only meaningful next step.
9. **V2-22 GitHub remote** — repo push, CI execution, gh-pages branch enable. Owner action.

The v1.x feature backlog is now **functionally exhausted** — no v1.x deferred items remain for autonomous shipping. Next code work needs owner direction (new feature ask, B1.2 expansion, or owner-blocked S8d/S8.5 unblocking).

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -13
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 494 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 494/494 tests PASS in ~7.4 s. Smoke 22/22 PASS in ~5 min.

**Note**: S16 + S17 each hit a `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 16 (S17) for full context if needed.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (10-line index) → drill into `project_latte_v1_6.md` for S17 detail; v1.5 (S16) lives in `project_latte_v1_5.md`; v1.3.1 (S15) in `project_latte_v1_3_1.md`; v1.3 (S14) in `project_latte_v1_3.md`.
4. **Don't** re-read S1-S11 memory entries — consolidated into `project_latte_v1_0.md` + `project_latte_v1_1.md` + `project_latte_v1_2.md` during S13.

---

## Owner-side pending (richest PNG set yet)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-9 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. **Popover now has 3 sections** (7 duration presets + Custom + 3 quick presets). **Activity tab has 3 charts**. **Triggers tab has whitelist UI**. **About → Status shows `(clamshell)` tag**. | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program 가입 | Account/payment owner-only | $99/yr + 1-2 days approval |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## C-7 v1.6 owner-visible behavior reference (for step 6 smoke)

```
Click menu bar icon → Popover appears
  ├─ [header: state / mode / power]
  ├─ ── divider ──
  ├─ Pause triggers toggle
  ├─ ── divider ──
  ├─ Section 1 — Duration presets:
  │  ├─ 5 min / 15 min / 30 min / 1h / 2h / 5h / Indefinitely
  │  └─ Custom: [stepper minutes] [Start]
  ├─ ── divider ──
  ├─ Section 2 — Quick presets (NEW):              ← C-7 Path A
  │  ├─ Until 5 PM
  │  ├─ Until 11 PM
  │  └─ Until midnight
  ├─ ── divider ──
  ├─ Turn off button
  └─ Settings… / Quit footer

Behavior (08-spec §3 Path A trade-off):
  Click "Until 5 PM" at 9 AM   → activate(.minutes(480))
  → checkmark renders on Custom row, NOT on "Until 5 PM" row
  → owner-tolerable per spec §5; revisit if user feedback flags
```

## J v1.6 owner-visible behavior (for step 6 smoke)

```
Settings → General → "Toggle Latte with ⌘⇧L":
  Toggle ON  → recorder field shows current chord glyph at full opacity
             → recorder accepts new chord on click + key press
             → "Reset" button enabled iff chord != .default
  Toggle OFF → recorder field at .opacity(0.5), .disabled(true)
             → Reset button disabled
             → secondary-fg hint: "Enable the shortcut above to record a different chord."
             → If mid-recording when toggle flips off: recording cancels (no lingering "Press shortcut…")
```
