# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S16** — same-day continuation of S15 (2026-05-01). V2-06 deferred I + G + H + C-3 deferred E + 9th simplify-pass. |
| **Theme** | "Polish the External Display trigger (V2-06) by working through all 3 deferred items in `06-display-trigger.md` + close out the last C-3 deferred item (E multi-day comparison)." |
| **Status** | ✅ **4 feat commits + 1 simplify-pass commit + 1 doc commit this session.** **468 → 485 tests** (+17). **Smoke unchanged at 22 scenarios** (new flows are owner manual smoke step 7 territory). Working tree clean. Test run ~7.5 s. |
| **Tail commit** | (post doc-sync commit forthcoming after this file lands) |

### Commit chain (S16 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S16 (V2-06 + C-3 E)        (S16 #6)
b7a7c72        chore: 9th simplify-pass follow-through (S16)             (S16 #5)
4e3c548        feat: daily totals chart for multi-day comparison (E)     (S16 #4)
0dfdf73        feat: per-display whitelist UUID-based (V2-06 H)          (S16 #3)
6495697        feat: clamshell-aware reason for ExternalDisplay (V2-06 G) (S16 #2)
dc13407        feat: NSScreenSource debounce (V2-06 I)                   (S16 #1)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `dc13407` | **I — NSScreenSource debounce**. New `DebouncingDisplaySource` decorator collapses bursts of `didChangeScreenParametersNotification` into one yield per 300ms window. Seq-counter pattern (each `scheduleFlush` bumps `pendingSeq` + captures it; in-flight Task yields only if its captured seq still equals `pendingSeq` at flush time) avoids the cancel-and-create race of the initial implementation. NSScreenSource wrapped by default in production; tests inject `MockDisplaySource` raw. | +3 |
| 2 | `6495697` | **G — Clamshell-aware reason**. DisplaySource gains `isInClamshellMode: Bool`, derived from NSScreen.screens (external present, built-in absent = lid closed). Vote reason becomes `"Display: Studio Display (clamshell)"` when in clamshell mode. Vote semantics unchanged — both lid states still vote awake; the tag refines what owner sees in About → Status / Activity → Currently active. | +2 |
| 3 | `0dfdf73` | **H — Per-display whitelist (UUID-based)**. New `DisplayInfo` value type (uuid + name) + `attachedExternalDisplays: [DisplayInfo]` on the protocol. NSScreenSource derives stable UUIDs via `CGDisplayCreateUUIDFromDisplayID` + `CFUUIDCreateString`. New `SettingsKey.externalDisplayWhitelist` JSON-encodes the UUID list. Trigger filter (`resolveVoteState`): empty whitelist → match any external (v1.2 preserved), non-empty → narrow to listed UUIDs. Settings → Triggers → External Display gains a "Match only these displays" toggle list. `setWhitelistedUUIDs` persists + re-evaluates so the vote flips on the spot. | +4 |
| 4 | `4e3c548` | **E — Multi-day comparison chart**. New `DailyTotalsChart` Section in ActivityTab — bar chart of total awake minutes per day across the retention window. Today's bar darkened so the eye reads day-over-day pattern without a separate overlay. `DailyTotal.compute` reuses `AwakeSegment.pair → merge → split` so parallel triggers don't double-count. Layout: dayOffset = 0 is the rightmost (most recent) bar. Bar count auto-sizes to retention (1d → 1 bar; 90d → 90 bars with auto-stride x-axis). | +5 |
| 5 | `b7a7c72` | **9th simplify-pass on S16 commits 1-4**. APPROVE-WITH-NITS (0 CRIT, 1 HIGH, 2 MED, 3 LOW). HIGH-1: regression test — when `attachedExternalDisplays` carries a name and `firstExternalDisplayName` is nil, the attached-list name must drive the reason; documents priority order so a future change can't silently flip it. MED-2: `SettingsStore.encodeStringArray([], for:)` now `remove(key)` instead of writing `[]` blob; preserves "absent == default / never touched" invariant a future migration may rely on. **Cross-cutting fix** — applies to all `[String]` settings, not just whitelist. MED-3: `DailyTotal.compute` switched window-start anchor to `Calendar.date(byAdding: .day)` (DST-correct). LOW-6: debouncer proxy test extended to cover the 2 new pass-through fields. | +3 |
| 6 | this commit | **Doc sync**: ROADMAP row 15 (S16) prepended; v2-backlog "Shipped in v1.5 (S16)" entry + "V2-06 still-deferred" subsection; 06-display-trigger.md "As shipped — v1.5" §; 09-c3 §13 noting E shipped. Memory: NEW `project_latte_v1_5.md`; `MEMORY.md` index 8 → 9 lines. SESSION_HANDOFF rewritten. | 0 |

### Patterns reaffirmed this session

- **Simplify-pass cadence is now 9 passes deep** (S10/S10.1/S11/S11/S12/S13/S14/S15/S16). All APPROVE or APPROVE-WITH-NITS. **Standing ritual after each batch of feature commits**: code-reviewer agent ~3 min + follow-through commit ~10 min.
- **Seq-counter for debounce/coalesce in actor-isolated code**: avoids the cancel-and-create race when cancelling Tasks during their `Task.sleep`. Cancelled tasks finished partial work before the cancellation propagated, producing off-by-one yields. Pattern to copy when next debouncer is needed.
- **AsyncStream iterator phantom-count gotcha**: `it.next()` returns nil exactly once when the consuming Task is cancelled mid-await. Tests counting yields must check the result, not blindly increment after `await`. Easy off-by-one trap.
- **Cross-cutting hygiene wins double**: MED-2's `encodeStringArray` empty-clear applied to all `[String]` keys, not just whitelist. One simplify-pass nit fixed a class of future migration risk.
- **Clamshell detection without IOPMrootDomain**: NSScreen.screens excludes built-in when lid closed. `hasExternal && !hasBuiltIn` is exactly the clamshell condition without needing the Power Management entitlement / private API. Cleaner + testable than the spec's IOPMrootDomain suggestion.
- **CGDisplay UUID for stable per-display identity**: `CGDisplayCreateUUIDFromDisplayID` + `CFUUIDCreateString`. Survives reboots and reorders. The whitelist UI surfaces the *name* but persists the UUID so a renamed monitor doesn't break the filter.

---

## Next-session entry points (priority order)

1. **Owner UI smoke 8-step** — steps 6 + 7 + 8 still pending. **Step 7 expanded for v1.5**: enable External Display trigger → attach external monitor → close lid (clamshell) → verify reason reads `"Display: <name> (clamshell)"` → open Settings → Triggers → External Display → toggle "Match only these displays" entries → verify vote flips. **Step 8 (v1.3.1)**: filter + export + click-row + retention stepper still need owner verification. Smoke 22 covers file-format only.
2. **Owner-blocked S8d** (~5 min Pages deploy: pick 5-7 PNGs / `deploy_pages.sh <url>` / Settings → Pages 1-click / curl validate). PNG candidate set is now **richest yet** — Activity tab has 3 charts (24h bar, 14d heatmap, daily totals) + filter + export + retention; Triggers tab has whitelist UI; About tab shows clamshell-tagged reasons.
3. **Owner-blocked S8.5** ($99/yr Apple Dev Program enrollment, 1-2 days approval).
4. **Owner-blocked S9** (App Store Connect metadata; depends on 8.5).
5. **C-7 Quick presets path decision** (08-spec is decision-ready — pick path A/B/C and proceed). **Top design candidate for v1.6.**
6. **B1.2 deferred refinements** (small scope; spec needs re-read first).
7. **C-3 still-deferred**: live polling refresh, iCloud sync, user-customisable Charts colours.
8. **V2-06 still-deferred** (no further v1.x scope): lid-closed-only mode, per-display position requirement.
9. **V2-22 GitHub remote** — repo push, CI execution, gh-pages branch enable. Owner action.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -13
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 485 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 485/485 tests PASS in ~7.5 s. Smoke 22/22 PASS in ~5 min.

**Note**: S16 hit a `LaunchServices Could not launch LatteTests` once — cleared by `pkill -9 -f "Latte.app"`. Cold-start ritual still mandatory.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 15 (S16) for full context if needed.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (9-line index) → drill into `project_latte_v1_5.md` for S16 detail; v1.3.1 (S15) lives in `project_latte_v1_3_1.md`; v1.3 (S14) in `project_latte_v1_3.md`.
4. **Don't** re-read S1-S11 memory entries — consolidated into `project_latte_v1_0.md` + `project_latte_v1_1.md` + `project_latte_v1_2.md` during S13.

---

## Owner-side pending (richer PNG set after S16)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5-9 marketing PNGs + `deploy_pages.sh` + Pages 1-click + curl validate. **Activity tab now has 3 charts** (24h, 14d heatmap, daily totals) + filter + export + retention. **Triggers tab now has whitelist UI**. About → Status shows `(clamshell)` tag when applicable. | Owner clicks only | ~5 min |
| S8.5 | Apple Developer Program 가입 | Account/payment owner-only | $99/yr + 1-2 days approval |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | varies |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10 min |

---

## V2-06 v1.5 owner-visible behavior reference (for step 7 smoke)

```
Settings → Triggers → External Display
  ├─ (description text)
  ├─ Currently: 1 external display
  ├─ Display: Studio Display
  ├─ ──────
  ├─ Match only these displays                  ← NEW (H)
  │  ├─ ☑ DELL U2723QE
  │  └─ ☐ Studio Display
  └─ "No filter — any external display awakes Latte." (when nothing checked)

Vote reason (About → Status, Activity → Currently active):
  Lid open + external attached:    "Display: Studio Display"
  Lid closed + external attached:  "Display: Studio Display (clamshell)"  ← NEW (G)
  Whitelist filtered out:          (no vote, "Display: disconnected" on transition)

Spec: docs/design/06-display-trigger.md (§"As shipped — v1.5")
```

## C-3 v1.5 update (E only — B/C/D/F still as in v1.3.1)

```
Settings → Activity → "Daily totals" Section                 ← NEW (E)
  └─ [bar chart, today highlighted, 1..N days based on retention]

Spec: docs/design/09-c3-activity-history.md §13
```
