# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S43 (2026-05-24) — iCloud-sync **Phase 3 pure logic** pre-built dark (Domain B activity-log union merge, CloudKit-free)
**v1.x release line:** v1.9 (unchanged — S43 adds one inert pure type, no version bump, no owner-visible behaviour change)
**Branch:** `claude/focused-hamilton-417bfc` — ahead of `origin/main` by S36 + S37 + S38 + S39 + S40 + S41 + S42 + **S43**. Push = owner action; push the **branch tip**. *(Exact count: `git rev-list --count origin/main..HEAD`.)*
**Test count:** 676/676 PASS (658 → 676: +18 `ActivityLogMergeResolverTests`)
**Smoke:** 23 scenarios (not re-run — S43 adds no runtime behaviour; the new type is inert until activation)
**Doc-drift:** clean (Core SwiftUI-free + CloudKit-isolation both green)
**Catalog:** 172 keys × 11 languages — unchanged
**Toolchain:** Xcode 26.5 / Swift 6.3.2 (Swift 6 language mode)
**Deployment target:** macOS 13.0 — **held for free** this session (Phase 3 needs no `@Model`, so no macOS-14 cost — unlike Phase 2 activation)

---

## Last session (S43)

Owner reviewed the S42 handoff and chose **"Phase 3 선빌드 실행"** — the one remaining
autonomous, CloudKit-free path the RFC flagged "confirm with owner before starting"
(Phase 3 is v2.1 per §12 Q5, so pre-building ahead of v2.0 is a sequencing call).
Same cadence as S40/S41/S42: verify the handoff, baseline, execute, verify
maximally, wrap.

**Handoff verified against the repo before starting:** branch tip `a778a9c`, 36
commits ahead of `origin/main`, all four S42 SHAs present; the main working dir was
on the stale S35 `main` — worked in the worktree (`xcodegen generate` first, since a
fresh worktree has no `.xcodeproj`).

### What landed (1 commit on `claude/focused-hamilton-417bfc`)

One **inert pure value type in `Sources/Core`**, compiled + unit-tested in the
**default** build — **no `#if LATTE_ICLOUD_SYNC` gate** (it carries no CloudKit
symbols; CryptoKit is a system framework, not CloudKit, so the §10 lint guard stays
green). The `CloudKitSyncEngine` will *drive* it at activation.

- **`ActivityLogMergeResolver`** — the append-only **union** merge for the activity
  log, **Domain B** conflict resolution (§4 B-2/§6/§10). The structural counterpart
  to S42's `SettingsLWWResolver` (Domain A) — **never last-writer-wins** (§6: LWW on
  an event log silently destroys concurrent-day history when two Macs are awake the
  same day).
  - `contentAddressedID(for:)` — SHA-256 of the immutable tuple `(timestamp-micros,
    triggerId, kind, reasonCode, id)`; a 64-char lowercase-hex, valid
    `CKRecord.recordName` with no transform at activation. Includes the per-event id
    so it is collision-free for genuinely distinct events and identical for
    byte-identical duplicates (the dedup key).
  - `merge(_:)` / `merge(_:_:)` — union any number of device views, dedup by
    `contentAddressedID`, return a single canonical order (timestamp, then id) so the
    merge is **commutative, associative, idempotent** as plain array equality.
  - `pruned(_:now:retention:)` — mirrors `ActivityLogStore.gc` exactly (drop entries
    *strictly older* than `now − retention`, keep the boundary; default tracks
    `ActivityLogStore.defaultRetention` = 14 days), pure, `now` injected.
  - `mergedAndPruned(_:now:retention:)` — the full Domain B sync-in transform: union,
    then local GC on the merged set (§4 B-2).
  - 18 tests. **No `ActivityLogEntry` model change** — so, unlike Phase 2, **no
    macOS-14 / `@Model` cost; macOS 13 holds for free.**

### Verification

