# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S22** — resumed owner-driven manual smoke (2026-05-02 → 2026-05-03). **Ten P-issues** total. Three light-mode visual + popover keybinding (reverted) + pause-all snooze caption + P5b reemit follow-up + P6 UX redesign + P6b observer-sync + P6c snooze-bypass + **P6d cross-trigger reemit parity** (P5b auto-recovery only worked for AppTrigger; the other 4 triggers inherited the empty default — owner-prompted audit caught the partial coverage). Twenty-two-commit chain. |
| **Theme** | "Four follow-ups this session — P5→P5b, P6→P6b, P6→P6c, P6→P6d — all caught the same meta-pattern: unit tests passed, but the actual feature didn't fully work. P5b/P6b/P6c were owner-reported runtime gaps. P6d was an owner-prompted parity audit that surfaced a `protocol default ≠ trigger-agnostic feature` blind spot. The harness sees commit-time correctness; runtime + cross-instance parity need explicit auditing." |
| **Status** | ✅ **10 fix commits + 1 revert + 8 doc-sync commits.** **Tests 554 → 570** (+16 net: P1 +1, P2 +2, P3 +1, P4 +0/reverted, P5 +3, P5b +2, P6 +3, P6b +1, P6c +1 net, P6d +2). **Smoke 22/22 PASS** post-each-fix. Working tree clean. |
| **Tail commit** | `0bf0b12` (fix: reemitCurrentVote impl on Calendar/WiFi/Schedule/ExternalDisplay — S22 / P-issue-6d) — doc-sync commit forthcoming after this file lands. |

