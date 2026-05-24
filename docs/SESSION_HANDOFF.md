# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S41 (2026-05-24) — iCloud-sync Phase 1 (ships dark) + full-suite flake fix (trap #8 closed)
**v1.x release line:** v1.9 (unchanged — S41 ships dark behind a kill-switch, no version bump, no owner-visible behaviour change)
**Branch:** `claude/focused-hamilton-417bfc` — ahead of `origin/main` by S36 + S37 + S38 + S39 + S40 + **S41**. Push = owner action; push the **branch tip**. *(Exact count: `git rev-list --count origin/main..HEAD` — a frozen integer here would be off-by-one after the wrap commits that write it.)*
**Test count:** 627/627 PASS (619 → 627: +7 CloudSync seam/wiring, +1 flake regression test)
**Smoke:** 23 scenarios (not re-run — S41 changes no runtime behaviour; sync is dark)
**Doc-drift:** clean (incl. Core SwiftUI-free + new CloudKit-isolation guard)
**Catalog:** 172 keys × 11 languages — unchanged
**Toolchain:** Xcode 26.5 / Swift 6.3.2
**trap #8 (full-suite flake):** **CLOSED this session** — see below.

---

## Last session (S41)

Owner asked for: a list of possible + remaining work, a recommended order, then
autonomous execution chunk-by-chunk with maximal verification, continuing until
context is well-used, then wrap. Recommended + executed order: **Step 0 baseline
→ iCloud Phase 1 (5 sub-chunks) → flake fix → RFC tidy → wrap.** All chunks
build + (filtered) test green before the next; full suite verified at the end.

### What landed (8 commits on `claude/focused-hamilton-417bfc`)

