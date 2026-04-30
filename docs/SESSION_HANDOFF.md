# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S14** — same-day continuation of S13 (2026-04-30). C-3 Activity history shipped: design doc + ActivityLogStore actor + ActivityTab Charts UI + 7th simplify-pass + smoke 22. |
| **Theme** | Phase 1 (design): owner-approved 4 decisions in 09-c3-activity-history.md (actor + JSON file persistence, dual-site hook in TriggerCoordinator, 4th Settings tab + Charts 24h+14d, raw reason text never persisted). Phase 2 (RED → GREEN): Part 1 store + hooks + 12 tests, Part 2 UI + AppEnvironment wiring + URL handler + ms timestamp quantise. Phase 3 (7th simplify-pass): APPROVE-WITH-NITS → 4 fixes + AwakeSegment.merge regression. Phase 4 (smoke + handoff): scenario 22 lazy-load contract + tab capture + privacy schema assertion. |
| **Status** | ✅ **4 코드 commits + 1 doc commit this session.** **426 → 442 tests** (+16 across the 4 commits). **Smoke 21 → 22 scenarios PASS**. Working tree clean. Test run ~6.7 s. Smoke run ~5 min. |
| **Tail commit** | (post doc-sync commit forthcoming after this file lands) |

### Commit chain (S14 only — top is HEAD)

```
(this commit)  docs: SESSION_HANDOFF wrap for S14 (C-3 Activity history)  (S14 #5)
7bfa1b7        test: smoke scenario 22 — activity-log lazy-load + Activity tab capture  (S14 #4)
6ef4e45        chore: 7th simplify-pass follow-through (C-3)               (S14 #3)
c4dac06        feat: ActivityTab UI + AppEnvironment wiring + microsecond timestamp quantise (C-3 part 2)  (S14 #2)
e4a401c        feat: ActivityLogStore + TriggerCoordinator hooks (C-3 part 1)  (S14 #1)
```

### What landed

| # | Commit | Scope | Tests Δ |
|---|---|---|---|
| 1 | `e4a401c` | **C-3 Part 1 — store + hooks**. New `ActivityLogEntry` Codable struct (id/timestamp/triggerId/kind/reasonCode). New `ActivityLogStore` actor: lazy-load on first append/snapshot, atomic JSON write, 14-day ring buffer GC, corrupt-/missing-file safe. New `LatteLog.activity` logger. `TriggerCoordinator` gains optional `activityStore: ActivityLogStore?` injection (nil-default for unit tests) + hooks at `handleVote` (organic vote ON/OFF) and `stop(_:)` (user-explicit OFF, distinct `reasonCode: .userToggleOff`). Privacy enforced by schema — raw `TriggerVote.reason` strings never cross into the log. | +12 |
| 2 | `c4dac06` | **C-3 Part 2 — UI + wiring**. New `SettingsTab.activity` 4th case + `latte://settings/activity` deep link. New `ActivityTab.swift` (Charts: 24h stacked bar by trigger + 14d heatmap + Currently active list, macOS 13 compatible — manual `VStack` empty-state instead of `ContentUnavailableView`). `AppEnvironment` instantiates real store from `ApplicationSupportDirectory/Latte/`, nil-safe on failure. **Microsecond timestamp quantise** in `ActivityLogEntry.init` so `secondsSince1970` Double round-trip preserves equality (ISO8601 truncates ns precision). | +1 |
| 3 | `6ef4e45` | **7th simplify-pass on S14 commits 1+2**. APPROVE-WITH-NITS (0 CRIT/HIGH, 2 MED, 2 LOW). All addressed: MED-1 `triggerDomain` `"externalDisplay"` → `"external-display"` (matches ExternalDisplayTrigger.id, was rendering wrong colour); MED-2 `DailyHeatmapChart.compute` was mis-pairing cross-trigger ON/OFF events — now pairs per-trigger then unions via new `AwakeSegment.merge` (3 regression tests); LOW-1 `stoppedByCoordinator` doc-comment marks it reserved for a future code path; LOW-2 `defaultDirectory()` `catch` now logs via `LatteLog.activity.fault` before returning nil. | +3 |
| 4 | `7bfa1b7` | **Smoke scenario 22**. `22-activity-log.sh` mirrors 21 shape: verifies activity-log.json absence on fresh launch (lazy-load contract holds), opens Settings → Activity tab via `latte://settings/activity` deep link, captures window for owner review, asserts schema privacy contract via `jq` if any entry happened to be written during the run. Bash cannot deterministically force trigger fire → owner manual smoke step 8 covers the "real fire → entry recorded" flow. | 0 |
| 5 | this commit | **Doc sync**: ROADMAP row 13 (S14) appended; v2-backlog "Shipped in v1.3 (S14)" entry added (privacy contract + spec link); 09-c3-activity-history.md §11 "As shipped" filled with deviations and MED-bug changelog; this file rewritten. | 0 |

### Patterns reaffirmed this session