### Commit chain (S22 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S22 (P-issue-6d)                       (S22 #22)
0bf0b12        fix: reemitCurrentVote on Calendar/WiFi/Schedule/ExternalDisplay      (S22 #21) ← P-issue-6d
66f69aa        docs: SESSION_HANDOFF wrap for S22 (P-issue-6c)                       (S22 #20)
bc13880        fix: user-explicit deactivate skips snooze (re-enable wakes immediate) (S22 #19) ← P-issue-6c
7a67e23        docs: SESSION_HANDOFF wrap for S22 (P-issue-6b)                       (S22 #18)
55c2c78        fix: Turn off → trigger disable now reaches Settings UI               (S22 #17) ← P-issue-6b
6c46e2c        docs: SESSION_HANDOFF wrap for S22 (P-issue-6)                        (S22 #16)
d78fca3        feat: Turn off becomes "big red button" — disables all triggers       (S22 #15) ← P-issue-6
5b83eb9        docs: SESSION_HANDOFF wrap for S22 (P-issue-5b)                       (S22 #14)
c4703db        fix: pause-lift auto-recovery + Turn off caption                      (S22 #13) ← P-issue-5b
d1513bb        docs: SESSION_HANDOFF wrap for S22 (P-issue-5 + P-issue-4 deferral)   (S22 #12)
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
| P5 | `895947a`. Pause-all from `.awakeTriggered` painted misleading "Until X" caption (because `enterSnoozed` sets `endsAt + reason=.user`). Plus: `.snoozed` lockout held 5 min after pause OFF, with no auto-recovery for steady-state triggers. **Two-part fix**: (a) new `AwakeInput.constraintDeactivate` + helper that goes directly to `.asleep` clearing pendingVotes; (b) `triggersPaused` didSet posts `.latteTriggerPauseDidLift` on true→false transition; `TriggerCoordinator` subscribes and calls `reevaluateAll()` invoking `Trigger.reevaluateWatched()`. | +3 |
| P5b | `c4703db`. **P5 fix was incomplete on the trigger side.** Owner re-tested: pause OFF still didn't auto-recover, and Turn off pressed while AppTrigger was voting ON painted the same "Until X" caption. Two distinct root causes: (a) `reevaluateWatched()` short-circuits on watched-set no-diff (Settings UI dedup) so pause-lift never actually re-emitted; (b) HeaderView returned "Until X" whenever endsAt!=nil regardless of isAwake, so .snoozed (entered via Turn off → .userDeactivate from .awakeTriggered) painted the snooze deadline as if it were an awake deadline. Fix: new `Trigger.reemitCurrentVote()` protocol method (bypasses dedup); `AppTrigger.reemitCurrentVote()` impl; `TriggerCoordinator.reevaluateAll()` switched from `reevaluateWatched()` to `reemitCurrentVote()`. HeaderView gates every "Until …" branch on `isAwake == true`. | +2 |
| P6 | `d78fca3`. **Owner-requested UX redesign.** Even with the P5b caption fix, owner found the Turn-off-while-trigger-active behaviour confusing: trigger stayed enabled, 5 min later cup auto-recovered. Mental model: pause = temporary (auto-recover when conditions hold), Turn off = explicit termination (disable triggers, manual re-enable). Implementation: new `Notification.Name.latteUserExplicitDeactivate` posted by `AwakeManager` from `deactivate()` and `toggle()` on awake → not-awake transitions only. `TriggerCoordinator` subscribes (mirror of `.latteTriggerPauseDidLift`) and calls new `disableAll()` which flips `trigger.isEnabled = false` (persists to UserDefaults) + calls `stop(_:)` (halts emissions, emits OFF vote). Pause-all explicitly NOT affected — keeps the temporary-suspend semantic. Tests: golden path + pause-all-doesn't-disable regression guard + asleep-deactivate-no-op. | +3 |
| P6b | `55c2c78`. **P6 fix passed unit tests but didn't reach the live UI.** Owner reported the Triggers tab toggle still showed ON after Turn off. Two defects. (a) Observer registered with `queue: .main` defers the block to OperationQueue.main, which fires on the next run-loop iteration; the popover-dismiss + Settings-show transition can leak past the deferral. Switched both observers to `queue: nil` — block runs synchronously on the posting thread. Both posts are from @MainActor, so MainActor.assumeIsolated continues to hold. (b) `TriggerSection`'s `@State var isOn` initializes from `trigger.isEnabled` ONCE at view creation; programmatic UserDefaults writes don't refresh the local @State. Added `.onReceive` for `.latteUserExplicitDeactivate` that re-reads `trigger.isEnabled` into `isOn`. New integration test uses a real `AppTrigger` to verify `trigger.isEnabled = false` reaches the underlying `SettingsStore` — `MockTrigger` has its own non-persisted storage. | +1 |
| P6c | `bc13880`. **5.5 still failed: re-enabled trigger didn't wake.** Owner verified the Settings toggle correctly went OFF after Turn off (P6b confirmed), but re-enabling the trigger in Settings while the matching app was still running did not wake the cup. Root cause: `AwakeManager.deactivate()` dispatched `.userDeactivate`, which from `.awakeTriggered` ran `enterSnoozed(...)` and locked the manager in `.snoozed` for 5 min. The post-Turn-off `(.snoozed, .triggerVoteOn)` transition records the vote into the shadow set without changing state — vote ON had no effect during the snooze window. The snooze was originally a re-fire suppressor; with P6's `disableAll()` already disabling every enabled trigger on the same path, the snooze became dead weight that actively blocked the new design. Fix: `deactivate()` and `toggle()`-when-awake dispatch `.constraintDeactivate` instead, which goes directly to `.asleep`, clears pendingVotes, releases assertion. Two existing FSM tests (`test83_userSnoozesDuringCall_shadowSetPreserved`, `test85_userForceOffDuringCooling_goesSnoozed`) encoded the v1 snooze contract; revised to match post-P6c expectations. New regression test `testReenableTriggerAfterTurnOffWakesImmediatelyWhenConditionHolds` covers the owner-reported flow with a real AppTrigger. | +1 net |
| P6d | `0bf0b12`. **Owner-prompted parity audit: "이거 다른 trigger도 잘 되는지 확인해봐야하지 않아?"** P-issue-5b's pause-lift auto-recovery hook only worked for AppTrigger because it was the only concrete trigger overriding `Trigger.reemitCurrentVote()`; Calendar / WiFi / Schedule / ExternalDisplay all inherited the protocol's empty default and would silently fail to wake on pause OFF even with steady-state condition still holding. Implementation pattern (mirrors P5b's AppTrigger fix): clear the per-trigger dedup state and re-run the existing evaluate/poll function. Calendar `activeEventIDs = []`. WiFi `lastVote = nil`. Schedule `activeEntryID = nil`. ExternalDisplay `lastVote = nil`. Each then runs its existing pollOnce/evaluate so the current condition emits ON; OFF is suppressed for empty-condition (manager is asleep, redundant OFF would be noise). The Turn off path (P6/P6b/P6c) was already trigger-agnostic because the wake comes from the trigger's own `start()` `emitOn()` on re-enable; only the pause-lift path depended on `reemitCurrentVote`. | +2 |

### Patterns reinforced this session

- **Inter-layer contrast tests** (P-issue-1) — colour fixes vs. another rendered element need gap tests, not single-sided ceilings.
- **Mug-and-coffee mental model** (P-issue-1) — vessel body sits **between** contents and background brightness-wise.
- **Closed-shape vs open-curve perceptual asymmetry** (P-issue-2) — alpha-blended stroke reads stronger on bounded shapes than on free-floating curves; light-mode strokes default to solid alpha 1.0.
- **Floor-test against pure black** (P-issue-3) — accent palettes need a darkness floor (avg ≥ 0.25), not just upper bounds.
- **LSUIElement popover keybinding completeness ≠ keybinding functionality** (P-issue-4) — source-inspection during popover UX checklist prep can flag missing `.keyboardShortcut(...)` modifiers, but **only owner manual smoke can confirm they actually fire** in the NSStatusItem popover context. Source-inspection finds the omission; manual smoke confirms whether the proposed wiring actually works. **Both halves are required.**
- **Constraint-driven deactivate ≠ user-driven deactivate** (P-issue-5) — system-level forces (pause-all, AC unplug) must NOT inherit the user-deactivate FSM transition table, because the `.snoozed` path that follows `.userDeactivate` from `.awakeTriggered` paints a misleading "Until X" caption. New `AwakeInput.constraintDeactivate` is the canonical handler.
- **Constraint-lift hooks for stateless re-evaluation** (P-issue-5) — when a constraint that suppressed triggers is lifted, the coordinator must explicitly ask each trigger to re-emit. Steady-state conditions (Notion still running, calendar event still in progress) don't naturally re-fire — they're not transition-driven.
- **Two-layer dedup for trigger re-eval hooks** (P-issue-5b) — the same trigger needs two separate protocol methods: `reevaluateWatched()` is idempotent on watched-set no-diff (Settings UI list-edit path), `reemitCurrentVote()` bypasses the dedup and emits the current state (constraint-lift / coordinator-driven path). Conflating them breaks one of the two callers — exactly what P-issue-5 ship did before owner caught it on retest.
- **HeaderView captions must gate `isAwake` before reading `endsAt`** (P-issue-5b) — `endsAt` is published for both awake-deadline (`.awakeUserTimed`) AND not-awake-deadline (`.snoozed`, `.coolingDown`) states. The "Until X" phrasing is only correct for the awake-deadline subset. Same defect surfaced through the Turn-off → snoozed path even before pause-all was wired.
- **Two distinct off-paths for distinct mental models** (P-issue-6) — pause-all (temporary suspend, triggers stay enabled, auto-recover when conditions still hold) vs Turn off (explicit termination, triggers disabled, user re-enables in Settings). Conflating both into a single FSM transition forces a confused middle ground (the original `.userDeactivate → .snoozed` semantics that surfaced as "5 min later the cup comes back even though I said off"). Each path needs its own notification + observer wiring.
- **`isEnabled` setter as the persistence boundary for trigger state** (P-issue-6) — flipping `trigger.isEnabled = false` programmatically is equivalent to the user toggling it OFF in Settings: same UserDefaults key, same UI reflection. New code that needs to "kill" a trigger should use this rather than introducing a parallel disable mechanism.
- **NotificationCenter `queue: .main` is a deferral** (P-issue-6b) — even from the main thread, scheduling on OperationQueue.main runs the block on the next run-loop turn; UI navigation between post and observer can leak past it. Use `queue: nil` for "must run before any subsequent UI read" semantics, with `MainActor.assumeIsolated` for actor safety when posters are @MainActor.
- **`@State` initialized from a non-observable model is a stale-cache hazard** (P-issue-6b) — when programmatic writes to the underlying model bypass the SwiftUI binding (e.g. `trigger.isEnabled = false` from a coordinator), the @State retains the previous value until view re-creation. Add an `.onReceive` for the relevant change notification to re-sync.
- **Mock-backed tests can hide model-vs-store regressions** (P-issue-6b) — `MockTrigger` stores `isEnabled` as an instance property; `AppTrigger.isEnabled` setter persists through `SettingsStore`. Tests using only mocks pass even if the protocol-level write doesn't reach the store. Add at least one integration test using the production trigger type whenever the contract involves persistence.
- **Dead invariants from earlier-design fix-paths** (P-issue-6c) — when a redesign covers ground an earlier safeguard already covered, the safeguard becomes dead weight that can actively block the new design. P6's `disableAll()` covered the "prevent immediate re-fire" goal that the original snooze invariant existed for; the snooze remained but now actively suppressed legitimate re-enable wakes. Audit related FSM transitions when redesigning a scenario; remove invariants the new design has subsumed.
- **Protocol default ≠ trigger-agnostic feature** (P-issue-6d) — extending a protocol with a default empty impl makes the *call site* trigger-agnostic (TriggerCoordinator can call it generically) but the *behaviour* still has to be implemented per concrete type. P-issue-5b shipped with only AppTrigger overriding `reemitCurrentVote()`; the other 4 inherited the empty default and silently no-op'd. When shipping a feature whose contract requires non-default behaviour from every concrete impl, audit the inheritance map at fix time and either implement everywhere or document the partial coverage.
- **Sequential cascade in resumed manual smoke** — each owner-driven fix exposes the next layer (cup body → stroke → noir → popover keybinding → pause-all snooze caption → P5 trigger-side incomplete → P6 redesign → P6b observer-sync → P6c snooze invariant blocking re-enable → P6d cross-trigger parity gap). Owner manual smoke + owner-prompted parity audits continue to find what unit tests can't.

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
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 570 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 570/570 tests PASS in ~8.5s. Smoke 22/22 PASS in ~6:14.

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
