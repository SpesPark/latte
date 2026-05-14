# Session Handoff

> **Always overwrite this file** at the end of each session. Long-lived plan lives in `ROADMAP.md`.

---

## Last session

| Field | Value |
|---|---|
| **Session #** | **S32** — i18n cluster close-out (Phases D + E + H + ko refinements) (2026-05-15, same-day continuation of S31). Owner direction at S32 start: "권장대로 진행" = full Option A loop in one session — push S31 to origin, do live ko review together (Option B from S31 owner-side queue), execute Phase H bulk LLM translation immediately after ko approval, wrap. S32 lands Phases D (Onboarding LanguageStep), E (Settings Language Picker), H (9 languages × 86 keys = 774 translations) + 3 ko refinements (`Enable` 사용 → 활성화, `Reset` 기본값 → 초기화, `Watched calendars` 감시 중인 → 관찰 중인) + extended `LocalizationCatalogTests` to assert 11-language coverage. v1.x i18n track now **fully landed**; only Phase I (P2 surface — MenuBar + Onboarding body + status notifications) remains for S33+. |
| **Theme** | "i18n cluster ships in a single session by riding the trust anchor pattern: owner reviews ko (the developer's own language, ~20 min), corrections feed back into the catalog, and only THEN does the LLM-batch fan out across 9 derived languages. The cost asymmetry is the whole point — translation errors in ko propagate as silent quality regressions across 9 languages, so spending 20 minutes to lock the anchor saves a 10× downstream debt. The Onboarding LanguageStep + Settings Picker land in the same cluster because they're the user-visible counterpart that makes the infrastructure discoverable — without a Picker, a Korean user with English macOS never sees the ko translations. Lesson: i18n is a 4-layer stack (infra → anchor lang → derived langs → UI surface), and shipping all 4 in one cluster is more efficient than the textbook 'translate first, UI later' since the UI is a 1-day delta and the QA loop is the same for all layers." |
| **Status** | ✅ **3 source commits** in S32 cluster: `95e4a6c` (Phase D + E) + `1284c9e` (Phase H + ko refinements) + this docs wrap. **Tests 594 → 607** (+13: +12 LanguagePreferenceTests, +1 testEveryEntryCoversAllPhaseHLanguages) in 10.5s. **Smoke 22/22** GREEN. **Working tree clean** after wrap. **xcstrings**: 86 keys × 11 languages = **all 940 cells populated** (en source + 10 translated languages). Catalog file size 22KB → 79KB. **Onboarding flow** now: `language → welcome → pickTriggers → done`. **Settings → General** gains Language section with Picker + "Restart Latte to apply." caption. |
| **Tail commits** | `95e4a6c` (S32 D+E) → `1284c9e` (S32 H + ko) → this S32 docs wrap. Preceded by S31 chain (`6c6f955` → `7842b60` → `e1a56a7`) and S30 chain (`afa1980` → `3a30e61` → `ad4cab6`). Origin/main synced. |

### What landed this session

