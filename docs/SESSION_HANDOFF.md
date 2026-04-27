# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## S8b research preamble (2026-04-27, mid-session, doc-only)

Before S8b execution work begins, a 45-min market research pass ran (4 parallel agents). 4 of 5 recommendations applied; owner overrode the price-hike recommendation. Doc-only changes — build state unchanged from S7.11 (263 tests, Release green).

**Adjustments applied:**
- `docs/design/01-PRD.md` §1.1 — wedge re-framed (Calendar-aware → Context-aware, outcome-first marketing headline added, subscription ban codified as durable guardrail).
- `docs/site/index.html` — H1 + tagline + meta title + problem heading + pricing card updated to "Never let your Mac sleep at the wrong moment" / "$2.99 once, forever, no subscription ever".
- `docs/v2-backlog.md` — recommended ship-order table added; V2-01 promoted to v1.1; **V2-05 schedule trigger NEW** (v1.2, ahead of EKCalendar picker per Q3 research); V2-04 demoted to v1.3; **V2-06 external display trigger NEW** (v1.3+); V2-03 confirmed-low-demand annotation.
- `docs/store/{subtitle-en,subtitle-ko,keywords-en,keywords-ko}.txt` — replaced with Q4 deliverable verbatim (subtitle-en `Auto keep-awake for your Mac` 28c; keywords-en 98c; subtitle-ko `맥을 자동으로 깨어있게` 12c; keywords-ko 59c).
- `docs/store/description-{en,ko}.md` — opening + pricing sections updated.
- Memory migrated: `~/.claude/projects/-Users-parkbyeongjun-Documents-Claude-Projects-Caffeinated-Clone/memory/` → `-Latte/memory/`. New `project_latte_session8b_research.md` + MEMORY.md prepend.

**Owner decisions captured:**
- **Keep $2.99** (rejected $3.99 sweet-spot recommendation) for aggressive market entry. Rationale: undercut Caffeinated, beat Lungo on price; prioritize adoption velocity over per-unit revenue.
- **Subscription banned** in PRD as durable guardrail (Bartender 5 cautionary tale).
- All other 3 recommendations approved as-is.

**S8b execution work below is unchanged.** This research preamble is doc-only — same build, same tests, same screenshots needed, same owner steps. Commit either as a separate `docs:` commit OR fold into the S8b execution commit at owner's discretion.

---

## S8b — v1.0 scope expansion (mid-session, code + tests + docs)

After approving the research preamble owner asked to ship more aggressively. Five v1.0 additions landed on the same `main` branch in 4 atomic commits (each independently smoke-able):

| Commit | Item | Effort | Tests |
|---|---|---|---|
| `05f8c2d` | V2-01 menu-bar awake visualization + V2-10 `accentAwake` cleanup | ~2h | 263 → 267 (+4) |
| `6109859` | Launch at Login (SMAppService) | ~2h | 267 → 274 (+7) |
| `7decb84` | V2-04 EKCalendar list picker | ~3h | 274 → 279 (+5) |
| `2da1f3d` | First-run onboarding wizard | ~4h | 279 → 284 (+5) |

**Behavior changes owner must smoke** (in addition to S7.11 regression check):
1. **First launch shows onboarding window** (3 steps: welcome → trigger picker → done). Old installs (settings already populated) skip — verify by deleting `~/Library/Containers/com.parkbyeongjun.latte/Data/Library/Preferences/com.parkbyeongjun.latte.plist` to simulate first run.
2. **Menu-bar icon now visibly distinguishes awake vs asleep**. Filled/outline styles: outline cup at rest → filled cup when active. Clock style: mug at rest → cup-with-steam when active.
3. **Settings → General → Behavior** has new "Launch at login" toggle. Toggling it should immediately register/unregister the SMAppService login item (verify via System Settings → General → Login Items).
4. **Settings → Triggers → Calendar** now has a "Watched calendars" disclosure with a multi-select picker. Empty selection means "all calendars" (backward-compat with pre-S8b default).