- **Simplify-pass cadence is now 7 passes deep** (S10/S10.1/S11/S11/S12/S13/S14). All APPROVE or APPROVE-WITH-NITS — never architectural concerns, only hygiene. **Standing ritual after each batch of feature commits**: code-reviewer agent ~5 min + follow-through commit ~10 min.
- **xcodegen auto-discovery still works** — 3 new Swift files (`ActivityLogEntry.swift`, `ActivityLogStore.swift`, `ActivityTab.swift`) added without project.yml change.
- **Spec amendments via §11 "as shipped"**: pattern continues from V2-06 (S11), B1.2 (S12+S13), now C-3 (S14). Next reader sees plan vs reality side-by-side.
- **TDD-RED via stub bodies**: write minimal `@Sendable struct` + actor method signatures with empty bodies first, write tests against them (compile OK, tests fail), then GREEN by filling in. Worked clean — RED 19 failures → GREEN 1 failure (timestamp precision) → fix → 0 failures.
- **Privacy contract is enforceable in code**: ActivityLogEntry schema has zero free-text fields; new test `testJSONEncodingHasOnlyAllowedKeys` is a permanent regression gate. Future refactor that accidentally adds an "appName" or "ssid" field fails the test.

---

## Next-session entry points (priority order)

1. **Owner UI smoke 8-step** — steps 6 + 7 + **NEW step 8** for B1.2 + V2-06 + C-3. **C-3 step 8 변형**: enable WiFi trigger with current SSID → toggle Wi-Fi off (system pref) → toggle on → wait 5s → open Settings → Activity tab → verify entries appear with correct kind + currentmessage trigger color. (Smoke 22 covers file-format only; this verifies the user-visible Charts render.)
2. **Owner-blocked S8d** (~5분 Pages deploy: pick 5 PNGs / `deploy_pages.sh <url>` / Settings → Pages 1-click / curl validate). **PNG candidate set may now expand to 6** — Activity tab Charts is a strong marketing visual once owner has ~3 days of accumulated data. Re-evaluate after step 8 above.
3. **Owner-blocked S8.5** ($99/yr Apple Dev Program enrollment, 1-2일 승인).
4. **C-7 Quick presets path 결정** — A/B/C/D 비교 doc은 `docs/design/08-c7-quick-presets-paths.md`에 decision-ready로 준비됨. Owner pick → 즉시 RED-GREEN.
5. **B1.2 deferred refinements**: per-action chords (Pause-all, snooze 따로 chord 할당), reserved-by-other-app indicator (macOS 미enumerate, defer).
6. **V2-06 deferred refinements**: clamshell-aware lid detection, per-display whitelist (UUID 기반), NSScreenSource debounce.
7. **C-3 deferred refinements**: per-trigger filter UI, CSV/JSON export, click-row → jump to trigger config, multi-day comparison view, user-customisable retention window. All §10 in 09-c3 spec.
8. **V2-22 GitHub remote** — repo push, CI 실제 실행, gh-pages branch enable. Owner action.

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -13
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 442 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL 후 — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: 442/442 tests PASS in ~7 s. Smoke 22/22 PASS in ~5 min.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 13 (S14) for full context if needed.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (6-line index) → drill into `project_latte_v1_2.md` for S13 detail; S14 entry will be appended in next consolidation pass.
4. **Don't** re-read S1-S11 memory entries — they were consolidated into `project_latte_v1_0.md` + `project_latte_v1_1.md` + `project_latte_v1_2.md` during S13.

---

## Owner-side pending (unchanged from S13)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8d | 5 marketing PNG 선택 + `deploy_pages.sh` + Pages 1-click + curl validate. **NOTE**: Activity tab Charts is now a candidate (after ~3 days of usage). | Owner clicks only | ~5분 |
| S8.5 | Apple Developer Program 가입 | Account/payment owner-only | $99/yr + 1-2일 승인 |
| S9 | App Store Connect 메타 입력 | S8.5 의존 | 변동 |
| V2-22 | GitHub repo push + Pages enable | repo URL + auth owner-only | ~10분 |

---

## C-3 owner-visible behavior reference (for step 8 smoke)

```
Settings → Activity (4th tab)
  ├─ Last 24 hours      [stacked bar, color per trigger]
  ├─ Last 14 days       [heatmap, days × hours]
  └─ Currently active   [list — reads coordinator.activeVotes in-memory]

File: ~/Library/Application Support/Latte/activity-log.json
  ├─ Created on first append (lazy)
  ├─ 14-day ring buffer (GC on append)
  ├─ Schema: [id, kind, reasonCode, timestamp, triggerId] only — NO free text
  └─ jq-friendly: jq '.[0]' < activity-log.json

Hook sites (TriggerCoordinator):
  ├─ handleVote(_:from:)    — organic ON / OFF (.voteOn / .voteOff)
  └─ stop(_:)               — user-explicit OFF (.userToggleOff)

Spec: docs/design/09-c3-activity-history.md (§1-§11)
```
