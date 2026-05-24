# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S42 (2026-05-24) — iCloud-sync Phase 2 **pure logic** pre-built dark (CloudKit-free)
**v1.x release line:** v1.9 (unchanged — S42 adds inert pure types, no version bump, no owner-visible behaviour change)
**Branch:** `claude/focused-hamilton-417bfc` — ahead of `origin/main` by S36 + S37 + S38 + S39 + S40 + S41 + **S42**. Push = owner action; push the **branch tip**. *(Exact count: `git rev-list --count origin/main..HEAD`.)*
**Test count:** 658/658 PASS (627 → 658: +10 LWW resolver, +15 migration snapshot, +6 chord sync-in)
**Smoke:** 23 scenarios (not re-run — S42 adds no runtime behaviour; all new types are inert until activation)
**Doc-drift:** clean (Core SwiftUI-free + CloudKit-isolation both green)
**Catalog:** 172 keys × 11 languages — unchanged
**Toolchain:** Xcode 26.5 / Swift 6.3.2 (Swift 6 language mode)
**Deployment target:** macOS 13.0 — **deliberately held** this session (see below)

---

## Last session (S42)

Same cadence as S40/S41: verify the handoff, list possible + remaining work,
recommend an order, execute autonomously chunk-by-chunk with maximal
verification, continue until context is well-used, then wrap.

**Boundary:** the unblocked autonomous backlog was declared exhausted at S41
(Phase 2+ is S8.5-gated). The one autonomous path the RFC flagged "confirm with
owner" was the **CloudKit-free pre-build of Phase 2's risk-bearing pure logic**
(§10). Owner **confirmed** it, and **confirmed holding the macOS 13 target**
(pure Codable snapshot instead of a SwiftData `@Model`, which forces macOS 14 and
drops macOS 13 Macs — surfaced as a product decision, not made silently).

### What landed (3 commits on `claude/focused-hamilton-417bfc`)

All three are **inert pure value types in `Sources/Core`**, compiled + unit-tested
in the **default** build — **no `#if LATTE_ICLOUD_SYNC` gate needed** (they carry
no CloudKit symbols, so the §10 lint guard still passes and there's no
"never-compiled dark code rots" gap). The `CloudKitSyncEngine` will *drive* them
at activation.

- **`d3945b3` Chunk 1 — `SettingsLWWResolver`** (Domain A only, §6/§10): pure
  generic per-record last-writer-wins. Strictly-later remote wins; exact tie keeps
  local (§3 conservative, re-toggle-recoverable). Generic over the
  Bool/Int/Double/String/Data trichotomy. Named + scoped so the §6 invariant is
  structural — **the activity log (Domain B) never reaches LWW** (that is Phase 3's
  append-only union merge). 10 tests.
- **`b8b8cfc` Chunk 2 — `SettingsMigration`** (OQ-04, §3/§10): pure
  `snapshot(from:now:)` enumerates every *present* `SettingsKey` via a
  **compiler-enforced exhaustive `SettingsKey.valueType`** (34 cases — an
  unclassified new key fails the build = drift guard) into a Codable
  `SettingsSnapshot` stamped `schemaVersion=2`; absent keys stay absent;
  `schemaVersion` rides the top-level field, not a copied entry. Modelled as
  **plain Codable, not `@Model`** → holds the **macOS 13** target. Adds
  `SettingsStore.exists(_:)` (protocol + both conformers). **Correctness finding:**
  `needsMigration` defaults an absent `schemaVersion` to **1** because shipped
  v1.x **never wrote it** — the §2.2 "absent → fresh, skip" assumption would have
  skipped migrating every real upgrading user; corrected + documented. 15 tests
  incl. full-`allCases` parity (§10) + JSON round-trip.
- **`fcc1b14` Chunk 3 — `ChordSyncResolver`** (§7): pure `@MainActor` device-physical
  half of chord sync. A local (non-synced) override wins locally; a failed
  registration **keeps the synced value (never clobbers it)** + reports
  `showsDisabledCue` (the shipped 07-spec-J disabled cue, S17); **persists nothing**
  → structurally cannot rewrite the synced value. 6 tests with a failable
  `MockHotKeyRegistrar`. The local-only `shortcutChordDeviceOverride` key + its
  migration-exclusion are deferred to activation.

### Verification

- **Default build:** 0 source warnings; CloudKit never compiled; behaviour identical.
- **Flag-on build** (`LATTE_ICLOUD_SYNC`): adapter still compiles clean under Swift 6.
- **Full suite: 658/658 PASS.** doc-drift --strict clean. Catalog 172 unchanged.
- *(The only build-log warnings are the pre-existing XCTest-dylib `ld` notes — test
  bundle targets macOS 13, Xcode 26 XCTest built for 14 — environmental, not source.)*

### S42 NEW patterns (4)

a. **Pre-build a gated feature's risk-bearing logic as inert pure value types in
   the *default* build, not behind the `#if`** — they compile + unit-test with no
   flag-on step and carry none of the gated framework's symbols, so the lint guard
   stays green and the "dark code never compiled → rots" gap never opens.
b. **A compiler-enforced exhaustive `switch` over an enum is a free drift guard** —
   classifying every `SettingsKey` by storage type means a future un-classified key
   fails the build, stronger than any hand-maintained doc list.
c. **A migration "fresh vs existing" probe must match what the *shipped* app
   actually wrote, not the design doc** — v1.x never wrote `schemaVersion`, so
   "absent = fresh" would skip all real upgrades; default the absent value to the
   current version instead.
d. **When "pure logic pre-build" hides a platform-version cost (SwiftData ⇒
   macOS 14), surface it as a product decision** — model the transform as plain
   Codable to hold the deployment floor; defer the `@Model` write to activation.