- **Default build:** `** BUILD SUCCEEDED **`, 0 source warnings; CloudKit never compiled.
- **Flag-on build** (`LATTE_ICLOUD_SYNC`): `** BUILD SUCCEEDED **`, adapter still clean under Swift 6.
- **Full suite: 676/676 PASS** (`** TEST SUCCEEDED **`). doc-drift --strict clean. Catalog 172 unchanged.
- *(Only build-log warnings are the pre-existing XCTest-dylib `ld` notes — test bundle
  targets macOS 13, Xcode 26 XCTest built for 14 — environmental, not source.)*

### ⚠ Trap #8 recurred (NOT this code) — reopened as "mitigated, not closed"

The **first** full `xcodebuild test` ended `** TEST FAILED **` with **0 assertion
failures and no signal** — the documented ~12% main-actor stall. The new suite passed
18/18 in isolation and the **immediate re-run was 676/676 green**. So the S41
`TriggerCoordinator` deinit-cancel fix *reduced* but did **not fully eliminate** the
stall. **Re-run-on-FAILED stays the mitigation.** trap #8 is downgraded from CLOSED to
**mitigated-not-closed** in `project_latte_status.md`; a real root-cause is still a
separate session (suspect remaining uncancelled async consumers / scheduling stall).
**Beware:** piping `xcodebuild test 2>&1 | grep …` reports *grep's* exit code, not
xcodebuild's — always read the `** TEST SUCCEEDED/FAILED **` line, not `$?` of the pipe.

### S43 NEW patterns (3)

a. **A CRDT-style union merge becomes pure-testable by returning a canonical
   (deduped + total-ordered) form** — sort the union by a stable key and
   commutativity / associativity / idempotency hold as ordinary array `==`, so the
   algebraic laws are plain `XCTAssertEqual`s, not bespoke set comparisons.
b. **Content-address over the *full* immutable tuple, not just the UUID** — including
   every field makes the id idempotent on true duplicates AND collision-free on
   genuine differences without trusting UUID assignment; a Codable round-trip test
   pins the id to the on-disk `secondsSince1970` format so sync dedup can't silently
   break.
c. **A "mitigated" flake is not a "closed" flake** — S41 marked trap #8 closed on
   10/10 green; it recurred on the first S43 full run. Treat intermittent stalls as
   mitigated-until-root-caused and keep the re-run-on-FAILED ritual.

Cumulative NEW S20→S43 ≈ 79.

### What was NOT done (and why)

- **All three iCloud phases' pure CloudKit-free logic is now pre-built** (Phase 1 seam
  S41; Phase 2 LWW/migration/chord S42; Phase 3 union merge S43). Everything that
  remains needs the **live CloudKit container behind the Apple Developer Program**:
  - **Phase 1 activation** — flip `LATTE_ICLOUD_SYNC` on, activate the staged
    entitlement.
  - **Phase 2 activation** — macOS-14 target bump + SwiftData `@Model` container +
    `ModelConfiguration.cloudKitDatabase = .private(...)` + wire the S42 resolvers +
    add the local-only `shortcutChordDeviceOverride` key.
  - **Phase 3 activation** — create the `activity-log` CloudKit custom zone; write
    each entry as a `CKRecord` named by `contentAddressedID`; feed downloaded records
    + the local JSON cache through `ActivityLogMergeResolver.mergedAndPruned` on
    sync-in; queue offline writes and flush on reconnect. (No macOS-14 bump needed.)

---

## Next-session entry points (priority order)

**1. (BLOCKER, owner-side) S8.5 Apple Developer Program** — the hard critical path.
The **autonomous code backlog is now genuinely exhausted**: all pure, CloudKit-free
logic for Phases 1/2/3 is pre-built and unit-tested. Nothing more lands until S8.5
unblocks the live container.

**2. (BLOCKER, owner-side) S9 App Store Connect metadata** — depends on S8.5.

**3. (AUTONOMOUS, optional, small) root-cause the trap #8 stall** — the only
non-Apple-gated work left, and it is *reliability*, not features. The S41 deinit-cancel
fix didn't fully close it (recurred S43). A dedicated session could instrument the
full-suite hang (suspect: remaining uncancelled async consumer Tasks / a scheduling
stall) and convert "re-run on FAILED" into a real fix. Read trap #8 in
`project_latte_status.md` first.

