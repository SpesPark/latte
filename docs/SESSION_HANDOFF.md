# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S29** — S8d Pages unlock + V2-22 GitHub remote (2026-05-15). Same-day decision sequence from owner closes the S28-deferred Step C (S8d). Three owner decisions (GitHub username, `gh` CLI vs web UI, SSH key status) resolved in-session: **(Q1) username `SpesPark`** (3 alternates checked via curl-based availability probe; `Spes`/`bj-park` both already taken on GitHub, picked `SpesPark` from 13 verified-available variants). **(Q2) `gh` CLI path** (`brew install gh` + browser OAuth via Google SSO + `gh auth setup-git` wires keychain credential helper). **(Q3) SSH key not registered** — HTTPS + token path adopted (gh's keyring-stored token used by git via `gh auth git-credential` helper). After unlock: `gh repo create SpesPark/latte --public --source=. --remote=origin --push` from main repo (creates repo, adds origin, pushes main in one shot). gh-pages push from staging worktree (no `git remote add` needed — main repo + worktree share `.git`, origin already visible). Pages auto-enabled by gh-pages branch push (confirmed via 409 "already enabled" + status=building; settled to `built` after ~36s polling). `scripts/validate_pages.sh` confirms 200 + text/html on both `/` and `/privacy.html`. **No Latte source touched** in S29 — infrastructure unlock only, 587/587 tests unchanged. |
| **Theme** | "S8d had been deferred since S26 because 3 mechanical decisions needed owner attention — once those land, the unlock is ~10 minutes of API-driven work, not days of waiting. The unlock also auto-completes V2-22 (GitHub remote on main repo) as a side effect of `gh repo create --source=.`. Three lessons reinforce: (1) **availability probe before commitment** — checked `SpesPark` and 14 variants via `curl -sI` HTTP-status pattern (200 = taken, 404 = available) so the owner-side decision was made against verified-available data; bj-park (the script default) turned out already-taken too, which would have surfaced as a confusing git push failure later. (2) **gh credential helper requires explicit `gh auth setup-git`** even after `gh auth login` with the 'Authenticate Git? Yes' prompt — `~/.gitconfig` was empty post-login until `gh auth setup-git` ran (likely owner skipped or fell through the git-config write step in the OAuth flow). Explicit setup-git call after login is the safer ordering. (3) **Pages auto-enable on first gh-pages branch push** — the explicit `POST /repos/.../pages` API call returned 409 'already enabled' because GitHub provisions the site automatically when a `gh-pages` branch lands on a new repo. Owner-side 'Settings → Pages → Source' click was unnecessary; the API path collapses to status polling (`GET .../pages` until `status=built`) + validate. The S28 handoff predicted ~5 min of manual web-UI work for Pages enable; actual was 0 min." |
| **Status** | ✅ **0 Latte source commits** + 1 docs wrap commit (S29 is infrastructure unlock — no `Sources/` or `Tests/` touched). **Tests 587/587** unchanged from S28 (no Latte code modified). **Smoke 22/22** unchanged from S28 (no scenarios touched). **Pages live**: https://spespark.github.io/latte/ + https://spespark.github.io/latte/privacy.html both validated 200 + text/html. **Main repo remote wired**: `origin = https://github.com/SpesPark/latte.git` (PUBLIC, default branch `main`). **gh CLI installed**: `gh 2.92.0` via Homebrew. **gh auth**: SpesPark account, HTTPS protocol, token scopes `gist`+`read:org`+`repo`+`workflow` stored in macOS keyring. **Git credential helper**: `~/.gitconfig` now has `[credential "https://github.com"] helper = !/opt/homebrew/bin/gh auth git-credential` after explicit `gh auth setup-git` post-login. **V2-22 closed** (GitHub remote was the only V2-22 requirement). **Working tree clean** (excluding `.claude/` worktree machinery). |
| **Tail commit** | (this S29 docs wrap commit) — preceded by S28 chain (`0786a1c` → `7d10ef4` → `beae984`). |