If any of #1-#4 surfaces a P1, fix-first per the established S7-family pattern.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | 8a (code & metadata prep) — 2026-04-27 |
| **Theme** | App Store prep, Dev-Program-free portion. Bundle ID + version 1.0 + folder rename + marketing site + App Store metadata + v2 backlog. |
| **Date** | 2026-04-27 |
| **Status** | ✅ Completed (pending final commit). 263/263 tests pass. Release config build succeeded. **Working folder renamed `Caffeinated-Clone/ → Latte/`.** Two commits planned for S8a: `87d1eab` (docs-only — already landed) + one S8a-final commit (still in working tree as of this handoff write — see "Final commit pending" below). S8.5 (Apple Dev Program enrollment) hard-blocked owner-side; everything inside this session was Dev-Program-free. |

### What was accomplished

#### Already committed (`87d1eab`)

1. **`docs/v2-backlog.md`** — 7 deferred items captured during S7-family iteration (V2-01 menu-bar awake-state visualization, V2-02 Calendar/WiFi `reevaluateWatched()` parity, V2-03 per-Focus selection, V2-04 EKCalendar picker, V2-10 `accentAwake` cleanup, V2-11 icon dark/tinted variants, V2-12 multi-OS smoke).

2. **`docs/site/`** — GitHub Pages-ready landing page (`index.html`) + Privacy Policy (`privacy.html`) with dark-mode-aware coffee palette + `README.md` documenting 3 hosting options.

3. **`docs/store/`** — 14 metadata text files for App Store Connect paste at submission time. en + ko localized for `subtitle`, `promotional-text`, `description`, `whats-new`, `keywords`. Plus `pricing.txt`, `category.txt`, `age-rating.md`, `privacy-data.md` (App Privacy declaration source-of-truth), `review-notes.md` for the App Store reviewer. `screenshot-guide.md` for the owner's capture pass with the 5 required shots and the pre-upload checklist. `screenshots/` directory with `.gitkeep`.

#### Done in working tree, **not yet committed**

4. **Bundle ID `com.example.latte → com.parkbyeongjun.latte`** across 6 source/config sites + 4 design docs:
   - `project.yml` — `bundleIdPrefix`, `Latte.PRODUCT_BUNDLE_IDENTIFIER`, `LatteTests.PRODUCT_BUNDLE_IDENTIFIER`
   - `Sources/Core/Logging.swift` — `LatteLog.subsystem`
   - `Sources/Core/PowerAssertion.swift` — `Logger(subsystem:)`
   - `Sources/Core/SettingsStore.swift` — `settingsLogger`
   - `docs/design/01-PRD.md` — table row + R-09 risk row
   - `docs/design/02-architecture.md` — §6.2 logging snippet
   - `docs/design/04-data-model.md` — `defaults read` example + container path
   - `docs/QA_LOG.md` — owner smoke `pmset -g assertions | grep` + `defaults delete` lines
   - `docs/site/privacy.html` — §3 storage path

5. **`MARKETING_VERSION 0.1.0 → 1.0.0`** in `project.yml` (`CURRENT_PROJECT_VERSION` stays `1` for first submission).

6. **GitHub username + repo placeholders swept** (`<github-username>` → `bj-park`, `<repo>` → `latte`, `<your-bundle-id>` → `com.parkbyeongjun.latte`) in `docs/site/README.md` and `docs/store/{support,marketing,privacy}-url.txt`.

7. **`docs/v2-backlog.md` V2-20/V2-21/V2-22**: explicit owner-revisit entries for the 3 defaults chosen this session (bundle ID prefix, git author identity, GitHub username/repo). Each entry includes the alternatives that were considered, the trigger for revisiting, and the exact action to take (file list to sweep) when the owner does.

8. **`02-architecture.md` v0.16 → v1.0** — design freeze gate. New v1.0 changelog entry summarizes all S8a deltas. `Last updated` 2026-04-27. `Successor docs` now includes `../v2-backlog.md`.

