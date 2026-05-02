# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S22** — resumed owner-driven manual smoke (2026-05-02 → 2026-05-03). **Five P-issues** total. Three light-mode visual issues from owner manual smoke (cup body too dark, handle invisible, noir as pure black). One self-discovered keybinding gap (popover ⌘, / ⌘Q in LSUIElement context — attempted, owner-confirmed non-functional, reverted). One pause-all snooze bug (`.awakeTriggered` → `.snoozed` painted misleading "Until X" caption + didn't auto-recover). Twelve-commit chain. |
| **Theme** | "Constraint ≠ user gesture. Pause-all, AC unplug, and other system-level forces must NOT inherit the user-deactivate FSM path — the user-flavoured `.snoozed` transition paints a misleading 'Until X' caption that lies about who initiated the sleep. New `.constraintDeactivate` input is the canonical handler now. Plus: constraint-lift hooks must trigger re-evaluation, because steady-state conditions don't naturally re-fire." |
| **Status** | ✅ **5 fix commits + 1 revert + 3 doc-sync commits.** **Tests 554 → 561** (+7 net: P1 +1, P2 +2, P3 +1, P4 +0/reverted, P5 +3). **Smoke 22/22 PASS** post-each-fix. Working tree clean. |
| **Tail commit** | `378b614` (chore: revert popover ⌘, / ⌘Q modifiers — owner-confirmed non-functional) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S22 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S22 (P-issue-5 + P-issue-4 deferral)   (S22 #12)
378b614        chore: revert popover ⌘, / ⌘Q — owner-confirmed non-functional       (S22 #11)
895947a        fix: pause-all bypasses snooze + lift hook re-evaluates triggers      (S22 #10) ← P-issue-5
cebff0a        docs: SESSION_HANDOFF wrap for S22 P-issue-4 (popover ⌘ shortcuts)    (S22 #9)
272970b        fix: popover ⌘, / ⌘Q keyboard shortcuts (initial fix)                 (S22 #8)  ← P-issue-4 reverted in #11
df50c71        docs: SESSION_HANDOFF wrap for S22 (3 P-issues + cascade pattern)     (S22 #7)
e4b340e        fix: noir accent light-mode — charcoal grey not pure black            (S22 #6)  ← P-issue-3
69d8927        fix: light-mode cup stroke — solid coffee brown for handle visibility (S22 #5)  ← P-issue-2
ebbd04a        fix: light-mode cup body — brighter than liquid                       (S22 #4)  ← P-issue-1
```

(P-issue-1 / 2 / 3 / 4 / 5 chronologically; commits #1-3 below the visible window are S20/S21 wrap+intro.)

### What landed this session (5 P-issues)

| P# | Resolution path | Tests Δ |
|---|---|---|
| P1 | `ebbd04a`. Cup light `(0.42, 0.32, 0.20)` → `(0.86, 0.80, 0.72)` warm tan. Replaced single-sided `avg ≤ 0.55` ceiling with two inter-layer gap tests (cup ≥ liquid + 0.30, cup ≤ popover 0.85). | +1 |
| P2 | `69d8927`. `Theme.Colors.cupStroke` becomes dynamic NSColor — light: solid `(0.36, 0.20, 0.09)` coffee brown α=1.0; dark: `labelColor.α(0.55)` legacy. Two regression-pin tests (light alpha+avg, dark alpha pin). | +2 |
| P3 | `e4b340e`. Noir light `(0.20, 0.20, 0.20)` → `(0.32, 0.32, 0.32)` charcoal. Floor-test ≥ 0.28. | +1 |
| P4 | `272970b` → `378b614`. **Attempted-and-reverted.** Added `.keyboardShortcut(",", modifiers: .command)` + `.keyboardShortcut("q", modifiers: .command)` on popover footer buttons. Owner confirmed via manual test that the modifiers don't fire in NSStatusItem popover context (LSUIElement / `.accessory` policy). Reverted; doc-comment in `MenuBarRoot.swift` records the deferral. | 0 |
| P5 | `895947a`. Pause-all from `.awakeTriggered` painted misleading "Until X" caption (because `enterSnoozed` sets `endsAt + reason=.user`). Plus: `.snoozed` lockout held 5 min after pause OFF, with no auto-recovery for steady-state triggers. **Two-part fix**: (a) new `AwakeInput.constraintDeactivate` + helper that goes directly to `.asleep` clearing pendingVotes; (b) `triggersPaused` didSet posts `.latteTriggerPauseDidLift` on true→false transition; `TriggerCoordinator` subscribes and calls `reevaluateAll()` invoking new `Trigger.reevaluateWatched()` (default empty impl, 5 concrete triggers already implement it). | +3 |

### Patterns reinforced this session

- **Inter-layer contrast tests** (P-issue-1) — colour fixes vs. another rendered element need gap tests, not single-sided ceilings.
- **Mug-and-coffee mental model** (P-issue-1) — vessel body sits **between** contents and background brightness-wise.
- **Closed-shape vs open-curve perceptual asymmetry** (P-issue-2) — alpha-blended stroke reads stronger on bounded shapes than on free-floating curves; light-mode strokes default to solid alpha 1.0.
- **Floor-test against pure black** (P-issue-3) — accent palettes need a darkness floor (avg ≥ 0.25), not just upper bounds.
- **LSUIElement popover keybinding completeness ≠ keybinding functionality** (P-issue-4) — source-inspection during popover UX checklist prep can flag missing `.keyboardShortcut(...)` modifiers, but **only owner manual smoke can confirm they actually fire** in the NSStatusItem popover context. Source-inspection finds the omission; manual smoke confirms whether the proposed wiring actually works. **Both halves are required.**
- **Constraint-driven deactivate ≠ user-driven deactivate** (P-issue-5) — system-level forces (pause-all, AC unplug) must NOT inherit the user-deactivate FSM transition table, because the `.snoozed` path that follows `.userDeactivate` from `.awakeTriggered` paints a misleading "Until X" caption. New `AwakeInput.constraintDeactivate` is the canonical handler.
- **Constraint-lift hooks for stateless re-evaluation** (P-issue-5) — when a constraint that suppressed triggers is lifted, the coordinator must explicitly ask each trigger to re-emit. Steady-state conditions (Notion still running, calendar event still in progress) don't naturally re-fire — they're not transition-driven.
- **Sequential cascade in resumed manual smoke** — each owner-driven fix exposes the next layer (cup body → stroke → noir → popover keybinding gap → pause-all snooze). Step 6 is now confirmed as the canonical popover regression catch.

### What was checked but not changed

- **Foam light-mode `(0.78, 0.68, 0.50)`** — owner-confirmed OK in revised report.
- **Stroke dark-mode `labelColor.α(0.55)`** — owner-confirmed OK.
- **CoffeeAccent.latte light** — has the smallest cup-vs-liquid gap (0.193). Still visually distinct, but if owner picks Latte and reports a regression, the inter-layer gap test will need to upgrade from default Espresso to all five accents.
- **Steam particles** — owner-confirmed OK ("천천히 잘 올라감").
- **AC-unplug constraint behaviour** — same theoretical bug (deactivate-to-snoozed paints "Until X"). The new `.constraintDeactivate` input handles it correctly too (helper is symmetric across all states), but owner only reported the pause-all variant. Coverage extends naturally; no separate test needed yet.

---

## Next-session entry points (priority order)

1. **Continue Step 6 verification** — re-confirm P5 (pause-all caption clear + post-unpause auto-recovery) lands. Then Step 6 region 6 (Recurring quick presets — owner deferred until P5 fixed) and region 7 (B1.2 ⌘⇧L global hotkey, optional). Then **Step 7** (Settings 4-tab) and **Step 8** (Activity tab).
2. **Owner-blocked S8d** (~5 min Pages deploy).
3. **Owner-blocked S8.5** (Apple Dev Program — applied 2026-05-02).
4. **Owner-blocked S9** (App Store Connect; depends on S8.5).
5. **C-3 still-deferred** (joint design with B1.2): iCloud sync of activity history + iCloud chord sync.
6. **V2-06 still-deferred**: lid-closed-only mode, per-display position requirement.
7. **B1.2 still-deferred** (per 07-spec §1): per-action chords, iCloud sync of chord, false-negative chord-reserved indicator.
8. **C-7 still-deferred**: Path B + Path C — both retired.
9. **V2-22 GitHub remote**.
10. **P-issue-4 revisit** (low-priority): NSEvent.addLocalMonitor on popover-show to wire ⌘, / ⌘Q via direct key event handling rather than SwiftUI `.keyboardShortcut(...)`. Defer until owner explicitly requests, or a future macOS changes popover focus handling.

The v1.x feature backlog stays **functionally exhausted**. S22 is a P-issue-driven re-fix series on top — no version bump, still v1.9.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -16
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 561 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 561/561 tests PASS in ~8.5s. Smoke 22/22 PASS in ~6:14.

**Note**: S16-S22 occasionally hit `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual is mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 21 (S22) for the most recent session.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (13-line index) → drill into `project_latte_v1_9.md` (now contains S20 ship + S21 + S22 sections); v1.8 (S19) lives in `project_latte_v1_8.md`; older entries in earlier `project_latte_v*.md` files.
4. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (unchanged from S21)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-9 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program — applied 2026-05-02 | Awaiting Apple review | 1-2 days |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## v1.9 owner-visible behavior reference (post-S22)

Light-mode `CoffeeCupView`:
```
Popover (≈0.95) > Cup body (warm tan, 0.793) > Liquid (Espresso 0.247)
                                              > Stroke (coffee brown, 0.217, α=1.0)  ← P2
                                              > Foam line (0.653, on liquid)
Accent floor: Noir 0.32 (charcoal), Espresso 0.247, Mocha 0.36, Caramel 0.46, Latte 0.6
```

Pause-all behaviour (post-P5):
```
.awakeTriggered  ── Pause ON ─→  .asleep        (was: .snoozed with stale "Until X")
                                  ↓
                    pendingVotes cleared, reason=.none, header "Tap to wake your Mac"
                                  ↓
.asleep          ── Pause OFF ─→ .latteTriggerPauseDidLift posted
                                  ↓
                    TriggerCoordinator.reevaluateAll() → each trigger.reevaluateWatched()
                                  ↓
                    Steady-state condition (Notion running) → vote ON → .awakeTriggered
```

Dark-mode rendering unchanged (cup `(0.95, 0.95, 0.97)`, foam `(0.96, 0.93, 0.85)`, stroke `labelColor.α(0.55)`).
