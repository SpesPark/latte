# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S47 (2026-05-26) — **pty recovered → executed the S46-deferred autonomous backlog D→C→B.** trap #9 was cleared (reboot/relogin), so the pty-gated work S46 had to defer became actionable. Owner confirmed **"자율 D→C→B"**. Shipped: a perf fix (C/T7) and a CI test-runner that absorbs the trap #8 stall (B). Both verified; full suite green.
**v1.x release line:** v1.9 (unchanged). **Public App Store version = 1.0.0** (owner decision S45).
**Branch:** `claude/focused-hamilton-417bfc` — pushed to `origin`, ahead of `origin/main` by S36 … + S47 (count: `git rev-list --count origin/main..HEAD`). **PR #1 is OPEN** (`https://github.com/SpesPark/latte/pull/1`) — **not merged** (owner decides; see Owner-side pending #1). New S47 commits stack on the branch and auto-update the PR.
**Latest commits:** `8893a56` (C/T7 perf), `6e24e88` (B / `run_tests.sh`), + this docs wrap.
**Test count:** **681** — re-confirmed green this session (681/681 PASS, first run, `** TEST SUCCEEDED **`). No test count change (C fixed a hot path, B added a script — neither adds tests; the C change is covered by the existing 18 resolver tests).
**Smoke:** 23 scenarios (not re-run — no runtime change).
**Doc-drift:** clean (incl. App Store char limits).
**Catalog:** 172 keys × 11 languages — unchanged.
**Toolchain:** Xcode 26.5 / Swift 6.3.2 (Swift 6 language mode). **Deployment target:** macOS 13.0.