| Phase | Work | Files | Tests Δ |
|---|---|---|---|
| **D — Onboarding LanguageStep** | New `.language` step prepended to wizard (welcome demoted to second). 11 native-name buttons in 2-column `LazyVGrid`, pre-selects user's current system language (`LanguagePreference.current()` → first-tap-continue UX for non-English users). Selection writes AppleLanguages immediately via `LanguagePreference.apply(_:)` — visible on next launch. Initial step state changed from `.welcome` to `.language`; Step.previous for `.language` returns self (no Back button on first step). `LanguageOnboardingButton` private subview with selected-state checkmark + accent border. | `Sources/UI/Onboarding/OnboardingView.swift` | +0 (UI behaviour covered by LanguagePreference unit tests) |
| **E — Settings Language Picker** | New Section between Appearance and Status. `Picker(selection: $selectedLanguage)` showing 11 native names (menu style), bound to `@State var selectedLanguage = LanguagePreference.current()`. `.onChange` writes through. Section footer: "Restart Latte to apply." | `Sources/UI/Settings/GeneralTab.swift` | +0 |
| **Core helper** | `LanguagePreference` — public enum namespace: `Option { code, nativeName }`, `supported: [Option]` (11, ko first, en second, then geographic/script proximity), `current(in:)` reads AppleLanguages with prefix-folding (ko-KR → ko, pt-PT → pt-BR), `apply(_:to:)` writes only if code is in supported list, `resolve(rawLanguages:)` pure overload for testability. | `Sources/Core/LanguagePreference.swift` (NEW) | +12 LanguagePreferenceTests |
| **ko refinements** | 3 owner-approved fixes: `Enable` 사용 → 활성화, `Reset` 기본값 → 초기화, `Watched calendars` 감시 중인 → 관찰 중인. (Other 83 ko translations confirmed during review.) | `Resources/Localizable.xcstrings` | 0 |
| **H — Bulk translations** | 86 keys × 9 languages (ja, zh-Hans, zh-Hant, es, de, fr, pt-BR, it, ru) = 774 new translation cells. Apple platform terminology follows official Apple localizations (System Settings → Privacy & Security per language; ja "システム設定 → プライバシーとセキュリティ", de "Systemeinstellungen → Datenschutz & Sicherheit", etc.). Brand names (Latte, Mac, Wi-Fi, SF Symbols, Esc) preserved untranslated. Copyright string translated everywhere except ja (Apple convention keeps "All rights reserved" English in JP locale). | `Resources/Localizable.xcstrings` | 0 |
| **F — Test contract extended** | `testEveryEntryCoversAllPhaseHLanguages` — builds `gaps: [Lang: [Key]]` and asserts empty; surfaces drift per-language if a new key lands without translations. Doc comment updated to reflect Phase H landed (was "9 other languages NOT asserted; community PR welcome"). | `Tests/LocalizationCatalogTests.swift` | +1 (594 → 607 in cluster, after also adding +12 LanguagePreferenceTests) |

### Patterns reinforced this session

- **`UserDefaults(suiteName:)` chains through `NSGlobalDomain` for system-defined keys** — system keys like `AppleLanguages` are not isolated by a fresh suite domain; they fall through to the host machine's system value. **How to apply**: when unit-testing a helper that reads a system-defined UserDefault, split the API into (a) a `current(in defaults:)` form that walks UserDefaults and (b) a pure `resolve(rawValues:)` form that operates on already-extracted values. Tests use the pure form so they don't depend on the test host's macOS language setting. Without this, the test passes on en-US machines and silently fails on the owner's ko-KR machine (or vice versa).
- **Region-tagged language code fall-through (`ko-KR → ko`, `pt-PT → pt-BR`, `zh-HK → zh-Hans`)** — macOS often stores AppleLanguages as region-tagged variants depending on where the user picked their language in System Settings. The catalog uses bare BCP-47 codes (or single-variant tags like `pt-BR`). Resolver must fold region tags to the closest supported code by matching language prefix on either side of the `-`. **How to apply**: for any "current locale → supported list" lookup, always do exact match first, then prefix-prefix match (both sides, since the system value and your catalog code may each carry a different region suffix). Return source language ("en") as final fallback.
- **Step enum prepend pattern for onboarding flow** — adding a new first step to an existing wizard requires: (a) `enum Step` case prepended, (b) `@State step` initial value changed to new case, (c) `previous` returns self for new first case (no Back button), (d) `advance()` switch case added for new step → existing first, (e) footer Back-button guard `step != .newFirst && step != .oldFirst`. Surgical, ~10 LoC of state plumbing in addition to the new step's content view. **How to apply**: this same pattern works for *any* wizard step insertion (not just first); update Step.previous + Step's neighbours in `advance()` only.
- **Bulk LLM translation as a hand-writable Python script with a dict literal** — for P1 ship of N keys × M languages, writing the translations as a `T = {key: {lang: value, ...}, ...}` Python dict in a single throwaway script (then JSON-merging back into xcstrings) is faster + more reviewable than per-cell tool calls. 774-cell dict ≈ 700 lines of source, 30-60 min owner-pair to draft + review. Script enforces invariants (every key in catalog has T entry, every T entry has all 9 langs) before writing. **How to apply**: when bulk-translating, never round-trip per-cell through the editor — write one script with all translations in a dict, validate completeness, write file once.
- **Per-language gap-report test pattern** — instead of asserting "all langs present for all keys" as a binary, build a `gaps: [Lang: [Key]]` dict and fail with the structured diff. When the test fails on a new key, the message tells you exactly which languages are missing it — no need to re-run with different log levels or instrument the test. **How to apply**: for any multi-dimensional coverage assertion (matrix invariants), accumulate gaps into a dict keyed by the missing dimension's identity, then assert empty. Failure message is actionable as-is.

