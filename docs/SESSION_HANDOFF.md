# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S48 (2026-05-27) — **design-verification pass (report-only).** Owner deferred the originally-planned work one session and instead asked for a *thorough correctness audit of the iCloud sync design* — the one body of work that was pre-built "dark" and **cannot** be validated against live CloudKit until S8.5, so design-level review is the only verification available. Audited `docs/design/10` RFC + the 5 dark resolvers (S41–S43) + their 638 test lines + a cross-check vs `04-data-model`. **Found 1 HIGH (H1, a latent full-settings-loss contradiction), 3 MEDIUM, 5 LOW.** Result handling = **memory only** (owner choice): nothing in code or the design docs was changed; findings live in `project_icloud_design_audit.md`. **The fixes are the next session's job.**
**v1.x release line:** v1.9 (unchanged). **Public App Store version = 1.0.0** (owner decision S45).
**Branch:** `claude/focused-hamilton-417bfc` — ahead of `origin/main` by S36 … + S47 + this S48 docs wrap (count: `git rev-list --count origin/main..HEAD`). **PR #1 is OPEN** (`https://github.com/SpesPark/latte/pull/1`) — **not merged** (owner decides; see Owner-side pending #1). This docs wrap auto-updates the PR.
**Latest commits:** `1f8432f` (S47 wrap) + this S48 docs wrap (audit recorded to memory; no code/design-doc change).
**Test count:** **681** — NOT re-run this session (design audit only; zero code change). Last green at S47 (681/681, first run).
**Smoke:** 23 scenarios (not re-run — no runtime change).
**Doc-drift:** clean (only this handoff + ROADMAP touched).
**Catalog:** 172 keys × 11 languages — unchanged.
**Toolchain:** Xcode 26.5 / Swift 6.3.2 (Swift 6 language mode). **Deployment target:** macOS 13.0.

**🟢 The autonomous backlog REOPENED.** S47 had it "genuinely exhausted," but the S48 audit surfaced concrete, **doc-level (S8.5-independent)** fixes — correcting the iCloud design before activation. **Next session = fix the audit findings, H1 first** (see Next-session entry points). 🟢 trap #8 stall auto-absorbed by `scripts/run_tests.sh`. 🟢 S8.5 handled. 🟡 App Store upload still owner-driven.

---

## Last session (S48)

Owner intent: defer the planned work one session; spend this one verifying *all the iCloud sync design* for errors. Scope confirmed to **iCloud design (RFC §10 + 5 resolvers + tests + 04-data-model cross-check)**, output **report-only**, findings handling **memory only** (two `AskUserQuestion` confirms). Worked read-only in the worktree; no build/test run needed (correctness-of-design audit, not a code change).

### What was audited
`docs/design/10-c3-icloud-sync-rfc.md` (440 lines) · `CloudSyncEngine` · `SettingsLWWResolver` · `SettingsMigration` · `ChordSyncResolver` · `ActivityLogMergeResolver` + all 5 test files (638 lines) · the depended-on types (`SettingsKey`/`SettingsStore`, `ActivityLogEntry`/`ActivityLogStore`, `KeyChord`/`HotKeyRegistrar`) · `04-data-model` §2.2/§3.2/§5/§6 · the §10 CloudKit-isolation lint guard + the `LATTE_ICLOUD_SYNC` wiring.

### 🔴 H1 (HIGH) — doc/code contradiction that loses all settings on upgrade
Shipped v1.x **never writes** `.schemaVersion` (grep-confirmed: only read, default 1). So a real install has `exists(.schemaVersion) == false`. The code handles this correctly — `SettingsMigration.currentSchemaVersion` defaults absent → **1** → `needsMigration == true` → migrate. **But** `04-data-model` §2.2 step 1 (~L53), §4.1 (~L118), §6.2 (~L374) all still say **"absent → fresh install → no migration"**, and RFC §3 instructs the implementer to *"Adopt 04-data-model §2.2 as written … steps 1–6 unchanged"* — which directly contradicts the RFC §11 correction note. If the activation session follows §3 + the authoritative doc, every real v1.x→v2.0 upgrade is misclassified as fresh → migration skipped → **all trigger settings / presets / chord lost.** RFC §13's "resolved in S38" only fixed the §5 enum-snapshot staleness (that IS fixed), NOT this — the two are conflated, which is the trap.
**Fix (next session, doc-level):** correct §2.2 step1 + §4.1 + §6.2 to "absent → treat as v1 → migrate"; reword RFC §3's "steps 1–6 unchanged / as written" to match §11.

