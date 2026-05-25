# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S46 (2026-05-25) — **opened the main-merge PR + hardened the store-metadata verification gate + pre-merge review + Phase-1-dark re-verification.** Docs/CI/tooling only; **no Swift source change, no version bump, no owner-visible behaviour change.** This session ran under **pty exhaustion (trap #9)** the whole time, so the full test suite could NOT be re-run — all work was deliberately scoped to pty-free, build-verifiable, or read-only tasks (writing test code that can't be verified would violate the session's stated goal of minimising verification errors).
**v1.x release line:** v1.9 (unchanged). **Public App Store version = 1.0.0** (owner decision S45).
**Branch:** `claude/focused-hamilton-417bfc` — pushed to `origin`, now ahead of `origin/main` by S36 … + S45 + **S46** (count: `git rev-list --count origin/main..HEAD`). **PR #1 is OPEN** (`https://github.com/SpesPark/latte/pull/1`) — **not merged** (owner decides; see Owner-side pending #1).
**Latest commit:** `09e46ee` `ci(store): add App Store char-limit checker + wire into doc-drift`.
**Test count:** **681** static — **NOT re-run this session (pty-blocked, trap #9).** No Swift changed since S45's verified 681-green, so it still holds. **Default + `LATTE_ICLOUD_SYNC` flag-on builds were both re-verified this session: BUILD SUCCEEDED, 0 warnings** (the build path does NOT need a pty — only the test runner does).
**Smoke:** 23 scenarios (not re-run — no runtime change).
**Doc-drift:** clean — and now **also enforces App Store char limits** (new section delegating to `scripts/check_store_limits.sh`).
**Catalog:** 172 keys × 11 languages — unchanged.
**Toolchain:** Xcode 26.5 / Swift 6.3.2 (Swift 6 language mode). **Deployment target:** macOS 13.0.

**🔴 pty exhaustion (trap #9) is ACTIVE right now** — `os.openpty()` fails with `Errno 6 Device not configured`; 527 `/dev/ttys*` nodes vs kernel cap 511. **It must be cleared by reboot / logout-login before any `xcodebuild test`.** See Cold-start. **🟢 Apple Developer Program (S8.5) is handled.** **🟡 Next phase = App Store upload** (owner-driven).

---

## Last session (S46)

Owner intent: build a task list + remaining-work list, recommend an order optimised for *incremental, low-error verification* ("철저하게 차곡차곡 쌓아가서 검증 오류 최소화"), then execute autonomously, using context fully, and wrap up. Owner picked **"open the main-merge PR first."**

Discovered at startup that **`xcodebuild test` was pty-blocked (trap #9, active)** — killing the stale `testmanagerd` did NOT recover it (the 527 `/dev/ttys*` nodes are orphaned device nodes the kernel won't reclaim without a reboot/relogin; only 1 live process held any ptys). So the plan was re-scoped to pty-free work and the test-dependent tasks (trigger-leak fix, perf nit) were deferred rather than written blind.

### 1. PR #1 opened (`claude/focused-hamilton-417bfc` → `main`)
42 commits (S36–S45), 63 files +2557/−384. Body groups the lineage: i18n close-out, iCloud 3-phase pure logic pre-built dark, whole-app audit/stabilization, Swift 6 migration, trap #8 leak fixes, App Store metadata reconciliation. **Not merged** — merging a shared branch is an owner decision; new S46 commits stack on the branch and auto-update the PR.

### 2. Store char-limit checker (`09e46ee`)
`scripts/check_store_limits.sh` asserts every char-limited `docs/store/` field is under Apple's cap (Unicode code points, trailing newline stripped — Korean = 1/char; counts reproduce S45 exactly: description-en 3995/4000, promo-en 160/170, keywords-en 98/100). Wired into `scripts/check_doc_drift.sh --strict` (the CI gate) so over-cap copy fails CI instead of surfacing at submit — **codifies the S45 bug** (description-en had silently grown ~690 chars over the cap). Both report-only (exit 0) and strict (exit 1 on over-limit/missing) paths verified, incl. a negative fixture test. All 11 fields currently pass.

### 3. Pre-merge code review (posted to PR #1, no code changed)
A `code-reviewer` agent reviewed the net Swift diff (read-only). **Verdict: no merge-blockers.** Findings + dispositions:
- **HIGH (agent) = FALSE POSITIVE.** It flagged `DebouncingDisplaySource`/`ExternalDisplayTrigger` plain `deinit` (not `isolated deinit`) on a `@MainActor` class as a Swift-6 data race. But the deinit only touches `observeTask: Task<Void,Never>?` and `AsyncStream.Continuation`, **both Sendable** → a nonisolated deinit cancelling a Sendable Task is legal & race-free under Swift 6, **proven by the 0-warning strict-concurrency build.** `isolated deinit` (SE-0371) is only required for *non-Sendable* isolated state. No action; do NOT "fix" this in a future session.
- **MEDIUM (real, deferred → T7):** `ActivityLogMergeResolver.canonicallyOrdered` recomputes SHA-256 on both operands per sort comparison (O(N log N) hashes vs O(N)). Dark/inactive Phase-3 code; the fix changes the canonical-ordering path → needs the 18 resolver tests re-run (pty-blocked). Tracked.
- MEDIUM (readability, no bug) + LOW (comment) — noted, no action.

### 4. iCloud Phase-1-dark re-verification + entry-point correction
Verified the dark state is healthy and consistent: flag OFF by default (`project.yml:61` signs with the no-CloudKit `Latte.entitlements`; `LATTE_ICLOUD_SYNC` only in activation comments), `Latte.icloud.entitlements` staged-**inactive**, container id `iCloud.com.parkbyeongjun.latte` consistent across the staged entitlement + `CloudKitSyncEngine.swift:22`, and **both default & flag-on builds 0-warning.**
**Correction (important):** the S45 handoff listed "iCloud Phase 1 *activation*" as an autonomous next step. That is **wrong** — `project.yml:54-60` and RFC §11 both correctly frame the flag-flip as **Phase 2** (needs S8.5 + a provisioned container + switching `CODE_SIGN_ENTITLEMENTS` to the iCloud entitlement + macOS-14 for the `@Model` write). **There is NO autonomous activation step left**: Phase 1 (the dark seam) is already shipped; flipping the flag is a gated Phase 2 release action. A future session must NOT flip it (it would break signing without a provisioned container).

### 5. Static Task-spawn inventory → trap #8 is harness-level (confirms the S44 read)
Inventoried every `Task` spawn in `Sources/`. **Every long-lived/looping task is stored and cancelled via deinit** (WiFi/Schedule/Calendar `pollTask`; ExternalDisplay/Debouncing `observeTask`; coordinator `consumerTasks`); all other spawns are one-shot fire-and-forget (incl. `TriggerCoordinator.swift:222`, the post-append notification, `[weak self]`). **No remaining uncancelled long-lived Task leak exists.** → The trap #8 residual is a **harness-level, load-dependent main-actor stall, not a product leak.** Next session's reliability work should pursue **harness mitigation** (per-test teardown cancelling spawned tasks, or lower test concurrency / serialise the trigger tests), NOT more leak-hunting.

### S46 NEW patterns (3)
a. **Codify a manual char/limit audit into a CI script the moment it bites once.** The S45 over-cap bug was invisible because the check was manual; `check_store_limits.sh` (Unicode code points, trailing-NL stripped) makes it fail CI. Calibrate the counter against a known prior result (description-en=3995) before trusting it, and verify the FAIL path with a negative fixture (a guard that never trips is useless).
b. **A `@MainActor` class with a plain `deinit` is NOT a Swift-6 race if the deinit only touches Sendable state** (`Task?`, `AsyncStream.Continuation`). The 0-warning strict build is the proof; `isolated deinit` is only for non-Sendable isolated cleanup. Don't cargo-cult `isolated deinit` onto every deinit.
c. **`xcodebuild build` does NOT need a pty; `xcodebuild test` does.** Under trap #9 you can still verify *builds* (0-warning, default + flag-on) and do all read-only/doc/CI work — only the test runner is blocked. Scope the session accordingly instead of stalling.

Cumulative NEW S20→S46 ≈ 89.

---

## Next-session entry points (priority order)

**FIRST: clear pty exhaustion.** `xcodebuild test` cannot run until the ptys are freed — **reboot or log out/in** (see Cold-start probe). Without this, the only progress possible is the owner-side App Store chain + more docs.

**A. (OWNER-driven) App Store upload** — see "Owner-side pending". Claude can assist: the PR is already open; wire `DEVELOPMENT_TEAM` once the owner gives the Team ID (+ `xcodegen generate`); further metadata edits (now guarded by `check_store_limits.sh`). Screenshots + signing are owner/GUI-gated.

**B. (AUTONOMOUS, pty-gated) trap #8 harness mitigation** — the S46 inventory confirmed there is no product leak left; the residual stall is harness/load. A dedicated effort: per-test teardown that cancels spawned tasks, or reduce test concurrency / serialise the trigger tests. Verifying it reduces stalls needs many full runs → **needs ptys.**

**C. (AUTONOMOUS, pty-gated) T7 perf nit** — `ActivityLogMergeResolver.canonicallyOrdered` double-hash (see Last session §3 / TaskList). Needs the 18 resolver tests re-run → **needs ptys.**

**D. (AUTONOMOUS, pty-gated) final clean 681-green full run** — re-confirm the suite green once ptys are back (S45 did this; nothing changed since, but it's the honest gate).

> Note: items B/C/D are ALL pty-gated. Until the machine is rebooted, autonomous progress is essentially exhausted — the remaining value is the owner-side App Store chain. iCloud Phase 1 is **done** (dark); Phase 2/3 activation is S8.5 + macOS-14 + owner-signing gated (NOT autonomous — see Last session §4).

---

## Cold-start (다음 세션 진입)

```bash
# 0. ⚠ PTY CHECK FIRST (trap #9 was ACTIVE at S46 end). If this fails, REBOOT
#    or log out/in — killing testmanagerd does NOT help (orphaned /dev/ttys
#    nodes; kernel reclaims them only on reboot/relogin). sysctl raise is
#    REJECTED (kern.tty.ptmx_max=511 is at/above the cap). No test runs until ok.
python3 -c "import os;[os.close(x) for x in os.openpty()]" && echo pty-ok || echo "PTY EXHAUSTED — reboot/relogin before any xcodebuild test"

# 1. PRE-FLIGHT — kill stale Latte before any test/Cmd-R.
pkill -9 -f "Latte.app" 2>/dev/null; sleep 1

# 2. Work in the WORKTREE, not the repo root (repo root is on `main`/S35).
#    Worktree: .claude/worktrees/focused-hamilton-417bfc (branch claude/focused-hamilton-417bfc,
#    has its .xcodeproj already; a fresh worktree would need `xcodegen generate`).

# 3. Builds work WITHOUT a pty (only the test runner needs one):
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LATTE_ICLOUD_SYNC' 2>&1 | grep -E "warning:|BUILD"

# 4. Doc-drift (now also checks App Store char limits) + the store checker directly:
scripts/check_doc_drift.sh --strict
scripts/check_store_limits.sh --strict

# 5. ONLY after pty-ok — tests (~11s, expect 681). trap #8 stall MITIGATED, NOT
#    CLOSED: a full run can stall with NO assertion text + 0 failures → ** TEST
#    FAILED **. Read the ** TEST SUCCEEDED/FAILED ** line, not a grep pipe's exit
#    code. RE-RUN on a no-assertion FAILED. Don't hammer back-to-back full runs
#    (inflates flake + re-leaks ptys → trap #9).
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | tail -3
```

**Expect**: pty-ok after reboot; 681/681 PASS; default + flag-on builds 0 warnings; doc-drift clean (incl. store char limits); 172 keys × 11 langs; macOS 13 target; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.40 → 1.46.
3. **Read [docs/design/10-c3-icloud-sync-rfc.md](design/10-c3-icloud-sync-rfc.md)** before any iCloud work — §11 phasing (Phase 1 done dark; flag-flip = Phase 2, gated), §12 decision log.
4. For App Store work, source-of-truth is **`docs/store/`** (README maps every field; char limits now enforced by `scripts/check_store_limits.sh`; `screenshot-guide.md` for captures).
5. Memory: `MEMORY.md` → `project_latte_v1_9.md` S20→S46 section; cross-cutting traps in `project_latte_status.md` (**trap #8 = mitigated/harness-level**, **trap #9 = pty, fixed by reboot/relogin not kill/sysctl**).
6. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (App Store upload — unchanged from S45 + reboot note)

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
| — | **Reboot/relogin** to clear pty exhaustion | needed before Claude can re-run the test suite for any pty-gated autonomous work (entry points B/C/D) | owner |
| — | **WiFi WhenInUse downgrade** (review-risk) | code calls `requestAlwaysAuthorization` but Info.plist has only the WhenInUse string; needs a real Mac to confirm CoreWLAN `ssid()` still resolves after downgrade | owner device smoke |

Other long-standing non-blocking items: RFC Q4 container-id (Phase ≥2), macOS-14 bump (Phase 2 activation only), Phase I community translation PRs.

---

## v1.9 owner-visible behaviour reference (post-S46)

**No owner-visible behaviour change in S46** (docs/CI/tooling only). The app behaves exactly as the S40–S45 reference: `cloudSync` nil, no CloudKit compiled, cup / menu bar / 6 triggers / Settings / Activity / ⌘⇧L all unchanged.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` implements the correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29–S45. Pages live at https://spespark.github.io/latte/ + /privacy.html.
Cross-project helper `~/dev/smoke-harness/lib/assert_bundle_resources.sh` + repo scenario `.smoke/scenarios/00-bundle-integrity.sh` (S35).
