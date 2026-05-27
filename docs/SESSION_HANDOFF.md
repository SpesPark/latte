# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S49 (2026-05-27) — **fixed the S48 audit findings at the doc level (the Claude-Code-doable autonomous work the owner asked to clear before the App Store push).** All of H1 (HIGH) + M1–M3 + L1–L5 from the S48 iCloud-design audit are now folded into the design docs; **the code needed no change — it was already correct, the docs were behind.** Two commits: `806dea3` (H1) + `ac51d4a` (M/L). No Swift touched (the lone code edit is the `check_doc_drift.sh` §10 lint guard, L5); no build/test required.
**v1.x release line:** v1.9 (unchanged). **Public App Store version = 1.0.0** (owner decision S45).
**Branch:** `claude/focused-hamilton-417bfc` — ahead of `origin/main` by S36 … + S47 + S48 wrap + S49 (count: `git rev-list --count origin/main..HEAD`). **PR #1 is OPEN** (`https://github.com/SpesPark/latte/pull/1`) — **not merged** (owner decides; see Owner-side pending #1). Pushed; PR auto-updates.
**Latest commits:** `806dea3` (H1 data-loss doc fix), `ac51d4a` (M1–M3 + L1–L5), + this S49 docs wrap.
**Test count:** **681** — NOT re-run (zero Swift change; last green at S47). doc-drift `--strict` is the only gate this session — clean (incl. the widened CloudKit-isolation guard).
**Smoke:** 23 scenarios (not re-run — no runtime change).
**Doc-drift:** clean.
**Catalog:** 172 keys × 11 languages — unchanged.
**Toolchain:** Xcode 26.5 / Swift 6.3.2 (Swift 6 language mode). **Deployment target:** macOS 13.0.

**🟢 The autonomous engineering backlog is exhausted again.** S48 reopened it with doc-level audit fixes; S49 cleared them. Every remaining iCloud step (Phase 2/3 activation) is S8.5-gated and partly a macOS-14 product decision; the M1–M3/L1–L4 fixes are now **specified in the RFC as activation requirements** but can't be *implemented* until the live CloudKit container exists. **🟡 The next track is the owner-driven App Store upload** — which the owner confirmed was the originally-planned work.

---

## Last session (S49)

Owner intent: the originally-planned work was the App Store push, but most of that is owner-gated GUI (screenshots, ASC, signing) — so **first clear the Claude-Code-doable autonomous work**, i.e. fix the S48 audit findings. Worked in the worktree; pure doc edits + one bash-guard edit, so no build/test (and no pty) was needed. **`git -C <worktree>` for all git ops** — the repo root is on `main`/S35 and the Bash cwd drifted there mid-session at S48, which had silently mis-targeted a `git push` (caught + corrected); using `-C` avoids it.

### H1 (HIGH) — `806dea3` — absent `schemaVersion` is v1, not fresh
The S48 data-loss trap: shipped v1.x never writes `schemaVersion`, so `04-data-model` §2.2 step1 / §4.1 / §6.2 saying "absent → fresh → no migration" (and RFC §3 telling the implementer to adopt §2.2 "steps 1–6 unchanged") would skip migrating every real upgrading user → total settings loss. The pre-built `SettingsMigration.currentSchemaVersion` already defaults absent → `1` (correct). Fix aligned the docs to the code: §2.2 step1 / §4.1 / §6.2 now say "absent → treat as 1 → migrate (no-op on a fresh install)"; RFC §3 migration bullet de-contradicted vs §11; RFC doc version 0.2 → 0.3. **No code change.**

