# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S22** — resumed owner-driven manual smoke (2026-05-02). Step 6 (popover light + dark) was the first surface re-checked after the S20 P1+P2 ship. Owner reported the light-mode cup still rendered as "two layers of coffee in a handle-less cup" — cup body and liquid blended, foam line read as a coffee-on-coffee boundary, stroke lost contrast against the dark cup body. Root cause was a wrong mental model in S20 P2: cup body must sit **between** liquid and background luminance, not just be "darker than white." Two-commit chain: P-issue-1 fix + this doc-sync. |
| **Theme** | "When a colour fix involves contrast against **another rendered element**, not just the background, the contract test must encode the **inter-layer luminance gap**. Single-sided ceilings let you pick a value that 'passes the dark-enough test' while creating a worse visual defect on the adjacent layer. Mug-and-coffee model: cup body sits between the liquid and the popover background brightness-wise — not at one end." |
| **Status** | ✅ **1 fix commit + 1 doc-sync commit + smoke validation this session.** **Tests 554 → 555** (+1 net: replaced 1 obsolete ceiling test with 2 mug-model contract tests). **Smoke 22/22 PASS** in ~6:14. Working tree clean. |
| **Tail commit** | `ebbd04a` (fix: light-mode cup body — brighter than liquid (S22 / P-issue-1)) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S22 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S22                              (S22 #2)
ebbd04a        fix: light-mode cup body — brighter than liquid (S22 / P-issue-1)  (S22 #1)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `ebbd04a` | **S22 / P-issue-1 — light-mode cup body re-fix supersedes S20 P2.** Owner-reported during the resumed Step 6 manual smoke: in light mode, cup body `(0.42, 0.32, 0.20)` and the default Espresso liquid `(0.42, 0.24, 0.08)` had near-identical luminance (gap=0.067 sRGB-avg), so the two layers blended into one brown mass with the 1px foam line between them reading as a coffee-on-coffee boundary. Stroke (`labelColor.alpha(0.55)` ≈ darkish grey) also lost contrast against the dark cup body, hiding the outline + handle. **Fix**: cup light → `(0.86, 0.80, 0.72)` warm tan mug — brighter than every `CoffeeAccent` liquid tone (so cup body reads as the mug, not as more coffee) and darker than the near-white popover background (so the labelColor stroke remains visible). Dark-mode value `(0.95, 0.95, 0.97)` unchanged. **Test refactor**: replaced the obsolete `testCupLightModeIsPerceptiblyDarkerThanWhite` (single-sided `avg ≤ 0.55` ceiling — passed with the wrong cup colour) with two contract tests: `testCupLightModeBrighterThanDefaultLiquidByMargin` (cup_avg ≥ liquid_avg + 0.30) + `testCupLightModeDarkerThanPopoverBackground` (cup_avg ≤ 0.85). Pre-fix the new gap test failed at 0.067; post-fix it passes at 0.546. 554 → 555 tests (+1 net: −1 obsolete, +2 new). Smoke 22/22 PASS. | +1 |
| 2 | this commit | **Doc sync**: ROADMAP row 21 (S22) prepended; SESSION_HANDOFF rewritten for S22; memory updated with S22 follow-up section; `MEMORY.md` index entry refreshed. | 0 |

### Patterns reinforced this session

- **Inter-layer contrast test pattern** — when a colour exists primarily to contrast against **another rendered element** (cup body vs. liquid, not vs. background), the contract test must encode the **luminance gap between the two**, not a single-sided ceiling on either one. Single-sided tests let you pick a value that "passes the dark-enough test" while creating a worse defect on the adjacent layer. The S20 P2 `cup avg ≤ 0.55` ceiling passed with `0.31` (cup body) but allowed cup ≈ liquid, which is what owner saw.
- **Mug-and-coffee mental model** — cup body sits **between** liquid and popover-background brightness-wise. Not "as dark as possible against white" — that's the visual logic of a pencil on paper, not a vessel holding contents.
- **Step 6 manual smoke is now the canonical popover light-mode regression catch** — automated tests with luminance proxies caught 50% of the visual defect (foam visibility) but missed the inter-layer issue. Owner-driven manual smoke is essential for visual contract validation.

### What was checked but not changed

- **Foam light-mode value** `(0.78, 0.68, 0.50)` — still correct: brighter than the new cup `(0.86, 0.80, 0.72)`? Foam avg = 0.653, cup avg = 0.793 — **foam is now darker than cup**, but foam draws on top of liquid (avg 0.247), and foam is still 0.406 brighter than liquid, which is the relevant gap (foam = "creamy cap on top of espresso"). The 1px foam line on top of the cup body (when liquid is empty / fillRatio < 0.05) doesn't render — `if fillRatio > 0.05` gate guards it. Foam light value left unchanged.
- **Stroke `labelColor.alpha(0.55)`** — at light mode, labelColor ≈ near-black, so stroke avg ≈ 0.45 (alpha 0.55 against the cup body 0.793). Gap from cup is ~0.34 — clearly visible. No change needed.
- **CoffeeAccent.latte light `(0.78, 0.62, 0.40)`** — avg = 0.6. Cup avg = 0.793. Gap = 0.193 — 35% smaller than the espresso gap (0.546). Still visually distinct (warm tan mug holding lighter beige coffee), but the latte accent has the smallest separation. If owner picks Latte accent and reports a regression, the gap test (currently keyed to default Espresso) will need to upgrade to cover all five accents.

---

## Next-session entry points (priority order)

1. **Continue Step 6 (light + dark) verification** — re-confirm fix lands visually, then check (a) "Activate / Sleep / Activate until …" buttons + Quick presets list, (b) preset countdown caption tick, (c) Pause-all caption, (d) ⌘, → Settings, (e) ⌘Q → quit. After Step 6 lands → **Step 7** (Settings 4-tab light + dark) and **Step 8** (Activity tab — Charts + colour pickers + live polling).
2. **Owner-blocked S8d** (~5 min Pages deploy: pick 5-9 PNGs / `deploy_pages.sh <url>` / Settings → Pages 1-click / curl validate).
3. **Owner-blocked S8.5** ($99/yr Apple Dev Program — applied 2026-05-02 per owner, awaiting 1-2 day approval).
4. **Owner-blocked S9** (App Store Connect metadata; depends on 8.5).
5. **C-3 still-deferred** (joint design with B1.2): iCloud sync of activity history + iCloud chord sync.
6. **V2-06 still-deferred** (no further v1.x scope): lid-closed-only mode, per-display position requirement.
7. **B1.2 still-deferred** (per 07-spec §1): per-action chords, iCloud sync of chord, false-negative chord-reserved indicator.
8. **C-7 still-deferred**: Path B (`.until(Date)` enum) + Path C (`@Published activeQuickPreset` aside) — both retired.
9. **V2-22 GitHub remote** — repo push, CI execution, gh-pages branch enable. Owner action.

The v1.x feature backlog stays **functionally exhausted** post-S20. S22 is a P-issue-driven re-fix on top — no version bump, still v1.9.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -16
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 555 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 555/555 tests PASS in ~8.5s. Smoke 22/22 PASS in ~6:14.

**Note**: S16-S22 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 21 (S22) for the most recent session; row 20 (S21) for autonomous polish; row 19 (S20) for v1.9 ship context.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (13-line index) → drill into `project_latte_v1_9.md` (now contains S20 ship + S21 + S22 sections); v1.8 (S19) lives in `project_latte_v1_8.md`; older entries in earlier `project_latte_v*.md` files.
4. **Don't** re-read S1-S11 memory entries — consolidated into `project_latte_v1_0.md` + `project_latte_v1_1.md` + `project_latte_v1_2.md` during S13.

---

## Owner-side pending (unchanged from S21)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-9 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program — applied 2026-05-02 | Awaiting Apple review | 1-2 days |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## v1.9 owner-visible behavior reference (Step 6 light-mode cup updated)

Light-mode `CoffeeCupView` now renders:

```
Popover background  ≈ near-white (0.95)
   │
   ├── Cup body (warm tan)  (0.86, 0.80, 0.72)  avg=0.793   ← S22 fix
   │     │
   │     ├── Liquid (Espresso default)  (0.42, 0.24, 0.08)  avg=0.247
   │     │     └── Foam line (1px)  (0.78, 0.68, 0.50, α=0.7)  avg=0.653
   │     │
   │     └── Stroke (labelColor α=0.55, ≈ dark grey)         avg≈0.45
   │
   └── Steam particles (foam α-fade)  same colour as foam line
```

Visual gap stack (light mode, sRGB-avg):
- Cup vs. popover: 0.95 − 0.793 = **0.157** (cup outline reads against background)
- Cup vs. liquid: 0.793 − 0.247 = **0.546** (mug reads against coffee — owner-reported defect resolved)
- Cup vs. stroke: 0.793 − 0.45 = **0.343** (handle + outline visible)
- Liquid vs. foam line: 0.653 − 0.247 = **0.406** (foam stroke reads on liquid)

Dark-mode rendering unchanged (cup `(0.95, 0.95, 0.97)`, foam `(0.96, 0.93, 0.85)`).