**Pre-req — `4fec07b` `fix(tests)`:** `@MainActor SettingsRootLayoutTests` clears
2 Swift-6 main-actor-autoclosure warnings. **Pre-existing since S40** — S40's
incremental build cached that file clean, so a fresh `xcodegen` re-surfaced them
(S40's "test target 0 warnings" was an incremental-cache artifact). Restores a
genuine zero-source-warning baseline.

**iCloud Phase 1 (docs/design/10 §11 row 1) — ships dark behind `LATTE_ICLOUD_SYNC`:**
- **`7937e39` 1a** — `CloudSyncEngine` protocol seam (pure @MainActor lifecycle:
  `isRunning`/`start`/`stop`) + `MockCloudSyncEngine`; 4 contract tests incl. the
  §8 unavailable-account no-op. In `Sources/Core`, mirrors SettingsStore/etc.
- **`bc8d8c1` 1b** — `AppEnvironment` gains injected `cloudSync: (any CloudSyncEngine)?`
  (nil default) + a `startCloudSyncIfNeeded()` boot hook called from
  `applicationDidFinishLaunching` after `bootTriggers`. Default build: nil →
  `cloudSync?.start()` no-op → behaviour unchanged. 3 wiring tests.
- **`19a979e` 1c** — `CloudKitSyncEngine` adapter skeleton wholly behind
  `#if LATTE_ICLOUD_SYNC` (default build never compiles/links CloudKit;
  account-availability gate only; container id `iCloud.com.parkbyeongjun.latte`
  lives here only) + a **CloudKit-isolation lint guard** in `check_doc_drift.sh`
  (§10: CKContainer/CKDatabase only in CloudKitSyncEngine.swift).
- **`e90110e` 1d** — stage **inactive** `Configuration/Latte.icloud.entitlements`
  (icloud-services=[CloudKit] + container-identifiers + network.client). NOT
  referenced by any build setting → default signing stays on Latte.entitlements
  (no CloudKit) → buildable pre-S8.5. project.yml documents the 2-step Phase 2
  activation.
- **`da5a755` 1e** — RFC §11 "Phase 1 landed dark in S41" note + README 619→626.

**Flake fix — trap #8 CLOSED (`1ae1eec`):** root cause confirmed by reading —
`TriggerCoordinator.start(_:)` keeps a long-lived `for await trigger.voteStream`
consumer task that strongly retains its trigger and is deliberately never
cancelled on `stop()` (S8b: cancelling breaks OFF→ON restart). **The
`isolated deinit` didn't cancel it either**, so a deallocated coordinator leaked
the task as suspended main-actor work; across the suite's hundreds of
coordinators these accumulated → the intermittent ~18s main-actor stall →
"Restarting after timeout" → TEST FAILED (no assertion). Fix: the `isolated
deinit` now cancels every consumer task — safe because the coordinator is already
being torn down (no live OFF→ON restart left to protect). RED→GREEN regression
test (`testDeinitReleasesConsumerTaskAndTrigger`: a weak-ref trigger is released
on coordinator dealloc — leaked pre-fix, released post-fix). README 626→627.

**RFC staleness tidy (`15e6dbd`):** RFC §3/§13 flagged 04-data-model §5's
SettingsKey snapshot as stale + deferred, but **S38 already refreshed it**
(+authoritative `allCases` pointer); marked resolved.

### Verification

- **Default build (flag off):** 0 warnings; CloudKit never compiled; `cloudSync`
  nil; app behaviour identical.
- **Flag-on build** (`SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LATTE_ICLOUD_SYNC'`):
  compiles the adapter + AppEnvironment `#if` branch clean under Swift 6 — closes
  the "dark code never compiled → rots" gap. (Don't `test` flag-on: the
  nil-by-default tests intentionally assert the dark path.)
- **Full suite: 627/627 PASS, and 10/10 green full runs post flake-fix** (was
  3/5 flake earlier this session). All 21 TriggerCoordinatorTests incl. OFF→ON
  restart stay green.
- **doc-drift --strict clean** (CloudKit-isolation guard passing; Core SwiftUI-free).

### S41 NEW patterns (5)

a. **A dark compile-time-gated feature is verifiable in BOTH states without its
   runtime gate** — default build proves "nothing changed"; a one-off flag-on
   `xcodebuild build` proves the `#if`-walled code still compiles (CloudKit
   *links* without the entitlement — that's sign/runtime, not compile).
b. **Stage an entitlement as an unreferenced file, not an active key** — adding
   CloudKit keys to the live entitlements breaks personal-signing pre-S8.5; a
   separate inactive `*.icloud.entitlements` + a documented 2-step switch keeps
   the default build green while the artifact is ready.
c. **A token-grep lint guard will catch its own documentation** — keep the literal
   CKContainer/CKDatabase tokens out of every file except the adapter (reword docs
   to "CloudKit's container/database APIs").
d. **An "intentionally never cancelled" task still needs deinit cancellation** —
   the S8b "don't cancel on stop()" rule protects the *live* restart path; it never
   implied "don't cancel when the owner object is destroyed" — that gap was trap #8.
e. **A fresh xcodegen/clean build is the honest warning audit** — incremental
   builds cache unchanged files clean and hide their warnings (S40 missed 2);
   regenerate before claiming a zero-warning baseline.

Cumulative NEW S20→S41 ≈ 72.

### What was NOT done (and why)

- **iCloud Phase 2/3/4** — S8.5-gated (live CloudKit needs the Apple Developer
  Program + a provisioned container). Phase 1's dark seam is the most that can
  land autonomously. Phase 2 = OQ-04 SwiftData migration for all
  `SettingsKey.allCases` + LWW resolver + chord value sync; Phase 3 = activity-log
  union merge (v2.1); Phase 4 = chord override polish + privacy re-answer.
- **Anything else autonomous** — the substantive unblocked backlog is exhausted
  at this boundary. The i18n queue is empty (S37 sweep). Remaining items are
  owner/Apple/tool-gated (below).

---

## Next-session entry points (priority order)

**1. (BLOCKER, owner-side) S8.5 Apple Developer Program** — gates S9 *and* every
iCloud phase ≥ 2 (live CloudKit). This is now the critical path: the autonomous
code backlog is essentially drained until S8.5 unblocks Phase 2.

**2. (BLOCKER, owner-side) S9 App Store Connect metadata** — depends on S8.5.

**3. (AUTONOMOUS, large — but S8.5-GATED) iCloud Phase 2.** On the clean Phase-1
seam. Scope (RFC §3, §6, §11 row 2): OQ-04 UserDefaults→SwiftData migration for
all `SettingsKey.allCases` (`schemaVersion` 1→2; UserDefaults kept read-only one
minor version) + per-record LWW resolver (pure fn, unit-testable) + B1.2 chord
value sync with per-device best-effort registration (§7). The pure LWW resolver
+ migration logic *could* be written CloudKit-free ahead of S8.5, but activation
(entitlement + container) needs S8.5 — confirm with owner before pre-building.
**Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md) §3/§6/§7/§11 first.**

**4. (AUTONOMOUS, optional) iCloud Phase 1 hardening, if a session wants more dark
work before S8.5:** the Phase-1 adapter's `start()` is account-gate-only; a
flag-on build is compile-verified but never *run*. No further autonomous value
until Phase 2 — don't gold-plate.

The autonomous-OPTIONAL i18n queue is empty and verified empty (S37 sweep).

---

## Cold-start (다음 세션 진입)

S31's one-command ritual still applies: `latte` (zsh alias) or
`bash ~/Documents/Claude/Projects/Latte/scripts/latte-resume.sh`.

```bash
# PRE-FLIGHT (MANDATORY) — kill stale Latte before any test/Cmd-R.
pkill -9 -f "Latte.app" 2>/dev/null; sleep 1

# A FRESH WORKTREE HAS NO .xcodeproj — generate it first:
xcodegen generate

# In a git worktree: edit + test the worktree path, NOT the repo root (S36 footgun).

# Tests (~10s, expect 627 PASS). The trap #8 flake is FIXED this session —
# 10/10 green post-fix. If a full run ever stalls again with no assertion text,
# it is a regression of trap #8 (check TriggerCoordinator deinit task-cancel).
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed"

# Default build clean (0 warnings, CloudKit-free):
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"

# Verify the dark iCloud code still COMPILES under the flag (won't run it):
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LATTE_ICLOUD_SYNC' 2>&1 | grep -E "warning:|BUILD"

# Doc drift (incl. Core SwiftUI-free + CloudKit-isolation guard):
scripts/check_doc_drift.sh --strict
```

**Expect**: 627/627 PASS; default + flag-on builds 0 warnings; doc-drift clean;
172 keys × 11 langs; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.37 → 1.41 for the iCloud-RFC → decision-lock →
   audit-stabilization → Swift-6 → **Phase-1-dark + flake-fix** lineage.
3. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)**
   before any iCloud work — §12 is the decision log; §3/§6/§7/§11 define Phase 2.
   §11 now carries the "Phase 1 landed dark in S41" status note.