### M1–M3 + L1–L5 — `ac51d4a` — activation-stage gaps folded into the RFC
- **M1 (§4 B-2):** named the unresolved CloudKit **zone-retention** gap — local GC does NOT delete `CKRecord`s, so the zone grows unbounded and every sync re-downloads full history (the "14-day GC bounds quota" claim was false for CloudKit). Recommended **delete-on-GC + upload-within-cutoff** (default bounded); **alternative = append-only full history** flagged as an explicit **owner product choice** for the Phase-3 (v2.1) lock.
- **M2 (§4 B-2):** dedup on the stored `CKRecord.recordName` (= the S43 `contentAddressedID`), **never** re-hash downloaded fields — CloudKit field precision ≠ the JSON round-trip the unit tests cover, and a divergent re-hash would duplicate history.
- **M3 (§3/§6):** pin the LWW timestamp to CloudKit server `modificationDate`, not a device wall-clock (skew can let an older edit win). Pure resolver unchanged — only *which* timestamp the driver feeds it.
- **L1 (04 §2.2):** the migration idempotency gate must live in the store `needsMigration` reads (UserDefaults `schemaVersion`) — bump it there or gate on `migrationCompleted`, else migration re-runs every launch.
- **L2 (04 §2.2):** noted the type-mismatch key drop (reverts to default).
- **L3/L4 (§7):** failed sync-in leaves the Mac with no active hotkey (prior chord unregistered first); `apply` must be gated on `keyboardShortcutEnabled` by the caller.
- **L5 (`check_doc_drift.sh`):** widened the §10 CloudKit-isolation guard to also catch `import CloudKit` (the true gating signal), not just CKContainer/CKDatabase. The only code change this session; doc-drift stays green (only `CloudKitSyncEngine.swift` imports CloudKit, and it's excluded).

**Net:** H1 is fully closed; M2/M3/L1 and the M1 product choice are now **specified in the RFC** and become the activation session's checklist (S8.5-gated, so not yet implemented). **No NEW patterns** (doc session). Cumulative NEW S20→S47 ≈ 92 unchanged. Findings + their resolution live in `project_icloud_design_audit.md`.

---

## Next-session entry points (priority order)

**The autonomous engineering backlog is exhausted again** (S48 audit fixes done; everything else is S8.5- or owner-gated).

**A. (OWNER-driven, the originally-planned work) App Store upload** — see "Owner-side pending". Claude can assist autonomously where possible: wire `DEVELOPMENT_TEAM` once the owner gives the Team ID (+ `xcodegen generate`); further `docs/store/` metadata edits (guarded by `check_store_limits.sh`). Screenshots (2880×1800, hard blocker) + signing + ASC paste are owner/GUI-gated.

**B. (gated) iCloud Phase 2/3 activation** — needs S8.5 + a provisioned container + switching `CODE_SIGN_ENTITLEMENTS` to `Latte.icloud.entitlements` + (Phase 2) a macOS-14 bump for the `@Model` write. **NOT autonomous** — a future session must NOT flip `LATTE_ICLOUD_SYNC` (breaks signing without a container). The S49 RFC now carries the activation checklist: **M2** dedup on `recordName`, **M3** server `modificationDate` for LWW, **L1** migration gate in the read store, **M1** owner picks bounded-vs-append-only zone retention. See `docs/design/10` §3/§4/§6/§7/§11.

**C. (only if trap #8 ever exceeds the runner's retries)** — `run_tests.sh` absorbs the stall; if a run ever fails all 3 attempts with no assertion, investigate harness/load, do NOT just bump the retry count.

---

## Cold-start (다음 세션 진입)

```bash
# 0. PTY CHECK (trap #9). Only matters if you run TESTS. Doc/metadata edits need
#    neither pty nor a build. If you do test and this fails, REBOOT or log out/in
#    — killing testmanagerd / sysctl does NOT help (orphaned /dev/ttys nodes).
python3 -c "import os;[os.close(x) for x in os.openpty()]" && echo pty-ok || echo "PTY EXHAUSTED — reboot/relogin"

# 1. Work in the WORKTREE, not the repo root (repo root is on `main`/S35).
#    Use `git -C` for git ops if the Bash cwd ever drifts back to the root.
cd .claude/worktrees/focused-hamilton-417bfc   # branch claude/focused-hamilton-417bfc, has its .xcodeproj

# 2. Doc/metadata gates (no pty, no build):
scripts/check_doc_drift.sh --strict
scripts/check_store_limits.sh --strict

# 3. If you touch Swift: builds need no pty:
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LATTE_ICLOUD_SYNC' 2>&1 | grep -E "warning:|BUILD"

# 4. Tests (only if Swift changed) — PREFER the runner (auto-retries the trap #8
#    no-assertion stall, fails fast on real failures). ~11s, expect 681.
scripts/run_tests.sh
```

**Expect**: pty-ok; (if tests run) 681/681 PASS; default + flag-on builds 0 warnings; doc-drift clean (incl. store char limits + the widened CloudKit guard); 172 keys × 11 langs; macOS 13 target; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. **Read `project_icloud_design_audit.md`** — the S48 findings + their S49 doc fixes + the activation checklist (M2/M3/L1 + the M1 owner choice).
3. `ROADMAP.md` rows 1.41 → 1.49.
4. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)** (now v0.3) — §11 phasing (Phase 1 done dark; flag-flip = Phase 2, gated), §12 decision log, and the S49 audit notes in §3/§4/§6/§7.
5. For App Store work, source-of-truth is **`docs/store/`** (README maps every field; char limits enforced by `scripts/check_store_limits.sh`; `screenshot-guide.md` for captures).
6. Memory: `MEMORY.md` → `project_icloud_design_audit.md` (S48/S49) + `project_latte_v1_9.md` S20→S47 section; cross-cutting traps in `project_latte_status.md` (**trap #8 = harness-level, auto-absorbed by `run_tests.sh`**; **trap #9 = pty, fixed by reboot/relogin not kill/sysctl**).
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

## v1.9 owner-visible behaviour reference (post-S49)

**No owner-visible behaviour change in S48 or S49** (S48 = design audit; S49 = design-doc fixes + one lint-guard widening — zero Swift/runtime change). The app behaves exactly as the S40–S47 reference: `cloudSync` nil, no CloudKit compiled, cup / menu bar / 6 triggers / Settings / Activity / ⌘⇧L all unchanged.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S47. Pages live at https://spespark.github.io/latte/ + /privacy.html.
Cross-project helper `~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario `.smoke/scenarios/00-bundle-integrity.sh` (S35).