Cumulative NEW S20→S42 ≈ 76.

### What was NOT done (and why)

- **Phase 2 activation** — S8.5-gated AND needs a macOS-14 target bump: introduce
  the SwiftData `@Model` container, drive the snapshot into it, set
  `ModelConfiguration.cloudKitDatabase = .private(...)`, wire the three resolvers
  into `CloudKitSyncEngine`, add the local-only `shortcutChordDeviceOverride` key
  (excluded from `SettingsMigration`). The pure logic this session is the most that
  lands without the live container.
- **Phase 3 (Domain B activity-log union merge, v2.1)** — independent; its merge
  *is* a pure function (§4 B-2/§10) and **could be the next CloudKit-free pre-build**
  if the owner wants more dark work. Confirm first (same gate as this session).

---

## Next-session entry points (priority order)

**1. (BLOCKER, owner-side) S8.5 Apple Developer Program** — now the hard critical
path. Gates S9 *and* every iCloud activation (Phase 2 live wiring, Phase 3). The
autonomous code backlog for Phase 2 is fully pre-built; nothing more lands until
S8.5 unblocks the live container.

**2. (BLOCKER, owner-side) S9 App Store Connect metadata** — depends on S8.5.

**3. (AUTONOMOUS, optional, CloudKit-free) Phase 3 union-merge pre-build** — the
only remaining autonomous sliver. Domain B append-only union merge is a pure
function over `[ActivityLogEntry]` (commutativity / associativity / idempotency /
GC-after-merge / content-addressed-id collision-freeness — §4 B-2, §10). Same
shape as this session's work. **Confirm with owner before starting** (Phase 3 is
v2.1 per §12 Q5, so pre-building ahead of v2.0 is a sequencing call).
**Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md) §4/§6/§10 first.**

**4. (AUTONOMOUS, large — but S8.5 + macOS-14-gated) Phase 2 activation** — see
"What was NOT done". Needs the live container and a deployment-target bump.

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

# Tests (~10s, expect 658 PASS). trap #8 flake FIXED in S41 (10/10 green). If a
# full run ever stalls again with no assertion text, it is a regression of trap #8
# (check TriggerCoordinator deinit task-cancel).
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed"

# Default build clean (0 source warnings, CloudKit-free):
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"

# Verify the dark iCloud code still COMPILES under the flag (won't run it):
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LATTE_ICLOUD_SYNC' 2>&1 | grep -E "warning:|BUILD"

# Doc drift (incl. Core SwiftUI-free + CloudKit-isolation guard):
scripts/check_doc_drift.sh --strict
```

**Expect**: 658/658 PASS; default + flag-on builds 0 source warnings; doc-drift
clean; 172 keys × 11 langs; macOS 13 target; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.37 → 1.42 for the iCloud-RFC → decision-lock →
   audit-stabilization → Swift-6 → Phase-1-dark+flake-fix → **Phase-2-pure-logic** lineage.
3. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)**
   before any iCloud work — §12 is the decision log; §11 carries both the
   "Phase 1 landed dark in S41" and "Phase 2 pure logic pre-built dark in S42" notes;
   §3/§4/§6/§7/§10 define the domains, policies, and test strategy.
4. Memory: `MEMORY.md` → `project_latte_v1_9.md` S20→S42 section; cross-cutting
   traps in `project_latte_status.md` (trap #8 marked CLOSED — S41).
5. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S42 update)

| # | What | Why blocked | Effort |
|---|---|---|---|
| S8.5 | Apple Developer Program — applied 2026-05-02 | Apple wait. **The critical path** (gates all iCloud activation; Phase 2 logic is fully pre-built). Check email + portal; if past the typical window, call Developer Support | 1-2 days typical |
| S9 | App Store Connect metadata + screenshots + binary submission | S8.5 depends | 1-3 sessions once unblocked |
| **Push branch** | **`claude/focused-hamilton-417bfc`** — now S36…+**S42** (count via `git rev-list --count origin/main..HEAD`). Push the **branch tip**. | none — ready | seconds |
| macOS-14 bump | Phase 2 *activation* needs the deployment target raised to macOS 14 for SwiftData `@Model` — a product call (drops macOS 13 Macs; affects S9 min-OS). Pure logic this session held macOS 13. | owner product decision | 1 answer |
| iCloud RFC Q4 | Container-id `iCloud.com.parkbyeongjun.latte` — accept at activation (non-gating; hard-coded in the adapter + staged entitlement) | owner, non-gating | 1 answer |
| WiFi WhenInUse | Downgrade `requestAlwaysAuthorization` → `requestWhenInUseAuthorization` — needs a real Mac to confirm CoreWLAN `ssid()` still resolves | owner device smoke | 1 edit + 1 smoke |
| Smoke 23 re-run | S36–S42 changed no UI; no scenario delta expected | none | 7 min |
| Phase I community PRs | TRANSLATIONS.md; Russian is the worked reference | awaiting community | ongoing |

---

## v1.9 owner-visible behaviour reference (post-S42)

**No owner-visible behaviour change in S42.** All three new types
(`SettingsLWWResolver`, `SettingsMigration`, `ChordSyncResolver`) are inert pure
value types that nothing calls yet — they exist so the S8.5-gated activation can
drive them. `cloudSync` is still nil, no CloudKit is compiled, the boot hook is a
no-op. The cup, menu bar, triggers, Settings, Activity, ⌘⇧L all behave exactly as
the S35/S40/S41 reference.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` already implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S41. Pages live at https://spespark.github.io/latte/ + /privacy.html.
Cross-project helper `~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario
`.smoke/scenarios/00-bundle-integrity.sh` (S35).