### What was checked but not changed

- 607/607 tests + smoke 22/22 — confirmed green after each S32 commit.
- 86-key ko translation pass — 83 of 86 confirmed accurate; only 3 refined.
- New onboarding/settings UI strings (4: "Choose your language", restart caption, "Language" header, footer) intentionally NOT yet wrapped in `String(localized:)` — keeps owner's catalog review noise-free; can be folded in alongside Phase I.
- `.environment(\.locale, ...)` propagation **not added** — verified that `String(localized:)` lookups consult Bundle.main resolved at launch, not the SwiftUI environment locale. Live in-app language switching would require Bundle reload (risky) or app relaunch. Restart-required UX is the honest path.
- Apple Dev Program S8.5 / ASC S9 — unchanged from S31. Day 13 of Apple wait.

### What was deferred to a later session

- **Phase I — P2 surface expansion** (S33+) — localize MenuBar (HeaderView, DurationPickerRow, CustomDurationRow, RecurringQuickPresetRow, MenuBarRoot) + Onboarding wizard body strings (welcome/pickTriggers/done step copy currently English literals) + status notifications + remaining ActivityTab strings + remaining TriggerConfigForms strings. Onboarding/Settings i18n-specific new strings (4) bundled into Phase I.
- **README disclaimer + GitHub issue template for translation PRs** — community-PR flow for 9 LLM-derived languages. Should land before public v1.0 ship; can be deferred until S8.5/S9 unblock to align with release timing.
- **Apple Dev Program S8.5 / ASC S9** — owner-blocked, unchanged.

The v1.x autonomous-coding backlog after S32:
- **Owner-blocked (Apple-side wait)**: S8.5 (Apple Dev Program review), S9 (depends on S8.5).
- **No owner action needed**: i18n cluster fully closed. ko anchor approved, 9 derived langs populated, UI surface (Onboarding + Settings) landed, test coverage extends to 11 langs.
- **Single autonomous candidates**: Phase I (S33), README + issue template (S33+), v2-backlog non-i18n items (cross-project rebuild-gate lift-and-shift, smoke scenario symmetric extension, C-3 iCloud sync, B1.2 deferred, V2-06 deferred, optional matcha smoke scenario).

---

## Next-session entry points (priority order)

**1. (BLOCKER, owner-side)** **S8.5 Apple Developer Program** — Day 13 of Apple wait. Action: check email + portal. If still pending past Day 14, call Developer Support.

**2. (BLOCKER, owner-side)** **S9 App Store Connect metadata** — depends on S8.5.

**3. (NEW)** **Phase I — P2 surface expansion** (S33 candidate). Adds `String(localized:)` wrap to remaining UI surface (~80 call sites across MenuBar + Onboarding body + ActivityTab + TriggerConfigForms). Each call adds a key to xcstrings + 11 translations. Estimated effort: 1-2 sessions depending on appetite for review pauses.

**4. (NEW)** **README disclaimer + community translation PR template** — short doc work. Adds "machine-assisted translations; community PRs welcome" note + GitHub issue template for "Help improve translations". ~30 min, no code change.

**5.** Other deferred items unchanged: cross-project rebuild-gate lift-and-shift, smoke scenario symmetric extension, C-3 iCloud sync, B1.2 deferred, V2-06 deferred, optional matcha smoke scenario.