9. **`ROADMAP.md` row 8 split**:
   - **8a** (this session): Code & metadata prep — 🟢 Done
   - **8b** (next): Owner pre-flight smoke against the v1.0.0 build + screenshots + GitHub Pages deploy — 🟡 Next
   - **8.5** (after 8b): Apple Developer Program enrollment ($99/yr) — 🔴 Blocked owner-only HARD gate
   - **9** (after 8.5): App Store Connect setup + Release archive — ⚪ Pending
   - 10 (TestFlight beta) and 11 (submission + launch) renumbered accordingly.
   - New v1.0 entry added to `## Document version` table.

10. **`xcodegen generate`** ran clean against the new `project.yml`.

11. **Test regression check** — 263/263 tests pass (Debug config). Bundle ID change had no functional impact.

12. **Release config build verification** — `xcodebuild -configuration Release ... build` → `** BUILD SUCCEEDED **`. Verified built `.app` bundle:
    - `CFBundleIdentifier = com.parkbyeongjun.latte` ✅
    - `CFBundleShortVersionString = 1.0.0` ✅
    - `CFBundleVersion = 1` ✅

13. **Working folder rename `Caffeinated-Clone/ → Latte/`** at the OS level (`mv`). Git tracks files by content hash so this is invisible to history; future commits land under the new path. **Side effect**: this session's Bash tool cwd became stale after the rename, so the final commit had to be deferred to the owner — see "Final commit pending" below.

### Final commit pending (owner action)

The Bash tool's working directory cache became stale when the project folder was renamed mid-session. All file changes are on disk and the working tree is intact, but `git add` / `git commit` could not be executed from this session. **Owner runs the following from a fresh terminal**:

```bash
cd ~/Documents/Claude/Projects/Latte

git status   # should show many M files + ROADMAP/SESSION_HANDOFF + docs/v2-backlog.md
git add -A
git commit -m "$(cat <<'EOF'
feat: session 8a — bundle ID, version 1.0.0, folder rename, S8a metadata

Code & metadata prep for App Store submission. Dev-Program-free portion
of S8 — everything in this commit can be done before owner pays the
$99/yr Apple Developer Program fee.

- Bundle ID: com.example.latte → com.parkbyeongjun.latte
  (6 source/config sites + 4 design docs swept; default per V2-20).
- MARKETING_VERSION: 0.1.0 → 1.0.0 (first App Store version).
- Working folder: Caffeinated-Clone/ → Latte/ (cosmetic).
- ROADMAP row 8 split: 8a (this commit, Done) / 8b (owner smoke, Next)
  / 8.5 (Apple Dev Program enrollment, Blocked HARD).
- 02-architecture.md v0.16 → v1.0 (design freeze gate).
- v2-backlog.md V2-20/21/22 added — owner-revisit entries for the
  bundle ID prefix, git author identity, and GitHub username/repo
  defaults chosen this session.

Verified: xcodegen generate clean; 263/263 tests pass; Release config
build succeeded; built .app bundle has correct CFBundleIdentifier +
CFBundleShortVersionString.

S7.11 owner smoke checklist remains pending against v1.0.0 build.
S8.5 (Apple Dev Program) is the next HARD gate.
EOF
)"

git log --oneline -3   # should show this commit + 87d1eab + f1888dc
```

If the commit fails on hook, address the issue and re-stage (do not `--amend`). Once committed, this handoff is fully realized and S8a is closed.

### What's NOT done (intentional)