### 🟡 MEDIUM (activation-stage design gaps; pure logic itself is correct)
- **M1.** CloudKit-side retention undefined → §4's "14-day GC bounds quota" is false (local GC never deletes remote records → unbounded zone growth + full-history re-download every sync; offline "resurrection" path also undefined). Needs a CloudKit delete/tombstone strategy in the RFC.
- **M2.** Dedup depends on `contentAddressedID` stability across the **CloudKit field** round-trip, but only the JSON path is tested; if CloudKit stores `timestamp` at different precision, recomputed id ≠ write-time id → duplicates. Mitigation: dedup on the stored `CKRecord.recordName` (already = the id), or store id/micros as explicit fields.
- **M3.** LWW `updatedAt` source unpinned (device wall-clock vs CloudKit server `modificationDate`); skew can invert the winner. Recommend pinning to server `modificationDate`.

### 🟢 LOW
L1 migration idempotency-gate store ambiguity (`needsMigration` reads UserDefaults; §2.2 writes the bump to SwiftData; no `markMigrated`). L2 `readValue` silently drops a present-but-wrong-type key → reverts to default. L3 chord sync-in unregisters the prior chord before a failed re-register → device left with no hotkey + cue (by design, sharp edge). L4 `ChordSyncResolver.apply` ignores `keyboardShortcutEnabled`. L5 §10 lint greps only `CKContainer|CKDatabase`, narrower than "all CloudKit in one adapter" (`CKRecord`/`import CloudKit` slip through).

### ✅ Verified GOOD (confidence)
micros quantization premise holds → content-addr id stable across JSON round-trip (tested); `pruned` ↔ `ActivityLogStore.gc` parity exact (both keep `>= cutoff`); CRDT laws + never-LWW hold and are tested (UUID-in-digest is load-bearing for both dedup and non-collapse); `SettingsKey` is exactly 34 cases = compiler-exhaustive `valueType` switch → drift impossible; CloudKit isolation real (kill-switch default-off, adapter `#if`-gated, zero real CK use outside the adapter); §5 enum-snapshot staleness genuinely fixed in S38 (distinct from H1).

Findings recorded in `project_icloud_design_audit.md` (H1 full + M/L + GOOD) and indexed in `MEMORY.md` as "S8.5 활성화 전 필독". **No new patterns** (audit session, no code).

Cumulative NEW S20→S47 ≈ 92 (unchanged).

---

## Next-session entry points (priority order)

**The autonomous backlog reopened with the S48 audit — and the top item needs NO Apple gate.**

**A. (AUTONOMOUS, do first) Fix the S48 audit findings — all doc-level, S8.5-independent.**
- **H1 (HIGH):** correct `04-data-model` §2.2 step1 + §4.1 + §6.2 ("absent → v1 → migrate") and reword RFC §3 ("steps 1–6 unchanged / as written") to agree with §11. Pure doc edits; run `check_doc_drift.sh --strict` after.
- **M1–M3:** add the missing design decisions to RFC `docs/design/10` — CloudKit-side retention/tombstone strategy (M1), dedup-on-`recordName` note (M2), LWW timestamp source = server `modificationDate` (M3).
- **L1–L5:** mostly RFC/`04-data-model` clarifications; L5 can widen the lint guard (`CKRecord`/`import CloudKit`) in `check_doc_drift.sh`. L2–L4 are notes-to-activation (decide whether to encode now or document).
- Full detail + line refs in `project_icloud_design_audit.md`. **None of these touch the dark resolvers' behaviour or need a build/CloudKit** — they make the *future activation* low-risk, which is the whole point of the dark pre-build.

**B. (OWNER-driven) App Store upload** — see "Owner-side pending". Claude can assist: wire `DEVELOPMENT_TEAM` once given the Team ID (+ `xcodegen generate`); metadata edits (guarded by `check_store_limits.sh`). Screenshots + signing are owner/GUI-gated.

**C. (gated) iCloud Phase 2 activation** — needs S8.5 + a provisioned container + switching `CODE_SIGN_ENTITLEMENTS` to `Latte.icloud.entitlements` + a macOS-14 bump for the `@Model` write (a product decision: drops macOS 13). **NOT autonomous** — a future session must NOT flip `LATTE_ICLOUD_SYNC` (it breaks signing without a provisioned container). See `docs/design/10` §11. **Apply the H1/M/L fixes (A) before this.**

