# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S20** — second owner-driven manual smoke session, same-day continuation of S19 (2026-05-02). Owner began smoke step 6/7 and surfaced two P-issues: About-tab tab-bar overflow (P1, CRIT) + light-mode coffee-cup invisibility (P2, HIGH). Three-commit fix-first chain. One simplify-pass (14th). |
| **Theme** | "Owner-driven manual smoke continues to drain UX defects. Fix-first per P-severity with same TDD-RED → GREEN → simplify-pass cadence as the prior 12 passes." |
| **Status** | ✅ **2 fix commits + 1 simplify-pass commit this session.** **548 → 554 tests** (+6 net: +2 layout, +6 appearance, -2 redundant). **Smoke unchanged at 22**. Working tree clean. Test run ~7.7s. |
| **Tail commit** | `fd5a5bc` (chore: 14th simplify-pass follow-through) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S20 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S20            (S20 #4)
fd5a5bc        chore: 14th simplify-pass follow-through      (S20 #3)
654c847        fix: dynamic Theme.Colors.cup + foam (P2)     (S20 #2)
97e6a1f        fix: Settings minHeight 360 → 420 (P1)        (S20 #1)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `97e6a1f` | **P1 — Settings window minHeight 360 → 420**. Owner reported during step 7 manual smoke that entering About tab made the tab bar invisible — couldn't switch back to General/Triggers/Activity without manually resizing the window. Root cause: About content (hero card ~196pt + statusCard ~112pt + spacers + footer + padding) totals ~386pt minimum vs ~332pt available content area on a stock 460×360 window (after ~28pt tab bar). The greedy `Spacer()` between statusCard and footer compressed to negative and content rendered over the tab bar. Extracted `SettingsRoot.minWindowWidth` (460) + `minWindowHeight` (420) as static `CGFloat` constants used by both `SettingsRoot.body` `.frame(...)` and `SettingsWindowController.setContentSize`. Window remains user-resizable above the floor. NEW `Tests/SettingsRootLayoutTests.swift` (2 tests): `XCTAssertEqual` two-way contract pin on both constants. | +2 |
| 2 | `654c847` | **P2 — dynamic Theme.Colors.cup + foam for light-mode visibility**. Owner reported during step 6 popover smoke that both the cup outline AND the rising steam particles were nearly invisible after switching from dark to light mode. Root cause: hard-coded near-white creamy values (`cup` `(0.95, 0.95, 0.97)`, `foam` `(0.96, 0.93, 0.85)`) tuned for dark backdrops; light mode also uses near-white backdrop → contrast ≈ 0. Converted both to dynamic `NSColor(name:)` resolving via `appearance.bestMatch(from: [.aqua, .darkAqua])` — pattern matches the existing `CoffeeAccent.color` provider exactly. Dark mode preserves the legacy creamy palette (no regression). Light mode uses deeper cappuccino tones — cup `(0.42, 0.32, 0.20)` (rich brown body), foam `(0.78, 0.68, 0.50)` (warm tan steam, lighter than cup so foam stroke still reads on liquid layer). NEW `Tests/ThemeAppearanceTests.swift` (initially 6, simplified to 4 after pass 14): legacy dark-mode pinning (RGB matches v1.8 values) + light-mode luminance ceilings (cup avg ≤ 0.55, foam avg ≤ 0.7). Menu-bar SF Symbol icon was unaffected — system tints it automatically. | +6 |
| 3 | `fd5a5bc` | **14th simplify-pass follow-through**. APPROVE-WITH-NITS — 0 CRIT/HIGH/1 MED/2 LOW. MED-1: `XCTAssertGreaterThanOrEqual` → `XCTAssertEqual` for two-way height contract (matches the existing `minWindowWidth` equality test); prevents both shrinking below the empirical floor and silent over-constraining via accidental upward bumps. LOW-1: `foam` + `cup` providers extracted `let isDark = ...` so the structure mirrors `CoffeeAccent.color` exactly — improves scan-readability, five extra characters. LOW-2: deleted `testCupColorDiffersBetweenLightAndDark` + `testFoamColorDiffersBetweenLightAndDark` — strictly subsumed by the legacy-pinning + luminance-ceiling pair below them. | -2 |
| 4 | this commit | **Doc sync**: ROADMAP row 19 (S20) prepended; v2-backlog "Shipped in v1.9 (S20)" entry added with 3 patterns block; SESSION_HANDOFF rewritten. Memory: NEW `project_latte_v1_9.md`; `MEMORY.md` index 12 → 13 lines. | 0 |

### Patterns established this session

- **Greedy-Spacer-overflow risk in fixed-height windows.** A `VStack { ...fixed content... Spacer() ...footer... }` pattern silently compresses the Spacer to negative when the parent height < fixed-content height, causing content to render outside parent bounds. The TabView tab bar in particular gets visually overlapped, blocking navigation. Fix: extract the parent minHeight as a named static constant on the root view AND write an `XCTAssertEqual` (not `>=`) test — that's a two-way contract preventing both shrinking below the empirical floor and silent over-constraining via accidental upward bumps.
- **Dual-mode dynamic NSColor pattern for hard-coded brand colors.** `Color(nsColor: NSColor(name:) { appearance in let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua; return isDark ? legacyValue : derivedDeeperValue })`. Preserves the legacy look in the original mode (zero regression) while giving a contrasting variant in the new mode. The `name:` parameter caches resolution so the closure runs once per appearance change, not per draw frame. Match the existing `CoffeeAccent.color` style exactly — extract `let isDark` rather than inline ternary, for readability.
- **Luminance-average proxy as a contrast smoke test.** `(r + g + b) / 3 ≤ threshold` is a coarse but reliable assertion that a color reads against a near-white (or near-black) backdrop without invoking full WCAG contrast math. Useful when the test fixture only has access to resolved sRGB values, not actual rendering context. Tighter than perceptual luminance (`0.299·r + 0.587·g + 0.114·b`) but stable enough for guarding hard-coded brand palettes.
- **Standing simplify-pass ritual is now 14 passes deep** (S10 / S10.1 / S11×2 / S12 / S13 / S14 / S15 / S16 / S17 / S18 / S19×2 / S20). All APPROVE or APPROVE-WITH-NITS. The MED-1 finding in S20 (`>=` vs `=` for the height test) is a textbook illustration: a one-line agent observation prevented a future maintainer from silently over-constraining the window without test signal.

---

## Next-session entry points (priority order)

1. **Continue owner UI smoke 8-step** — Step 7 (Activity tab Chart colours + live polling) Step 7 partial (Settings tabs verified once tab bar regression fixed) and Step 8 still pending. v1.7's three Chart-colour pickers + Reset button + 300ms-debounced live polling are unverified by manual smoke.
2. **Owner-blocked S8d** (~5 min Pages deploy: pick 5-9 PNGs / `deploy_pages.sh <url>` / Settings → Pages 1-click / curl validate). PNG candidate set is even richer post-S20 — light-mode popover header now shows a clean cappuccino cup with visible steam (S20 fix), Settings creates a 460×420 window that fits all four tabs (S20 fix), v1.8 popover/sheet/Pause-caption polish remains. Owner can pick light or dark mode for the screenshot run.
3. **Owner-blocked S8.5** ($99/yr Apple Dev Program — **applied 2026-05-02 per owner**, awaiting 1-2 day approval).
4. **Owner-blocked S9** (App Store Connect metadata; depends on 8.5).
5. **C-3 still-deferred** (joint design with B1.2): iCloud sync of activity history + iCloud chord sync — schema integration risk if shipped solo.
6. **V2-06 still-deferred** (no further v1.x scope): lid-closed-only mode, per-display position requirement.
7. **B1.2 still-deferred** (per 07-spec §1): per-action chords, iCloud sync of chord (joint with C-3 iCloud), false-negative chord-reserved indicator.
8. **C-7 still-deferred**: Path B (`.until(Date)` enum) + Path C (`@Published activeQuickPreset` aside) — both **retired** per 08-spec §10. The seed-then-mutable redesign in §11 is now the canonical C-7 model.
9. **V2-22 GitHub remote** — repo push, CI execution, gh-pages branch enable. Owner action.

The v1.x feature backlog stays **functionally exhausted** post-S20. What changed this session: continued owner-driven UX defect surfacing — exactly the post-v1.7 pattern. Future owner-driven sessions will keep this cadence — surface during use, fix-first, ship.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -16
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 554 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 554/554 tests PASS in ~7.7s. Smoke 22/22 PASS in ~5 min.

**Note**: S16-S20 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 19 (S20) for full context if needed.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (13-line index) → drill into `project_latte_v1_9.md` for S20 detail; v1.8 (S19) lives in `project_latte_v1_8.md`; older entries in `project_latte_v1_7.md` / `project_latte_v1_6.md` / `project_latte_v1_5.md` / `project_latte_v1_3_1.md` / `project_latte_v1_3.md`.
4. **Don't** re-read S1-S11 memory entries — consolidated into `project_latte_v1_0.md` + `project_latte_v1_1.md` + `project_latte_v1_2.md` during S13.

---

## Owner-side pending (richest PNG set yet)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-9 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. **Popover** can show duration presets + 0..N recurring rows (3 seeded by default, all editable / deletable post-S19). **Activity tab** has 3 charts + chart-colour pickers. **General tab** has Custom-presets editor with Delete button in the edit sheet (S19). **Triggers tab** has whitelist UI. **About → Status** shows `(clamshell)` tag. **Light-mode popover** now shows a visible cappuccino cup + tan steam (S20 fix). **Settings window** opens at 460×420 — all four tabs reachable (S20 fix). | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program — **applied 2026-05-02** | Awaiting Apple review | 1-2 days |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## v1.9 owner-visible behavior reference (for step 6 + 7 smoke)

### About tab — fixed in S20

```
Settings window opens at 460×420 (was 460×360):
  ┌─[General][Triggers][Activity][About]─┐  ← all four tabs always reachable
  │                                       │
  │   ┌─────────────────────────────┐     │
  │   │   ☕ (cup illustration)       │     │
  │   │   Latte                       │     │
  │   │   Version 1.0.0 (1)           │     │
  │   │   Keep your Mac awake when… │     │
  │   └─────────────────────────────┘     │
  │   ┌─────────────────────────────┐     │
  │   │ State    Awake               │     │
  │   │ Mode     Display + Idle      │     │
  │   │ Reason   App: Zoom           │     │
  │   │ Power    On AC               │     │
  │   └─────────────────────────────┘     │
  │              © 2026 Latte             │
  └───────────────────────────────────────┘
```

### Light-mode CoffeeCupView render — fixed in S20

```
Light mode (e.g. system Appearance: Light):
  Popover header (36×36):     cup body in deep cappuccino brown,
                              steam particles in warm tan — both visible
                              against near-white popover backdrop.
  AboutTab card (80×80):      same palette, just larger.
  GeneralTab preview, etc.:   same.

Dark mode:                    unchanged from v1.8 — cup near-white,
                              steam creamy off-white.

Menu-bar SF Symbol icon:      unaffected — system tints automatically
                              for both modes (no manual color logic).
```

### Settings window minimum size — fixed in S20

```
Initial open: 460pt × 420pt (was 460×360)
Resize floor: 460pt × 420pt (enforced via .frame(minWidth:minHeight:))
Resize ceiling: none — user can drag any direction freely above floor.
Persisted between launches via setFrameAutosaveName("LatteSettingsWindow").

Constants exposed at SettingsRoot.minWindowWidth / .minWindowHeight
for cross-reference from SettingsWindowController.
```