### What landed this session (no Latte source commits — docs wrap only)

| Step | Resolution path | Tests Δ |
|---|---|---|
| 1 — gh CLI install | `brew install gh` → gh 2.92.0 in `/opt/homebrew/Cellar/gh/2.92.0`. ~38MB single-bottle install, no caveats beyond zsh completions location. | 0 |
| 2 — SpesPark account + `gh auth login` | Owner signed up at github.com via Google SSO (display name = username = `SpesPark` confirmed via `curl -s -o /dev/null -w '%{http_code}' https://github.com/SpesPark` returning 200 post-signup). Then owner ran `gh auth login` → GitHub.com / HTTPS / Authenticate Git: Yes / browser OAuth (8-char code paste at https://github.com/login/device). Token stored in macOS keyring with scopes `gist`+`read:org`+`repo`+`workflow`. | 0 |
| 3 — Git credential helper wiring | Initial `git config --global --get-regexp credential.` returned empty — the in-flow "Authenticate Git? Yes" step did not write the helper (gh 2.92 may have a different prompt sequence, or owner fell through). Explicit `gh auth setup-git` wrote `[credential "https://github.com"] helper = !/opt/homebrew/bin/gh auth git-credential` to `~/.gitconfig`. Verified `git config --get-all credential.https://github.com.helper` returns the gh-credential entry. Global fallback remains `osxkeychain`. | 0 |
| 4 — Repo create + main push | From main repo on `main` branch: `gh repo create SpesPark/latte --public --description "..." --source=. --remote=origin --push`. Creates PUBLIC repo, adds origin = https://github.com/SpesPark/latte.git, pushes current branch (main), sets `main` as default. Single command does repo create + remote add + push. Verified via `gh repo view SpesPark/latte --json url,visibility,defaultBranchRef`. | 0 |
| 5 — gh-pages push from staging | `cd ~/Documents/Claude/Projects/latte-gh-pages-staging && git push -u origin gh-pages`. Staging worktree shares `.git` with main repo, so `origin` was already visible — no `git remote add` needed. 1 commit (`e3738a9` site: initial Latte marketing + privacy pages) pushed. Verified both branches present via `gh api repos/SpesPark/latte/branches`. | 0 |
| 6 — Pages enable (auto) | Explicit `POST /repos/SpesPark/latte/pages` returned `409 GitHub Pages is already enabled` — GitHub auto-provisions Pages when a `gh-pages` branch lands on a new repo. Polled `GET .../pages` until `status=built` (~36s, 7 attempts at 6s interval). `html_url`: https://spespark.github.io/latte/ (subdomain lowercased — GitHub canonicalises). | 0 |
| 7 — validate_pages.sh | `scripts/validate_pages.sh https://spespark.github.io/latte/` → `[validate] / OK (200, text/html; charset=utf-8)` + `[validate] /privacy.html OK (200, text/html; charset=utf-8)` + `all checks passed — Pages site is App Store submission ready`. | 0 |
| Security scan | `git grep -nIE '(api[_-]?key\|secret[_-]?key\|password\s*=\|TOKEN\s*=\|sk-[a-zA-Z0-9]{20,}\|ghp_[...]\|AKIA[...]\|PRIVATE KEY)' HEAD` and tracked-files scan for `.env` / `.pem` / `.p8` / credentials → both clean before public push went out. Latte's local-only architecture (no secrets in source) is consistent with the green scan. | 0 |

### Patterns reinforced this session

- **Availability probe before commitment** (Steps 1-2) — `curl -s -o /dev/null -w "%{http_code}" https://github.com/<name>` returns 200 for taken usernames and 404 for available. Batch 15 variants in a `for` loop to give owners a real menu. Owner's initial pick (`Spes`) and the script default (`bj-park`) both turned out 200 — without the probe, the gh repo create would have failed at namespace-collision and the owner would have made the pivot decision under time pressure. The probe is cheap, deterministic, and pre-resolves the "first choice unavailable" branch.
- **`gh auth setup-git` is not implied by `gh auth login`'s git-prompt** (Step 3) — Even after picking "Authenticate Git with your GitHub credentials? Yes" in the OAuth flow, `~/.gitconfig` had no credential helper. Run `gh auth setup-git` explicitly as a separate step after `gh auth login` to wire the helper. Without it, git pushes to github.com fall through to osxkeychain → username/password prompt → owner confusion. The explicit-after-login ordering removes the conditional behavior and gives the same end state regardless of the OAuth path the owner picked.
- **GitHub Pages auto-enables on first `gh-pages` branch push** (Step 6) — `POST /repos/<owner>/<repo>/pages` returned `409 already enabled` immediately after `git push -u origin gh-pages`. The S28 handoff anticipated ~5 min of web-UI clicking to enable Pages (Settings → Pages → Source = gh-pages / root); actual was 0 min of clicks. The validate path collapses to `gh api repos/.../pages` status polling (`building` → `built`, ~30-60s) + `scripts/validate_pages.sh <url>`. Future S8d-style unlocks for other macOS apps in the pipeline can rely on this auto-enable — no manual GitHub UI clicks needed.
- **`gh repo create --source=. --push` auto-completes "remote add" + "first push"** (Step 4) — Single command for the post-decision unlock collapses what was historically 3 commands (`git remote add origin <url>`, `git push -u origin main`, `gh repo view` to confirm) into 1. This is also why V2-22 (originally a separate "set up GitHub remote on main repo" item) is now closed as a no-marginal-effort side effect — the gh CLI path does both in one invocation.
- **Worktrees share `.git`, so `origin` propagates** (Step 5) — Adding `origin` to the main repo at `~/Documents/Claude/Projects/Latte` made it immediately visible from the staging worktree at `~/Documents/Claude/Projects/latte-gh-pages-staging` without re-running `git remote add`. `git remote -v` from the staging worktree shows the same remote URL. For multi-branch deployment patterns (main + gh-pages in separate worktrees), set up the remote once on the main repo and push branches from their respective worktrees.

### What was checked but not changed

- 587/587 tests and smoke 22/22 — S29 made zero Latte source changes (no `Sources/`, `Tests/`, `.smoke/scenarios/`, `project.yml` touched). The S28-validated state holds. No re-run was needed during S29; if the owner wants belt-and-braces, run cold-start ritual at S30 start (will hit the rebuild-gate "up to date" path since source mtime is older than binary mtime).
- `docs/v2-backlog.md` V2-22 row — closed in this docs wrap (status flips to ✅ Done via S29).
- S28 docs and patterns — accurate description of the rebuild gate + assertion infrastructure. No retroactive corrections from S29 perspective.

### What was deferred to a later session

- **S8.5 Apple Developer Program** — still awaiting Apple review (applied 2026-05-02; typical wait 1-2 days; now 13 days). Owner should ping Apple via the Developer Support portal if no update by 2026-05-17.
- **S9 App Store Connect metadata** — depends on S8.5 (need Dev Program enrollment to create the App Store Connect listing). Materials are pre-staged: `docs/store/` has 14 metadata text files in en + ko, screenshot guide, reviewer notes. Once S8.5 unblocks, S9 is mechanical paste-into-form work.
- **Cross-project rebuild-gate lift-and-shift** (S27/S28 carryover) — the smoke harness rebuild gate added in S28 can be applied to the other 9+ macOS apps in the owner's pipeline by adding 3 lines of `build_*` config to each project's `.smoke/config.yml`. Not on the critical path; pick up when working on the next app.
- **Smoke scenario coverage extension** (S28 carryover) — `assert_binary_type` is currently in scenarios 18/20/21/22 (the four where the S27 stale-binary discovery bit). Symmetric coverage for 01-17 + 19 is ~10 assertion lines (~30 min). Only worth doing if a stale-binary recurrence surfaces.
- **C-3 iCloud sync / B1.2 iCloud chord sync** — joint design (CloudKit + conflict resolution). Multi-session, owner direction needed on whether/when to start.
- **V2-06 still-deferred** (lid-closed-only mode, per-display position requirement) — small UX features, no critical-path blocker.
- **B1.2 still-deferred** (per-action chords, false-negative chord-reserved indicator) — owner direction needed.

The v1.x autonomous-coding backlog after S29:
- **Owner-blocked (Apple-side wait)**: S8.5 (Apple Dev Program review), S9 (depends on S8.5).
- **No longer owner-blocked**: S8d ✅ closed this session, V2-22 ✅ closed as side effect.
- **Multi-session candidates needing owner direction**: C-3 iCloud sync, B1.2 deferred items, V2-06 deferred items.
- **Single autonomous candidates**: rebuild-gate lift-and-shift to other projects, smoke scenario coverage symmetric extension. Neither is on the critical path.

---

## Next-session entry points (priority order)

**0. (BLOCKER) S8.5 Apple Developer Program** — applied 2026-05-02, now Day 13 of typical 1-2 day wait. Action: check email + https://developer.apple.com/account/ enrollment status. If still pending, owner can call Apple Developer Support (only owner can — phone/portal authentication tied to Apple ID). Once approved, S9 (ASC metadata paste) unblocks.

**1. (BLOCKER) S9 App Store Connect metadata** — depends on S8.5. Materials pre-staged in `docs/store/`:
   - `metadata/en/{name,subtitle,description,keywords,promotional_text,whats_new}.txt`
   - `metadata/ko/{...}.txt`
   - `support_url.txt` → `https://spespark.github.io/latte/`
   - `marketing_url.txt` → same
   - `privacy_url.txt` → `https://spespark.github.io/latte/privacy.html`
   - `reviewer_notes.txt`
   - `screenshot_guide.md`
   - The URLs are now LIVE — verify any `<acct>` placeholder in metadata text was already replaced; if not, sed-replace to `spespark`.

**2. (LOW) Pre-flight verify smoke 22/22 against new public repo state** *(optional belt-and-braces)* — S29 changed no Latte source so smoke is logically unchanged, but the cold-start ritual would catch any drift if owner pulls main on a different machine. `~/dev/smoke-harness/run.sh --project ~/Documents/Claude/Projects/Latte` will rebuild gate "up to date" and PASS 22/22.

**3. (LOW) Smoke harness rebuild-gate adoption in other projects** *(carried from S27/S28)* — apply `build_command` / `build_source_dir` / `build_binary_path` keys to the `.smoke/config.yml` of the next 1-2 macOS apps in the owner's pipeline. ~3 lines per project + a verification run.

**4. (LOW) Smoke scenario coverage extension** — `assert_binary_type` for scenarios 01-17 + 19 (the older v1.0~v1.1 features). ~30 min autonomous work. Only worth doing if a stale-binary recurrence surfaces.

**5. (LOW) C-3 iCloud sync of activity history** + **B1.2 iCloud chord sync** — joint design (CloudKit + conflict resolution). Multi-session, requires owner direction on whether/when to start.

**6. (LOW) V2-06 still-deferred**: lid-closed-only mode, per-display position requirement.

**7. (LOW) B1.2 still-deferred** (per 07-spec §1): per-action chords, false-negative chord-reserved indicator.

S29 is an infrastructure unlock session. v1.x version unchanged at v1.9. With S8d + V2-22 closed, the v1.x owner-blocked queue narrows to S8.5 + S9 (Apple-side only).

---

## Cold-start (다음 세션 진입)

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null   # zombie 제거 — LSMultipleInstancesProhibited
git log --oneline -8

# S29 NEW: confirm origin remote + Pages still live
git remote -v                                                  # origin = https://github.com/SpesPark/latte.git
gh auth status 2>&1 | head -5                                  # ✓ Logged in to github.com account SpesPark
curl -s -o /dev/null -w "%{http_code}\n" https://spespark.github.io/latte/  # 200

# S28 unchanged: harness rebuild gate is up to date if no source touched
xcodebuild -scheme Latte -configuration Release build -quiet 2>&1 | tail -3
stat -f "%Sm  %N" ~/Library/Developer/Xcode/DerivedData/Latte-hcfmwngrrkeynehkwodtxrrnyxyq/Build/Products/Release/Latte.app/Contents/MacOS/Latte

xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed 587 tests"
~/dev/smoke-harness/run.sh --project .   # SERIAL — xcodebuild test ↔ harness 병렬 금지 (S10.1 lesson)
```

**Expect**: origin remote pointing at SpesPark/latte; gh auth showing SpesPark; Pages 200; 587/587 tests PASS in ~9s; smoke 22/22 PASS in ~6:14 with feature-presence assertions firing GREEN.

**S29 NEW useful**:
- `gh repo view SpesPark/latte --web` opens the repo in browser
- `gh api repos/SpesPark/latte/pages --jq '.status'` returns current Pages status (`built` / `building` / `errored`)
- `scripts/validate_pages.sh https://spespark.github.io/latte/` re-runs the App-Store-readiness curl check
- `gh repo edit SpesPark/latte --description "<new desc>"` updates the public description without web UI
- For future `gh-pages` updates: `scripts/deploy_pages.sh https://github.com/SpesPark/latte.git` syncs `docs/site/{index,privacy}.html` → `../latte-gh-pages-staging/` → push origin gh-pages. Use HTTPS URL until SSH key is registered; SSH form is `git@github.com:SpesPark/latte.git`.

---

## How to resume

1. Read this file first (always overwritten last session).
2. Skim `ROADMAP.md` row 28 (S29) for this session, row 27 (S28) for the immediately prior session.
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` (now 14-line index) → drill into `project_latte_v1_9.md` for the S20→S29 section.
4. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S29 update)

| # | What | Why blocked | Effort |
|---|---|---|---|
| **S8d** | **CLOSED this session** — SpesPark/latte repo live, gh-pages branch pushed, Pages serving https://spespark.github.io/latte/ + /privacy.html | Was: 3 owner decisions (username, gh CLI, SSH key) | 0 (closed) |
| **V2-22** | **CLOSED this session** — `gh repo create --source=. --push` auto-added origin to main repo | Was: depended on S8d unlock | 0 (closed) |
| S8.5 | Apple Developer Program — applied 2026-05-02 | Awaiting Apple review (Day 13). Owner should check email + portal; consider calling Developer Support if Day 14+ | 1-2 days (typical) |
| S9 | App Store Connect 메타 입력 + screenshots upload + binary submission | S8.5 의존; materials pre-staged in `docs/store/` | varies (1-3 sessions once S8.5 unblocks) |

---

## v1.9 owner-visible behavior reference (post-S29, no behaviour change)

S29 changed zero Latte runtime behaviour — only repo infrastructure (GitHub remote + Pages live). The reference list below is unchanged from S28 wrap.

- Activity tab no longer flashes the empty-state placeholder on first-ever entry per app launch (S25 P-issue-4).
- Activity tab Export CSV/JSON removed (S24).
- Activity tab no longer flashes spinner-only frame on first entry (S24 P-issue-2).
- Activity tab no longer flashes previous scroll position on tab re-entry (S24 P-issue-3).
- Recurring Quick presets render active marker on picked row (left stripe + right checkmark) (S23 P-issue-2/3).
- All three popover row types show consistent active marker (S23 P-issue-3).
- "Until X" caption shows target wall-clock minute (S23 P-issue-1).
- Activity tab Retention is a Picker (S23 P-issue-4).
- Popover footer ⌘Q quits Latte from inside popover; global awake-toggle chord unaffected (S26/S27).
- ⌘, in popover passes through (S27).

Carryover from earlier sessions (unchanged):

- v1.0~v1.8 owner-visible feature set (5 trigger types, custom presets, activity log, theme customisation, etc.)
- S22 fixes: pause-all snooze caption, "big red button" Turn off, HeaderView caption gates, cross-trigger pause-lift auto-recovery, recurring presets light-mode visuals.

---

## ⌘⇧L behaviour reference (read before next chord-related work)

Unchanged from S27/S28 wrap. **`AwakeManager.toggle()` already implements** "if caffeinate ON → Turn off (disable all triggers); if caffeinate OFF → Indefinitely activate" — no code change pending.

```
AwakeManager.toggle():
  if state.assertionHeld {
      process(.constraintDeactivate)
      postUserExplicitDeactivateIfTransitioned()  // disableAll()
  } else {
      process(.userActivate(.indefinite))
  }
```

Don't re-research — behaviour is correct, only the chord (default ⌘⇧L, owner-rebindable, owner currently using ⌘⌃L) is collision-prone.

---

## Smoke harness infrastructure reference (S28 unchanged)

**Where the rebuild gate lives**: `~/dev/smoke-harness/run.sh` (owner-local, NOT git-tracked).

**Where the feature-presence helper lives**: `~/dev/smoke-harness/lib/assert_binary_type.sh` (owner-local, NOT git-tracked).

**Per-scenario assertion call template** (already in 18/20/21/22):

```bash
bash "$HARNESS_LIB/assert_binary_type.sh" \
  "$SMOKE_APP_PATH/Contents/MacOS/Latte" \
  '\bLatte\.YourTypeName\b' \
  "scenario-name-for-log" >/dev/null
```

**Adoption checklist for the next macOS app** (V2-30 cross-project leverage):

```yaml
# .smoke/config.yml
build_command: xcodebuild -scheme <App> -configuration Release build -quiet
build_source_dir: Sources
build_binary_path: ~/Library/Developer/Xcode/DerivedData/<App>-<hash>/Build/Products/Release/<App>.app/Contents/MacOS/<App>
```

Then add `assert_binary_type` calls to scenarios that test specific features.

---

## GitHub repo + Pages infrastructure reference (S29 NEW)

**Main repo remote**: `origin = https://github.com/SpesPark/latte.git` (PUBLIC, default = main). Owner of repo: `SpesPark` account.

**gh-pages branch**: pushed from `~/Documents/Claude/Projects/latte-gh-pages-staging/` worktree. Contains `index.html` + `privacy.html` (marketing landing + Privacy Policy, dark-mode-aware).

**Live URLs**:
- Landing: https://spespark.github.io/latte/
- Privacy: https://spespark.github.io/latte/privacy.html
- Repo: https://github.com/SpesPark/latte

**Updating Pages content** (future):
1. Edit `docs/site/{index,privacy}.html` on main branch.
2. Run `scripts/deploy_pages.sh https://github.com/SpesPark/latte.git` (HTTPS form; switch to `git@github.com:SpesPark/latte.git` once owner registers SSH key).
3. Script diffs against staging worktree, commits changed files, pushes origin/gh-pages.
4. ~30-60s for Pages CDN to rebuild.
5. `scripts/validate_pages.sh https://spespark.github.io/latte/` to verify.

**Token rotation** (when needed):
- `gh auth refresh -s gist,read:org,repo,workflow` re-issues the gh CLI token.
- macOS keyring stores it under `gh:github.com`.
- Git credential helper auto-picks up the new token (no per-push re-auth).

**SSH key registration** (optional, future): add at https://github.com/settings/keys → switch deploy_pages.sh URLs to `git@github.com:SpesPark/latte.git` form.