**D. (only if trap #8 ever exceeds the runner's retries)** — `run_tests.sh` absorbs the stall; if a run ever fails all 3 attempts with no assertion, investigate harness/load, do NOT just bump the retry count.

---

## Cold-start (다음 세션 진입)

```bash
# 0. PTY CHECK (trap #9). Only matters if you run TESTS. Doc edits (entry point A)
#    need neither pty nor a build. If you do test and this fails, REBOOT or log
#    out/in — killing testmanagerd / sysctl does NOT help (orphaned /dev/ttys).
python3 -c "import os;[os.close(x) for x in os.openpty()]" && echo pty-ok || echo "PTY EXHAUSTED — reboot/relogin"

# 1. Work in the WORKTREE, not the repo root (repo root is on `main`/S35).
cd .claude/worktrees/focused-hamilton-417bfc   # branch claude/focused-hamilton-417bfc, has its .xcodeproj

# 2. Entry point A is doc-only. After editing docs/design/04 + 10:
scripts/check_doc_drift.sh --strict
scripts/check_store_limits.sh --strict

# 3. If you touch any code (L5 lint widen / L2–L4 if encoded): builds need no pty:
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LATTE_ICLOUD_SYNC' 2>&1 | grep -E "warning:|BUILD"

# 4. Tests (only if code changed) — PREFER the runner (auto-retries the trap #8
#    no-assertion stall, fails fast on real failures). ~11s, expect 681.
scripts/run_tests.sh
```

**Expect**: pty-ok; (if tests run) 681/681 PASS; default + flag-on builds 0 warnings; doc-drift clean (incl. store char limits); 172 keys × 11 langs; macOS 13 target; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. **Read `project_icloud_design_audit.md`** (the S48 findings — H1 full + M/L + line refs) before touching iCloud docs.
3. `ROADMAP.md` rows 1.41 → 1.48.
4. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)** — §11 phasing (Phase 1 done dark; flag-flip = Phase 2, gated), §12 decision log. The H1/M/L fixes edit this + `04-data-model`.
5. For App Store work, source-of-truth is **`docs/store/`** (README maps every field; char limits enforced by `scripts/check_store_limits.sh`; `screenshot-guide.md` for captures).
6. Memory: `MEMORY.md` → `project_icloud_design_audit.md` (S48) + `project_latte_v1_9.md` S20→S47 section; cross-cutting traps in `project_latte_status.md` (**trap #8 = harness-level, auto-absorbed by `run_tests.sh`**; **trap #9 = pty, fixed by reboot/relogin not kill/sysctl**).
7. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (App Store upload)

Order matters (later steps depend on earlier).

| # | What | Notes | Owner/Claude |
|---|---|---|---|
| 1 | **(decide) merge PR #1 to `main`** | PR is OPEN at `https://github.com/SpesPark/latte/pull/1`; pre-merge review posted (no blockers). Release build best built from main. | owner decides; Claude can merge if told |
| 2 | **Apple Small Business Program** opt-in (15%) | ASC → Agreements, Tax, and Banking. Do early (lead time). | owner |
| 3 | **Register App ID** `com.parkbyeongjun.latte` | developer.apple.com → Identifiers | owner |
| 4 | **Team ID** → set `DEVELOPMENT_TEAM` (EMPTY in `project.yml:61` area, currently `""`) + `xcodegen generate` | give Claude the Team ID and Claude wires it | owner→Claude |
| 5 | **Create app record** in App Store Connect (macOS, "Latte", bundle id, SKU) | | owner |
| 6 | **Screenshots** 2880×1800 per `docs/store/screenshot-guide.md` | `docs/store/screenshots/` is EMPTY (.gitkeep) — **hard blocker**; needs a running build | owner |
| 7 | **Fill ASC listing** from `docs/store/*` + pricing **$2.99** + App Privacy "No Data Collected" + age rating + URLs | privacy URL live (spespark.github.io/latte/privacy.html) | owner |
| 8 | **Archive → Validate → Upload → Submit** (Xcode Organizer) | Release, signed with the team from #4 | owner |
| — | **WiFi WhenInUse downgrade** (review-risk) | code calls `requestAlwaysAuthorization` but Info.plist has only the WhenInUse string; needs a real Mac to confirm CoreWLAN `ssid()` still resolves after downgrade | owner device smoke |

Other long-standing non-blocking items: RFC Q4 container-id (Phase ≥2), macOS-14 bump (Phase 2 activation only), Phase I community translation PRs.

---

## v1.9 owner-visible behaviour reference (post-S48)

**No owner-visible behaviour change in S48** (design audit only — zero code/runtime change). The app behaves exactly as the S40–S47 reference: `cloudSync` nil, no CloudKit compiled, cup / menu bar / 6 triggers / Settings / Activity / ⌘⇧L all unchanged.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S47. Pages live at https://spespark.github.io/latte/ + /privacy.html.
Cross-project helper `~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario `.smoke/scenarios/00-bundle-integrity.sh` (S35).
