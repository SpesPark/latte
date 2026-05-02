# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S22** — resumed owner-driven manual smoke, Step 6 light-mode visibility (2026-05-02 → 2026-05-03). **Four P-issues** total. Three from owner manual smoke (cup body too dark, handle invisible, noir as pure black) + one self-discovered during checklist preparation (no ⌘, / ⌘Q wiring on popover footer in LSUIElement context). Eight-commit chain: 4 fixes + 2 doc-sync iterations. |
| **Theme** | "Manual smoke catches the **visible** layer; source inspection during checklist prep catches the **omitted** layer. Owner-eyes found three contrast/colour defects that automated luminance tests had missed; my source-inspection found a fourth — popover ⌘ shortcuts that never existed because LSUIElement apps have no application menu to inherit them from. Both classes of finding need to be in the loop — automated tests for what they catch, manual smoke for visual fidelity, source inspection for keybinding completeness." |
| **Status** | ✅ **4 fix commits + 2 doc-sync commits.** **Tests 554 → 558** (+4 net: P1 +1, P2 +2, P3 +1, P4 +0 — UI-only). **Smoke 22/22 PASS** post-each-fix. Working tree clean. |
| **Tail commit** | `272970b` (fix: popover ⌘, and ⌘Q keyboard shortcuts) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S22 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S22 (P-issue-4 added)                   (S22 #6)
272970b        fix: popover ⌘, and ⌘Q keyboard shortcuts                              (S22 #5)
df50c71        docs: SESSION_HANDOFF wrap for S22 (P-issues 1-3)                      (S22 #4)
e4b340e        fix: noir accent light-mode — charcoal grey not pure black             (S22 #3)
69d8927        fix: light-mode cup stroke — solid coffee brown for handle visibility  (S22 #2)
ebbd04a        fix: light-mode cup body — brighter than liquid                        (S22 #1)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `ebbd04a` | **P-issue-1 — light-mode cup body re-fix supersedes S20 P2.** Owner reported "two layers of coffee in a handle-less cup" — cup body `(0.42, 0.32, 0.20)` and Espresso liquid `(0.42, 0.24, 0.08)` had sRGB-avg gap=0.067, blending into one brown mass with foam line reading as coffee-on-coffee boundary. Mental model was wrong: mug is a light vessel holding dark coffee. Fix: cup light → `(0.86, 0.80, 0.72)` warm tan. Replaced single-sided `avg ≤ 0.55` ceiling test with two inter-layer gap tests (cup ≥ liquid + 0.30, cup ≤ popover 0.85). | +1 |
| 2 | `69d8927` | **P-issue-2 — light-mode stroke solid coffee brown.** After P-issue-1 fix, owner reported outline visible but handle barely visible. Same `labelColor.alpha(0.55)` stroke for both — but closed body outline reads from 4-way edge cues, while open handle curve floating in popover background perceptually washes out at alpha 0.55. Fix: `Theme.Colors.cupStroke` becomes dynamic NSColor — light: solid `(0.36, 0.20, 0.09)` coffee brown alpha 1.0; dark: `labelColor.alpha(0.55)` (legacy preserved). Two regression-pin tests: light alpha=1.0 + avg≤0.30; dark alpha=0.55 pin. | +2 |
| 3 | `e4b340e` | **P-issue-3 — noir light charcoal grey.** Owner reported Noir accent rendered as solid black against tan cup body. Previous `(0.20, 0.20, 0.20)` was darker than every other accent (espresso=0.247, mocha=0.36) and indistinguishable from pure #000. Fix: noir light → `(0.32, 0.32, 0.32)` clear charcoal. Still the darkest accent, but visibly grey. Test `testNoirAccentLightModeIsCharcoalNotBlack` (avg ≥ 0.28). | +1 |
| 4 | `df50c71` | **Doc sync** for P-issues 1-3: ROADMAP row 21 + SESSION_HANDOFF + memory. | 0 |
| 5 | `272970b` | **P-issue-4 — popover ⌘, and ⌘Q.** Self-discovered while writing the manual-smoke checklist for the remaining Step 6 surfaces: source inspection revealed the popover footer "Settings…" and "Quit" Buttons had no `.keyboardShortcut(...)` modifier. Latte runs as `LSUIElement` with `.accessory` activation policy, so there is no standard application menu providing ⌘, / ⌘Q for free — the keybindings I had told the owner to test simply did not exist. Fix: SwiftUI `.keyboardShortcut(",", modifiers: .command)` on Settings… + `.keyboardShortcut("q", modifiers: .command)` on Quit. Both bind to the popover's responder chain — fire only when popover is the key window, no cross-app focus conflict. No conflict with B1.2 global hotkey (default ⌘⇧L — different modifier set). 558 tests still PASS, smoke 22/22 PASS. UI-only — no test added (SwiftUI `.keyboardShortcut` modifier has no public introspection API). | 0 |
| 6 | this commit | **Doc sync** for P-issue-4: ROADMAP row 21 amended to 4 P-issues + 8-commit chain; SESSION_HANDOFF + memory updated. | 0 |

### Patterns reinforced this session

- **Inter-layer contrast tests** (from P-issue-1) — when a colour contrasts against **another rendered element** (cup body vs. liquid, not vs. background), the contract test must encode the **luminance gap between the two**. Single-sided ceilings on either side independently let you pick a value that "passes the dark-enough test" while creating a worse defect on the adjacent layer. **Now the default test pattern for any future dynamic-color introduction.**
- **Mug-and-coffee mental model** (from P-issue-1) — vessel-holds-contents UI: body sits **between** contents and background brightness. Not "as dark as possible against white".
- **Closed-shape vs open-curve perceptual asymmetry** (from P-issue-2) — same alpha-blended stroke reads stronger on a closed bounded shape (4-way edge cues) than on a free-floating curve. An alpha that works for an outline can hide a handle/curve. **Light-mode strokes default to solid alpha 1.0 unless a specific reason holds.**
- **Floor-test against pure black** (from P-issue-3) — perceptually any RGB with avg < 0.25 reads as solid black against most cup bodies. Accent palettes need a darkness-floor regression test, not just upper-bounds.
- **Sequential owner-report cascade** — each fix exposed the next layer of regression. Once cup body was correct, stroke became the bottleneck. Once stroke was correct, noir became the bottleneck. Step 6 manual smoke is now confirmed as the canonical popover light-mode regression catch — automated luminance tests caught some defects but missed the inter-layer + perceptual-asymmetry issues.
- **LSUIElement popover keybinding completeness** (P-issue-4) — menu-bar-only apps with `.accessory` activation policy do not have a standard application menu, so ⌘, and ⌘Q must be wired explicitly via SwiftUI `.keyboardShortcut(...)` on the popover Buttons. There is no inherited fallback. **Source-inspection during any popover UX checklist preparation should grep for `.keyboardShortcut(` on every visible Button and flag any missing keybindings before owner spends time testing them.** Found by my own checklist prep, not by owner — this class of "documented behaviour that doesn't actually exist" is the reason source-inspection has to be in the loop alongside manual smoke.

### What was checked but not changed

- **Foam light-mode `(0.78, 0.68, 0.50)`** — owner-confirmed OK in revised report. Foam now darker than cup `(0.86, 0.80, 0.72)` but draws on top of liquid (espresso 0.247) — gap from liquid = 0.406, still strong.
- **CoffeeAccent.latte light** — has the smallest cup-vs-liquid gap (0.193 — cup 0.793 vs. latte 0.6). Still visually distinct (warm tan mug holding lighter beige), but if owner picks Latte accent and reports a regression, the inter-layer gap test will need to upgrade from default Espresso to all five accents.
- **Other accents (caramel, mocha, latte) light values** — all in usable mid-tone range (0.36 – 0.6). Only noir was flagged. No changes.
- **Steam particles** — owner-confirmed OK ("천천히 잘 올라감").

---

## Next-session entry points (priority order)

1. **Continue Step 6 verification** — visual-confirm all four fixes land (cup body / stroke + handle / noir / popover ⌘ shortcuts), then 4-step compressed checklist for the remaining popover surfaces: (1) duration preset click → ✓ + caption tick, (2) Turn off click → sleep, (3) ⌘, **now wired** → Settings opens, (4) ⌘Q **now wired** → app quits. Then **Step 7** (Settings 4-tab light + dark) and **Step 8** (Activity tab — Charts + colour pickers + live polling).
2. **Owner-blocked S8d** (~5 min Pages deploy: pick 5-9 PNGs / `deploy_pages.sh <url>` / Settings → Pages 1-click / curl validate).
3. **Owner-blocked S8.5** ($99/yr Apple Dev Program — applied 2026-05-02, awaiting 1-2 day approval).
4. **Owner-blocked S9** (App Store Connect metadata; depends on 8.5).
5. **C-3 still-deferred** (joint design with B1.2): iCloud sync of activity history + iCloud chord sync.
6. **V2-06 still-deferred**: lid-closed-only mode, per-display position requirement.
7. **B1.2 still-deferred** (per 07-spec §1): per-action chords, iCloud sync of chord, false-negative chord-reserved indicator.
8. **C-7 still-deferred**: Path B + Path C — both retired.
9. **V2-22 GitHub remote** — repo push, CI execution, gh-pages branch enable.

The v1.x feature backlog stays **functionally exhausted**. S22 is a P-issue-driven re-fix series on top — no version bump, still v1.9.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -16
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 558 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 558/558 tests PASS in ~8.5s. Smoke 22/22 PASS in ~6:14.

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

## v1.9 owner-visible behavior reference (Step 6 light-mode cup updated post-S22)

Light-mode `CoffeeCupView` now renders:

```
Popover background  ≈ near-white (0.95)
   │
   ├── Cup body (warm tan)        (0.86, 0.80, 0.72)  avg=0.793   ← S22 P-issue-1
   │     │
   │     ├── Liquid (Espresso)    (0.42, 0.24, 0.08)  avg=0.247
   │     │     └── Foam line (1px, α=0.7)  (0.78, 0.68, 0.50)  avg=0.653
   │     │
   │     └── Stroke (coffee brown)  (0.36, 0.20, 0.09)  avg=0.217  ← S22 P-issue-2
   │           applies to body outline + handle, both at α=1.0
   │
   └── Steam particles (foam α-fade)  same color as foam line
```

Visual gap stack (light mode, sRGB-avg):
- Cup vs. popover: 0.95 − 0.793 = **0.157** (cup outline reads against background)
- Cup vs. liquid: 0.793 − 0.247 = **0.546** (mug reads against coffee)
- Stroke vs. cup body: 0.793 − 0.217 = **0.576** (outline + handle visible against cup)
- Stroke vs. popover: 0.95 − 0.217 = **0.733** (handle reads against background — P-issue-2 fix)
- Liquid vs. foam line: 0.653 − 0.247 = **0.406** (foam reads on liquid)

Accent palette light-mode brightness floor (post-S22 P-issue-3):
- Espresso: 0.247 (warm brown undertones, not pure black)
- Mocha: 0.36
- Caramel: 0.46
- Latte: 0.6
- **Noir: 0.32** (charcoal — visibly grey, not solid black)

Dark-mode rendering unchanged (cup `(0.95, 0.95, 0.97)`, foam `(0.96, 0.93, 0.85)`, stroke `labelColor.alpha(0.55)`).