S32 closes the i18n P1 + P2-anchor + bulk-translation trio in one cluster. v1.x version unchanged at v1.9 (matcha + i18n are pre-launch additions, all part of v1.0 launch state since v1.0 hasn't shipped). Owner-blocked queue narrows to S8.5 Apple + S9 ASC only.

---

## Cold-start (다음 세션 진입)

S31 added one-command cold-start ritual at [`scripts/latte-resume.sh`](scripts/latte-resume.sh).

```bash
# One-command resume
latte             # if zsh alias from S31 is installed
# OR
bash ~/Documents/Claude/Projects/Latte/scripts/latte-resume.sh
```

To run tests / smoke after the resume check:

```bash
# Tests (~10s, expect 607 PASS)
xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed"

# Smoke harness (~6-7min, expect 22/22 PASS, SERIAL with xcodebuild)
~/dev/smoke-harness/run.sh --project .

# Start Claude Code in this directory
claude
```

**Manual fallback** (if the script is missing):

```bash
cd ~/Documents/Claude/Projects/Latte
pkill -9 -f "Latte.app" 2>/dev/null
git log --oneline -8
[ -d Latte.xcodeproj ] || xcodegen generate
git remote -v
curl -s -o /dev/null -w "Pages /: %{http_code}\n" https://spespark.github.io/latte/
python3 -c "import json; d = json.load(open('Resources/Localizable.xcstrings')); print(f'{len(d[\"strings\"])} keys × 11 langs')"
```

**Expect**: 86 keys × 11 languages all populated (en source + 10 translated); 607/607 tests PASS; smoke 22/22 PASS.

**S32 NEW useful**:
- `python3 -c "import json; d = json.load(open('Resources/Localizable.xcstrings')); langs = sorted({l for k in d['strings'].values() for l in k.get('localizations', {})}); print('11-lang coverage:', langs)"` — verify 11-language fan-out
- `xcodebuild test ... -only-testing:LatteTests/LocalizationCatalogTests` — fast 8-test catalog verification (~2s)
- `xcodebuild test ... -only-testing:LatteTests/LanguagePreferenceTests` — 12-test runtime-helper verification

---

## How to resume

1. Read this file first.
2. `ROADMAP.md` row 31 (S31), row 30 (S30), row 29 (S29). (Row 32 / S32 to be appended on next docs pass.)
3. Memory: `~/.claude/projects/.../memory/MEMORY.md` → drill into `project_latte_v1_9.md` for S20→S32 section.
4. **Don't** re-read S1-S11 memory entries — consolidated during S13.

---

## Owner-side pending (S32 update)

| # | What | Why blocked | Effort |
|---|---|---|---|
| ~~ko review~~ | ~~Review xcstrings ko~~ | ✅ DONE in S32 — 3 refinements applied | — |
| S8.5 | Apple Developer Program — applied 2026-05-02 | Awaiting Apple review (Day 13). Owner should check email + portal | 1-2 days (typical) |
| S9 | App Store Connect 메타 입력 + screenshots upload + binary submission | S8.5 의존 | varies (1-3 sessions once S8.5 unblocks) |
| Phase I | P2 surface expansion (MenuBar + remaining UI) | Can start S33 — no owner direction needed | 1-2 sessions |
| Community PR | README + GitHub issue template for translation refinement | Optional; can defer until S8.5 unblocks | 30 min |

---

## v1.9 owner-visible behavior reference (post-S32)

S32 lands the **first user-visible i18n change**: Onboarding wizard now opens with a language selection step (11 native-name buttons), and Settings → General gains a Language section with a Picker + "Restart Latte to apply." caption. Selecting a non-English language writes `AppleLanguages` UserDefault; the chosen language takes effect on next app launch (Bundle.main locale is resolved at startup).

ko macOS users now see fully Korean Settings UI on launch. Users picking ja/zh-Hans/zh-Hant/es/de/fr/pt-BR/it/ru via the Picker see machine-assisted translations of the same surface (P1 = Settings strings + accent names + assertion-status strings; P2 surface remains English pending Phase I).

Carryover from S31 (unchanged for users — i18n infra was invisible until S32):
- 86 keys × 11 languages in `Resources/Localizable.xcstrings`.

Carryover from S30:
- Settings → General → Appearance → Coffee tone now 6 options (espresso, caramel, mocha, latte, **matcha**, noir).

Carryover from earlier sessions — unchanged: Activity tab fixes (S25/S24); Recurring Quick presets active marker (S23); "Until X" wall-clock caption (S23); ⌘Q/⌘, popover passthrough (S26/S27); v1.0~v1.8 owner-visible feature set; S22 fixes.

---

## ⌘⇧L behaviour reference

Unchanged. `AwakeManager.toggle()` already implements correct semantic.

---

## Smoke harness + GitHub repo / Pages infrastructure reference

Unchanged from S29/S30/S31. Pages live at https://spespark.github.io/latte/ + /privacy.html.