4. Memory: `MEMORY.md` → `project_latte_v1_9.md` S20→S41 section; cross-cutting
   traps in `project_latte_status.md` (**trap #8 now marked CLOSED — S41**).
5. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S41 update)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8.5 | Apple Developer Program — applied 2026-05-02 | Apple wait. Now the critical path (gates Phase 2+). Check email + portal; if past the typical window, call Developer Support | 1-2 days typical |
| S9 | App Store Connect metadata + screenshots + binary submission | S8.5 depends | 1-3 sessions once unblocked |
| **Push branch** | **`claude/focused-hamilton-417bfc`** — now S36+S37+S38+S39+S40+**S41** (count via `git rev-list --count origin/main..HEAD`). Push the **branch tip**. | none — ready | seconds |
| iCloud RFC Q4 | Container-id `iCloud.com.parkbyeongjun.latte` — now hard-coded in the staged entitlement + adapter default; accept at Phase 2 kickoff (non-gating) | owner, non-gating | 1 answer |
| WiFi WhenInUse | Downgrade `requestAlwaysAuthorization` → `requestWhenInUseAuthorization` — needs a real Mac to confirm CoreWLAN `ssid()` still resolves | owner device smoke | 1 edit + 1 smoke |
| Smoke 23 re-run | S36–S41 changed no UI; no scenario delta expected | none | 7 min |
| Phase I community PRs | TRANSLATIONS.md; Russian is the worked reference | awaiting community | ongoing |

---

## v1.9 owner-visible behaviour reference (post-S41)

**No owner-visible behaviour change in S41.** iCloud sync ships **dark** behind
the `LATTE_ICLOUD_SYNC` compile-time kill-switch (off by default): `cloudSync` is
nil, no CloudKit code is compiled, the boot hook is a no-op. The flake fix is a
`deinit`-only task cancellation that runs after a coordinator is already gone —
invisible at runtime. The cup, menu bar, triggers, Settings, Activity, ⌘⇧L all
behave exactly as the S35/S40 reference.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` already implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S40. Pages live at https://spespark.github.io/latte/ + /privacy.html.
Cross-project helper `~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario
`.smoke/scenarios/00-bundle-integrity.sh` (S35).