**🟢 pty (trap #9) was CLEAR this session** (`os.openpty` 8/8). **🟢 trap #8 stall is now auto-absorbed by `scripts/run_tests.sh`** (retries the no-assertion stall only; real failures fail fast). **🟢 Apple Developer Program (S8.5) is handled.** **🟡 Next phase = App Store upload** (owner-driven). **The autonomous backlog is now genuinely exhausted** — every remaining engineering step needs the live CloudKit container behind S8.5 (see Next-session entry points).

---

## Last session (S47)

Owner intent (from the S46 handoff + this session's confirm): pty was the only thing blocking the S46-deferred backlog; if recovered, run **D→C→B** autonomously with maximal verification, then wrap.

**Startup checks:** trap #9 CLEARED (`os.openpty` 8/8; 20 `/dev/ttys` nodes vs S46's 527 orphaned — the machine was rebooted/relogged). Branch tip was `8fc4217` (S46 docs wrap), **one commit past the `09e46ee` recorded in MEMORY/handoff** — corrected. Worktree `.claude/worktrees/focused-hamilton-417bfc` healthy (has its `.xcodeproj`, synced with origin); repo root is on `main`/S35 as always — **worked in the worktree.**

### D — baseline (681-green)
Ran the full suite in the worktree: **681/681 PASS, first run, no trap #8 stall** (`** TEST SUCCEEDED **`, 11.9s). The honest gate S45 set, reconfirmed; nothing had changed since.

### C — T7 perf nit (`8893a56`)
`ActivityLogMergeResolver.canonicallyOrdered` recomputed SHA-256 for **both** operands on every sort comparison (O(N log N) hashes). Switched to **decorate-sort-undecorate**: hash each entry once (O(N)), sort the `(id, entry)` pairs by `(timestamp, id)`, undecorate. The order is byte-identical, so the union merge's commutativity / associativity / idempotency contract is unchanged. Resolves the S46 pre-merge-review MEDIUM (dark Phase-3 code). **Verified:** 18 resolver tests + full 681 green; default + flag-on (`LATTE_ICLOUD_SYNC`) builds 0-warning; doc-drift --strict clean.

### B — trap #8 harness mitigation (`6e24e88`)
**Investigation first.** The two levers the S46 handoff suggested turned out to be exhausted or inapplicable:
- *"reduce concurrency / serialise the trigger tests"* — the scheme is **already `parallelizable = "NO"`** (test classes run serially). Lever spent.
- *"per-test teardown that cancels spawned tasks"* — all 11 trigger test classes hold their triggers as **local variables** (released at method scope-end). A `tearDown` override has no reference to reach them. Only 4 non-trigger test files even have setUp/tearDown.

S46 had already confirmed there is **no remaining product leak** (static Task-spawn audit). So the correct B — per S46's own verdict, *"harness mitigation, not leak-hunting"* — is to **codify the long-documented "re-run-on-FAILED" manual mitigation into infrastructure**:

`scripts/run_tests.sh` runs `xcodebuild test`, captures the log, and classifies it by the **authoritative `** TEST SUCCEEDED/FAILED **` line (NOT the pipe exit code)** into:
- **PASS** → exit 0.
- **FAIL** (a real `Test Case … failed`, a nonzero failure summary, OR a build failure) → **exit 1, never retried.**
- **PTY** (trap #9 launch error) → **exit 1, never retried** (reboot fixes it; retrying burns ptys).
- **STALL** (`** TEST FAILED **` with zero assertion evidence, or a killed/absent result) = trap #8 → **retry**, bounded (default 3 attempts, well under the ~25 that re-exhaust ptys).

Pre-flight kills stale Latte + clears a stale `-resultBundlePath` before each attempt so retries are clean. **CI's Test step now calls it.** The safety property — *a genuine red is never masked* — is the whole point: retry ONLY the well-characterised stall, fail-fast on everything else.

**Verified:** 6-case classifier self-test with crafted logs (PASS/FAIL/STALL/PTY/build/empty — proving the dangerous "real fail → no retry" direction); live happy-path (PASS attempt 1, exit 0); `-resultBundlePath` retry-clean (consecutive runs, no "already exists"); and **a live run that genuinely hit a trap #8 stall on attempt 1 and recovered on attempt 2** — empirical proof both that the residual stall is real/load-dependent and that the runner absorbs it. Confirmed the "already exists" error (`xcodebuild: error: Existing file…`) classifies as FAIL, not STALL (no misclassification).

### S47 NEW patterns (3)
a. **Decorate-sort-undecorate to hoist an expensive comparator key.** When a sort tie-break recomputes a costly key (SHA-256) per comparison, precompute it once per element (O(N) vs O(N log N)) and sort the decorated pairs; identical order ⇒ the algebraic contract holds.
b. **Codify a documented manual flake-mitigation into a retry-runner that decides by the authoritative result line, not the pipe exit code.** Retry ONLY the well-characterised no-assertion stall; fail-fast on every real/build/pty failure so a red is never masked; prove the dangerous direction impossible with crafted-log fixtures before trusting it.
c. **When the suggested fix levers are already pulled (serialisation) or structurally inapplicable (local-var triggers a teardown can't reach), the right move for a confirmed harness-level flake is harness infrastructure, not product/test churn.**

Cumulative NEW S20→S47 ≈ 92.

---

## Next-session entry points (priority order)

**The autonomous backlog is genuinely exhausted.** All three iCloud phases' pure CloudKit-free logic is pre-built dark (P1 seam S41, P2 LWW/migration/chord S42, P3 union-merge S43); the trap #8 stall is now auto-absorbed by the runner; the Swift 6 migration is done; the store metadata + char-limit gate are in. **There is NO autonomous engineering step left** that doesn't need the live CloudKit container behind S8.5.

**A. (OWNER-driven) App Store upload** — see "Owner-side pending". Claude can assist: PR #1 is open; wire `DEVELOPMENT_TEAM` once the owner gives the Team ID (+ `xcodegen generate`); further metadata edits (guarded by `check_store_limits.sh`). Screenshots + signing are owner/GUI-gated.

**B. (gated) iCloud Phase 2 activation** — needs S8.5 + a provisioned container + switching `CODE_SIGN_ENTITLEMENTS` to `Latte.icloud.entitlements` + a macOS-14 bump for the `@Model` write (a product decision: drops macOS 13). **NOT autonomous** — a future session must NOT flip `LATTE_ICLOUD_SYNC` (it breaks signing without a provisioned container). See `docs/design/10` §11.

**C. (only if trap #8 ever exceeds the runner's retries)** — `run_tests.sh` now absorbs the stall; if a run ever fails all 3 attempts with no assertion, that exceeds the historical flake rate → investigate the harness/load (per-test main-actor quiescence, lower trigger-test load), do NOT just bump the retry count.

---

## Cold-start (다음 세션 진입)

```bash
# 0. PTY CHECK (trap #9). Was CLEAR at S47 end. If this fails, REBOOT or log
#    out/in — killing testmanagerd / sysctl does NOT help (orphaned /dev/ttys
#    nodes; kernel reclaims them only on reboot/relogin).
python3 -c "import os;[os.close(x) for x in os.openpty()]" && echo pty-ok || echo "PTY EXHAUSTED — reboot/relogin"

# 1. Work in the WORKTREE, not the repo root (repo root is on `main`/S35).
cd .claude/worktrees/focused-hamilton-417bfc   # branch claude/focused-hamilton-417bfc, has its .xcodeproj

# 2. Builds need no pty:
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LATTE_ICLOUD_SYNC' 2>&1 | grep -E "warning:|BUILD"

# 3. Doc-drift (+ App Store char limits) + the store checker directly:
scripts/check_doc_drift.sh --strict
scripts/check_store_limits.sh --strict

# 4. Tests — PREFER the runner (auto-retries the trap #8 no-assertion stall,
#    fails fast on real failures). ~11s, expect 681. Don't hammer back-to-back
#    full runs (re-leaks ptys → trap #9).
scripts/run_tests.sh
#    (raw, if you need it: xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | tail -3 —
#     read the ** TEST SUCCEEDED/FAILED ** line, NOT the pipe exit code; re-run on a no-assertion FAILED.)
```

**Expect**: pty-ok; 681/681 PASS; default + flag-on builds 0 warnings; doc-drift clean (incl. store char limits); 172 keys × 11 langs; macOS 13 target; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.41 → 1.47.
3. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)** before any iCloud work — §11 phasing (Phase 1 done dark; flag-flip = Phase 2, gated), §12 decision log.
4. For App Store work, source-of-truth is **`docs/store/`** (README maps every field; char limits enforced by `scripts/check_store_limits.sh`; `screenshot-guide.md` for captures).
5. Memory: `MEMORY.md` → `project_latte_v1_9.md` S20→S47 section; cross-cutting traps in `project_latte_status.md` (**trap #8 = harness-level, now auto-absorbed by `run_tests.sh`**; **trap #9 = pty, fixed by reboot/relogin not kill/sysctl**).
6. **Don't** re-read S1-S11 memory entries — consolidated during S13.

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

## v1.9 owner-visible behaviour reference (post-S47)

**No owner-visible behaviour change in S47** (a perf fix on dark Phase-3 code + a CI test-runner). The app behaves exactly as the S40–S46 reference: `cloudSync` nil, no CloudKit compiled, cup / menu bar / 6 triggers / Settings / Activity / ⌘⇧L all unchanged.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S46. Pages live at https://spespark.github.io/latte/ + /privacy.html.
Cross-project helper `~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario `.smoke/scenarios/00-bundle-integrity.sh` (S35).