**4. (AUTONOMOUS, large — but S8.5-gated) any iCloud activation** — see "What was NOT
done". All three need the live container; Phase 2 additionally needs a macOS-14 bump.

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

# Tests (~10s, expect 676 PASS). trap #8 flake is MITIGATED, NOT CLOSED (recurred S43):
# a full run can still stall with NO assertion text + 0 failures → ** TEST FAILED **.
# That is trap #8, not your code — RE-RUN. Read the ** TEST SUCCEEDED/FAILED ** line,
# NOT the exit code of a `… | grep` pipe (that is grep's exit, not xcodebuild's).
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | tail -3

# Default build clean (0 source warnings, CloudKit-free):
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"

# Verify the dark iCloud code still COMPILES under the flag (won't run it):
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LATTE_ICLOUD_SYNC' 2>&1 | grep -E "warning:|BUILD"

# Doc drift (incl. Core SwiftUI-free + CloudKit-isolation guard):
scripts/check_doc_drift.sh --strict
```

**Expect**: 676/676 PASS; default + flag-on builds 0 source warnings; doc-drift
clean; 172 keys × 11 langs; macOS 13 target; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.37 → 1.43 for the iCloud-RFC → decision-lock →
   audit-stabilization → Swift-6 → Phase-1-dark+flake-fix → Phase-2-pure-logic →
   **Phase-3-pure-logic** lineage.
3. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)**
   before any iCloud work — §12 is the decision log; §11 carries the "Phase 1 landed
   dark in S41", "Phase 2 pure logic pre-built dark in S42", and "Phase 3 pure logic
   pre-built dark in S43" notes; §3/§4/§6/§7/§10 define the domains, policies, and
   test strategy.
4. Memory: `MEMORY.md` → `project_latte_v1_9.md` S20→S43 section; cross-cutting traps
   in `project_latte_status.md` (**trap #8 = mitigated-not-closed**, recurred S43).
5. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S43 update)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8.5 | Apple Developer Program — applied 2026-05-02 | Apple wait. **The critical path** (gates all iCloud activation; Phases 1/2/3 pure logic all pre-built). Check email + portal; if past the typical window, call Developer Support | 1-2 days typical |
| S9 | App Store Connect metadata + screenshots + binary submission | S8.5 depends | 1-3 sessions once unblocked |
| **Push branch** | **`claude/focused-hamilton-417bfc`** — now S36…+**S43** (count via `git rev-list --count origin/main..HEAD`). Push the **branch tip**. | none — ready | seconds |
| macOS-14 bump | **Phase 2 activation only** needs the deployment target raised to macOS 14 for SwiftData `@Model` (drops macOS 13 Macs; affects S9 min-OS). **Phase 3 needs no bump.** | owner product decision | 1 answer |
| iCloud RFC Q4 | Container-id `iCloud.com.parkbyeongjun.latte` — accept at activation (non-gating; hard-coded in the adapter + staged entitlement) | owner, non-gating | 1 answer |
| WiFi WhenInUse | Downgrade `requestAlwaysAuthorization` → `requestWhenInUseAuthorization` — needs a real Mac to confirm CoreWLAN `ssid()` still resolves | owner device smoke | 1 edit + 1 smoke |
| Smoke 23 re-run | S36–S43 changed no UI; no scenario delta expected | none | 7 min |
| Phase I community PRs | TRANSLATIONS.md; Russian is the worked reference | awaiting community | ongoing |

---

## v1.9 owner-visible behaviour reference (post-S43)

**No owner-visible behaviour change in S43.** `ActivityLogMergeResolver` is an inert
pure value type that nothing calls yet — it exists so the S8.5-gated Phase 3 activation
can drive it. `cloudSync` is still nil, no CloudKit is compiled, the boot hook is a
no-op. The cup, menu bar, triggers, Settings, Activity, ⌘⇧L all behave exactly as the
S35/S40/S41/S42 reference.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` already implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S42. Pages live at https://spespark.github.io/latte/ + /privacy.html.
Cross-project helper `~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario
`.smoke/scenarios/00-bundle-integrity.sh` (S35).
