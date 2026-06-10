# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

**Last session:** S52 (2026-06-10) — **Track F i18n adversarial quality review.** Owner picked Track F from the S51 queue. 10 parallel per-language native-reviewer agents over the machine-written catalog (172 keys × 11 languages), findings verified against the actual catalog before applying, 102 value fixes in one data-only commit. Several agent findings **rejected as false positives** after verification (see below — the review-the-reviewer step caught real agent errors).
**v1.x release line:** v1.9 (unchanged). **Public App Store version = 1.0.0.**
**Branch:** `claude/focused-hamilton-417bfc` — S52 adds `56498c2` (Track F fix) + wrap, then the **post-wrap A1/A2/A3 round**: `dc2cdbf` rebrand-prep kit (`scripts/rebrand.sh` + `docs/rebrand-checklist.md` — 상호 확정 시 ~5분 작업), `a7be73f` store-copy↔binary truth guard in `check_doc_drift.sh` (mutation-tested; S51 Track C can't regress), `86cd3fc` TRANSLATIONS.md review-status + protected-choices list. **PR #1 OPEN** (`https://github.com/SpesPark/latte/pull/1`) — not merged (owner decides). Pushed; PR auto-updates.
**Test count:** **713 verified + 4 authored-but-NOT-yet-run** (B1 `872a38a` — trap #9 hit mid-session; see ⚠ below). README intentionally still says 713 — bump to 717 only after the suite actually runs green.
**Builds:** Track F test run green attempt 1; after B1: default + flag-on builds **0 warnings** + build-for-testing compiles, but **`scripts/run_tests.sh` could NOT run (pty exhausted, 527 orphans — reboot only)**. **Doc-drift + store-limits:** clean.

> ## ⚠ S53 MUST DO FIRST (before any other work)
> 1. Owner reboots / relogs (trap #9 — pty exhausted at S52 end).
> 2. `scripts/run_tests.sh` — **expect 717/717** (713 + 4 AwakeTimerWiringTests).
> 3. If any of the 4 new tests are red: fix-first on `872a38a` (seam: `AwakeManager.init sleeper` param + `timerTask(for:)` internal accessor + `Tests/AwakeTimerWiringTests.swift`). Do NOT stack new work on an unverified suite.
> 4. Then bump README test count 713 → 717.
**Catalog:** 172 keys × 11 languages — same shape, 102 values improved. **Toolchain:** Xcode 26.5 / Swift 6.3.2 / macOS 13 target.

---

## S52 what landed

### Method (reusable for future i18n passes)

1. Extracted per-language review sheets (`/tmp/latte-i18n-review/<lang>.md`: key + context comment + en source + target, plural forms inlined) so each agent reviews ~27 KB instead of the 333 KB xcstrings.
2. 10 parallel Explore agents (ko/ja/zh-Hans/zh-Hant/de/es/fr/it/pt-BR/ru), each prompted as a native-speaker macOS localizer with Apple per-language conventions + CLDR plural rules, returning `KEY | SEV | ISSUE | FIX` lines.
3. **Every finding verified against the actual catalog before applying** — agents quote from sheets and sometimes hallucinate or get grammar wrong (see rejections).
4. Fix script used **substring-assert replacements** (`old in value` or hard abort) — any agent misquote aborts instead of corrupting the catalog. Plus two scripted normalization passes (ja katakana, CJK punctuation).
5. Gates: placeholder-multiset en↔target over all changes (0 mismatches), leftover-punct scan (0), English-leftover scan (0), `run_tests.sh` 713/713, doc-drift `--strict` clean.

### Applied (102 values, `56498c2`)

- **Cross-language systemic HIGH — untranslated English:** "awake/asleep" (global-shortcut description) and "awake (assertion)" (auto-start + battery descriptions) were left in English in **ko/ja/zh-Hans/zh-Hant/ru**. Now use each language's established state anchors, verified against the bare `Awake`/`Asleep` state-label keys: 깨어 있음/잠자기 · アクティブ/スリープ · 唤醒/睡眠 · 喚醒/睡眠 · активный/спящий режим.
- **ja:** トリガ → トリガー standardized (7 keys); `Awake — %@` 起動中 → アクティブ (now matches bare `Awake` = アクティブ).
- **ja/zh-Hans/zh-Hant punctuation normalization** (51 strings): `()` → （）, CJK-preceded `:` → ：, CJK-preceded `,` → ，. Comma rule is **CJK-before only** — a both-sides rule left mixed-width strings when Latin follows (`段内,Latte`); ⌘ (U+2318) is non-CJK so `⌘,` stays untouched.
- **zh-Hant:** mainland-isms 運行 → 執行 / 應用 → 應用程式 (3 keys); 保留歷史時間 → 保留記錄期限; 已選 %lld 個 → 已選取 %lld 項; 監看 → 監控.
- **ru:** “Расширенные” → “Дополнительно” (now matches the actual `Advanced — add by bundle ID` button = Дополнительно); `день(дни)` bracket plural → в выбранные дни.
- **de:** external-display strings unified on *Display* (Bildschirme → Displays, 3 keys); `Warm amber` Warmes Bernstein → **Warmer Bernsteinton** (gender agreement); no-op phrasing → "hat keine Wirkung".
- **es:** Apple-glossary **reposo** for sleep state (5 keys incl. `Asleep` Durmiendo → En reposo, `Sleep when on battery` → Reposo con batería).
- **fr:** ungrammatical "Lorsqu'activé" → "Lorsque cette option est activée" (2 keys); actif/dormant → actif/veille (matches `Asleep` = En veille).
- **it:** slash notation "nel/i giorno/i selezionato/i" → "nei giorni selezionati"; attivo/sospeso → attivo/stop (matches `Asleep` = In stop).
- **pt-BR:** **"A integração" was a mistranslation of "Onboarding"** → "A configuração inicial"; Dormindo → Em repouso; pt-PT word order "Permitir dormir a tela" → "Deixar a tela dormir".

### Rejected as FALSE POSITIVES (do not "re-fix" these)

- **ru agent HIGH on the external-displays plural** — claimed few/other "%lld внешних дисплея" should be "дисплеев". **WRONG**: Russian paucal (2–4) takes genitive *singular* (2 дисплея), and fractions (other) also take genitive singular. The catalog has been CLDR-correct since S36. ⚠ If a future i18n agent re-flags this, reject again.
- du/tú/你 informal-register complaints (de/es/zh agents) — the catalogs are internally consistent and modern Apple style IS informal in these languages.
- fr `Awake` = "Actif" relabel suggestion — catalog-wide Actif/Inactif consistency beats it.
- ja agent's suggestion to add a `one` plural form to Japanese — would violate CLDR (ja is other-only).

### Per-language agent grades (pre-fix, for the record)

ko D · ja C · zh-Hans D · zh-Hant C · de C+ · es D · fr C · it C+ · pt-BR B+ · ru C. The D/C grades were dominated by the systemic untranslated-awake/asleep issue + punctuation; after `56498c2` the flagged HIGH/MEDIUM classes are closed. Remaining LOW-grade polish (register nuances, individual word choices) is genuine native-speaker territory — community-PR contract in TRANSLATIONS.md still stands.

---

## Next-session entry points (priority order)

**A. (owner-decision queue — unchanged from S51):**
1. 🟠 **상호 (brand) decision** → bundle-ID rewire → publish (see DECISION PENDING below). **Rewire is now scripted** (S52 A1): `scripts/rebrand.sh com.<brand> --apply` + the manual steps in `docs/rebrand-checklist.md` (TCC re-grants, defaults migration, gh-pages redeploy).
2. `latte://demo` ships in Release — `#if DEBUG` wrap yes/no (screenshots/smoke depend on it; don't wrap casually).
3. PR #1 merge (no blockers in review).
4. WiFi When-In-Use device-verify (S50 T5 + S51 F2).

**B. (owner-approved in S52, partially landed):**
- ✅ **B1 clock seam — LANDED `872a38a`** (verification pending S53 reboot, see MUST DO above). `AwakeManager.init` gains injectable `sleeper` (defaults to `Task.sleep`); internal `timerTask(for:)` accessor; 4 end-to-end wiring tests (duration expiry / coolDown expiry / cancel-on-deactivate / reschedule-replaces). `.snooze` wiring not E2E-covered — unreachable from public API since P-issue-6c (pure-FSM tests own it).
- ⏳ **B3 chart POSIX locale** ([ActivityTab.swift:302](../Sources/UI/Settings/ActivityTab.swift) `en_US_POSIX`) — deferred to S53: no more Swift churn while the suite can't run. i18n cosmetic; charts show English dates in all 11 locales.
- ⏳ **B2 `IOPowerSource.fanOut` parity** — deferred (needs seam design; same no-churn reasoning).
- ❌ **B4 LOW bundle** (dead `?? presets[0]`, `@MainActor` consistency, `recordActivity` object-nil) — intentionally skipped; S50's "no churn during the App Store push" call stands.

**C. (gated) iCloud Phase 2/3 activation** — unchanged; S8.5 + container + entitlements switch + macOS-14 `@Model`. NOT autonomous. M2/L1/L4 contracts carried in source since S51.

**v1.x autonomous backlog is otherwise exhausted** — Track F was the last queued autonomous item. Anything further is community-PR refinement or owner-gated.

### 🟠 DECISION PENDING: brand (상호) / bundle ID — owner deciding, blocks first publish
Unchanged from S50/S51. Individual account ⇒ seller shows personal legal name; owner wants a brand ⇒ Org account (개인사업자 + D-U-N-S) later via App Transfer (must happen during v1.x, BEFORE iCloud Phase 2). Bundle ID is permanent post-publish ⇒ hold publishing until the 상호 is chosen, then grep-sweep rewire (`project.yml` / entitlements / Info.plist / `.smoke/config.yml` / `docs/store/*` / screenshots `_scripts` / defaults+container paths all hardcode `com.parkbyeongjun.latte`) → regenerate → signed-build verify → publish as Individual.

---

## Cold-start (다음 세션 진입)

```bash
# 0. PTY CHECK (trap #9) — only matters for TESTS. ⚠ S52 ended PTY-EXHAUSTED
#    (527 orphans) — if this fails, the owner must reboot/relogin first.
python3 -c "import os;[os.close(x) for x in os.openpty()]" && echo pty-ok || echo "PTY EXHAUSTED — reboot/relogin"

# 1. ⚠ CWD: a session restart RESETS Bash cwd to the repo root (main/S35 state!) — bit S51.
#    The ROOT checkout is stale; ALL work happens in this worktree. Verify pwd; prefer absolute paths or git -C.
cd /Users/parkbyeongjun/Documents/Claude/Projects/Latte/.claude/worktrees/focused-hamilton-417bfc && pwd

# 2. Doc/metadata gates (no pty, no build):
scripts/check_doc_drift.sh --strict && scripts/check_store_limits.sh --strict

# 3. If you touch Swift (regenerate first if you ADD/REMOVE a source/test file):
xcodegen generate
xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "warning:|BUILD"

# 4. Tests — PREFER the runner (absorbs the trap-#8 stall). ~20s, expect 717.
scripts/run_tests.sh
```

**Expect**: pty-ok (after owner reboot); **717/717 PASS** (713 verified + 4 unverified AwakeTimerWiringTests — if red, fix-first on `872a38a`); doc-drift + store-limits clean; 172 keys × 11 langs; `cloudSync` nil in the default build.

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` rows 1.51 → 1.52 (1.52 = this session's full detail incl. the rejected-false-positive list).
3. Memory: `MEMORY.md` → `project_latte_v1_9.md` (S51–S52 at the tail) + `project_latte_status.md` (traps; #8 = harness-absorbed, #9 = pty/reboot, cwd-reset-on-restart hazard) + `project_icloud_design_audit.md`.
4. For App Store work: `docs/store/` **in this worktree** is source-of-truth (root's copy is stale S35). Metadata says FIVE triggers and no export — do not "fix" it back (Focus = V2-03b, export removed S24).
5. For any future i18n agent pass: read the S52 "Rejected as FALSE POSITIVES" list first — especially the ru paucal genitive-singular point.

---

## Owner-side pending (App Store upload)

Unchanged from S51.

| # | What | Status |
|---|---|---|
| 0 | **상호 결정** → bundle-ID rewire → publish | 🟠 blocks everything below |
| 1 | merge PR #1 (owner call; no blockers in review) | owner |
| 2 | Small Business Program opt-in | owner |
| 3 | App ID register (after 상호/bundle-ID) | owner |
| 4 | Team ID / signing | ✅ DONE S50 (`4BXCVHZANL`) |
| 5 | ASC app record | owner |
| 6 | Screenshots 8 × 2880×1800 | ✅ DONE S50 (owner review framing) |
| 7 | ASC listing paste from `docs/store/*` (**worktree copy**) + $2.99 + privacy + age | owner |
| 8 | Archive → Validate → Upload → Submit | owner |
| — | WiFi When-In-Use device-verify | owner device smoke |
| — | `latte://demo` `#if DEBUG` wrap — yes/no | owner decision (S51 audit, MEDIUM) |

---

## v1.9 owner-visible behaviour reference (post-S52)

S52 is **translation-text-only** — no behaviour change, no English-UI change. Users of the 10 non-English languages see corrected strings (most visibly: the keyboard-shortcut settings description no longer contains English "awake/asleep"; ja menu-bar awake state now reads アクティブ consistently; zh punctuation is full-width; es sleep state reads "En reposo"). `cloudSync` nil, no CloudKit compiled, cup / menu bar / **5 registered triggers** (Focus = V2-03b) / Settings / Activity / ⌘⇧L unchanged.