- **Owner pre-flight smoke (S8b)** — `docs/QA_LOG.md` §S7.11 checklist + the new screenshot capture pass per `docs/store/screenshot-guide.md`. Claude cannot drive the menu-bar UI; this is owner-only.
- **GitHub Pages deploy** — files in `docs/site/` are ready but the `bj-park/latte` repo's `gh-pages` branch (or a separate `latte-site` repo) must be created by owner. Verify `https://bj-park.github.io/latte/privacy.html` returns HTTP 200 before App Store submission.
- **Apple Developer Program enrollment** — $99/yr, 1-2 day approval. HARD gate for everything in S8.5+.
- **Bundle ID lock-in** — `com.parkbyeongjun.latte` is a default. Once submitted to App Store, bundle ID is **immutable** for the app's lifetime. Owner has one revisit window (V2-20) before S9 submission.
- **Git author rewrite for past commits** — the 8 S7-family commits + `87d1eab` were authored under the system username. Not rewriting history (V2-21 documents the choice).

---

## Decisions still pending owner approval

- **None blocking S8b.** Owner can run pre-flight smoke immediately.
- **Bundle ID lock-in confirmation** before S9 (App Store Connect record creation). This is the last revisit window per V2-20.

---

## Known issues / debt

- **Bash tool cwd stale this session** — owner must run final `git commit` from a fresh terminal as shown above. New chat sessions will pick up the renamed folder cleanly.
- **`docs/QA_LOG.md` smoke checklist still owed** — same as before, now superseded by the v1.0.0 build re-smoke for S8b.
- **EKCalendar list picker** (V2-04), **per-Focus selection** (V2-03), **`Theme.Colors.accentAwake` cleanup** (V2-10), **menu-bar awake-state visualization** (V2-01) — all formally in `docs/v2-backlog.md`. None block App Store submission.

---

## Files changed this session (cumulative across both planned commits)

### Already in `87d1eab`

```
A  docs/v2-backlog.md                          (initial 7-item backlog)
A  docs/site/index.html
A  docs/site/privacy.html
A  docs/site/README.md
A  docs/store/README.md
A  docs/store/app-name.txt
A  docs/store/subtitle-en.txt
A  docs/store/subtitle-ko.txt
A  docs/store/promotional-text-en.txt
A  docs/store/promotional-text-ko.txt
A  docs/store/description-en.md
A  docs/store/description-ko.md
A  docs/store/whats-new-en.md
A  docs/store/whats-new-ko.md
A  docs/store/keywords-en.txt
A  docs/store/keywords-ko.txt
A  docs/store/category.txt
A  docs/store/pricing.txt
A  docs/store/support-url.txt
A  docs/store/marketing-url.txt
A  docs/store/privacy-url.txt
A  docs/store/privacy-data.md
A  docs/store/age-rating.md
A  docs/store/review-notes.md
A  docs/store/screenshot-guide.md
A  docs/store/screenshots/.gitkeep
```

### Pending S8a-final commit (working tree)

```
M  project.yml                                 (bundleIdPrefix, 2× PRODUCT_BUNDLE_IDENTIFIER, MARKETING_VERSION)
M  Sources/Core/Logging.swift                  (subsystem string)
M  Sources/Core/PowerAssertion.swift           (subsystem string)
M  Sources/Core/SettingsStore.swift            (subsystem string)
M  docs/design/01-PRD.md                       (working folder note, bundle ID, R-09)
M  docs/design/02-architecture.md              (v0.16 → v1.0, §6.2 logging snippet)
M  docs/design/04-data-model.md                (container path + defaults read example)
M  docs/QA_LOG.md                              (pmset / defaults delete commands)
M  docs/site/README.md                         (bj-park/latte URLs)
M  docs/site/privacy.html                      (§3 storage path)
M  docs/store/support-url.txt                  (bj-park/latte URL)
M  docs/store/marketing-url.txt                (bj-park/latte URL)
M  docs/store/privacy-url.txt                  (bj-park/latte URL)
M  docs/v2-backlog.md                          (+ V2-20/21/22 owner-revisit entries)
M  ROADMAP.md                                  (working folder header, row 8 split, v1.0 changelog entry)
M  docs/SESSION_HANDOFF.md                     (this file, S8 → S8a/8b)
~  Latte.xcodeproj                              (gitignored — re-run xcodegen if needed)
```

---

## How to resume

```bash
cd ~/Documents/Claude/Projects/Latte
git status         # Verify the S8a-final commit landed (or do it now per the block above)
git log --oneline -3
xcodebuild test -scheme Latte -destination "platform=macOS,arch=arm64" 2>&1 | tail -5
```

If totals match S8a (263/263 tests, build succeeds), proceed to "Next session entry point" below.

---

## Next session entry point

**Theme**: S8b — Owner pre-flight smoke + GitHub Pages deploy + screenshot capture. **No Dev Program required.**

### Pre-session prerequisites (owner)

- [ ] Final S8a commit landed (per "Final commit pending" block above).
- [ ] Re-built `Latte.app` from the Release config: `xcodebuild -scheme Latte -configuration Release -destination "platform=macOS,arch=arm64" build`. Run `~/Library/Developer/Xcode/DerivedData/Latte-*/Build/Products/Release/Latte.app`.

### To-do (in order)

#### 1. S7.11 re-smoke against v1.0.0 build (~30 min, owner-only)

Run through `docs/QA_LOG.md` §S7.11 checklist plus the post-S7.10 owner smoke checklist. Particular attention to:
- Calendar / WiFi / Focus Toggle OFF → ON cycles (S7.11 fixed the latent stream-finish bug for these).
- AppIcon visible at 16/32/128 sizes in Finder/Dock.
- App trigger (S7.8/9/10 fixes) still intact.
- `pmset -g assertions | grep -i com.parkbyeongjun.latte` shows the assertion when active and zero when off.

If P1 surfaces, fix-first then continue. If clean, tick the checklist in `QA_LOG.md` and commit.

#### 2. Capture marketing screenshots (~90 min, owner-only)

Per `docs/store/screenshot-guide.md` — 5 shots at 2880×1800 against the Release build. Drop into `docs/store/screenshots/` with the prescribed filenames (`01-hero.png` … `05-about.png`). Pre-upload checklist in the same file. Commit when done.

#### 3. Deploy GitHub Pages (~30 min, owner)

Create `bj-park/latte` repo on GitHub if not already there. Push the local repo. Then per `docs/site/README.md` Option A (or Option B if owner prefers separate repo):

```bash
git checkout --orphan gh-pages
git rm -rf .
cp -r docs/site/* .
git add index.html privacy.html README.md
git commit -m "site: initial Latte marketing + privacy"
git push -u origin gh-pages
git checkout main
```

Then GitHub Pages settings → Source = `gh-pages` branch → root.

Verify:
```bash
curl -sI https://bj-park.github.io/latte/privacy.html | head -5
# Must show: HTTP/2 200 + content-type: text/html
```

#### 4. Wrap S8b (~15 min)

- Tick the smoke checklist in `docs/QA_LOG.md`.
- Update `docs/store/{support,marketing,privacy}-url.txt` if final hosted URLs diverge from the default `bj-park.github.io/latte/`.
- ROADMAP row 8b → 🟢 Done; row 8.5 → 🟡 Next (owner ready to enroll).
- Overwrite this `SESSION_HANDOFF.md` for S8.5 entry.
- Commit as `feat: session 8b — owner pre-flight smoke + screenshots + GitHub Pages live`.

### Cannot-start-without checks

- S8a-final commit landed (per "Final commit pending" above).
- Owner has GitHub account + write access to a repo for the marketing site.

If any pending, do not start S8b.

---

## Recap quick stats

- 263 tests, all passing.
- Core/ + Triggers/ all ≥ 80% coverage.
- 0 P1 defects logged (S7.11 smoke checklist still owed against v1.0.0 build).
- 0 architectural changes since S7.11; only metadata + bundle ID + version + folder.
- 2 commits planned for S8a: `87d1eab` landed; S8a-final pending owner.
- Working folder is now `Latte/`. The path `~/Documents/Claude/Projects/Caffeinated-Clone/` no longer exists.
