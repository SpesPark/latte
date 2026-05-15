# Translations

Latte ships with 11 languages: English (source), Korean, Japanese,
Simplified Chinese, Traditional Chinese, Spanish, German, French,
Brazilian Portuguese, Italian, and Russian.

| Code | Language | Quality bar |
|---|---|---|
| `en` | English | Source — written by the developer |
| `ko` | 한국어 | Hand-reviewed by the developer (native speaker) |
| `ja` | 日本語 | Machine-assisted, awaiting native review |
| `zh-Hans` | 简体中文 | Machine-assisted, awaiting native review |
| `zh-Hant` | 繁體中文 | Machine-assisted, awaiting native review |
| `es` | Español | Machine-assisted, awaiting native review |
| `de` | Deutsch | Machine-assisted, awaiting native review |
| `fr` | Français | Machine-assisted, awaiting native review |
| `pt-BR` | Português (Brasil) | Machine-assisted, awaiting native review |
| `it` | Italiano | Machine-assisted, awaiting native review |
| `ru` | Русский | Machine-assisted, awaiting native review |

The 9 "machine-assisted" translations were drafted with LLM assistance
following Apple's official platform terminology (System Settings →
Privacy & Security per locale, etc.). They are **shipping** so that
non-English speakers can use Latte today in their language, but a
native speaker's eye will catch awkward phrasings, terminology drift,
or outright errors that the drafting pass missed.

**Community PRs improving these translations are welcome and
appreciated.**

## How to suggest an improvement

### Option A — Open an issue (no Git needed)

Use the [**Translation improvement**](../../issues/new?template=translation_improvement.md)
issue template. Paste the current string and your suggested string,
write one or two sentences on why your version is better, and submit.

This is the lowest-friction path. If you have suggestions for multiple
strings, one issue per string is cleanest — but a single issue with a
list is also fine.

### Option B — Open a Pull Request

If you'd like to edit the catalog directly:

1. The catalog lives at [`Resources/Localizable.xcstrings`](Resources/Localizable.xcstrings)
   (Apple's String Catalog format, JSON-encoded).
2. Open it in Xcode 26+ (visual editor) **or** edit the JSON directly
   — both are equivalent.
3. Locate your language code under `strings → <key> → localizations
   → <lang>` and edit the `value` field.
4. Open a PR. CI will run `LocalizationCatalogTests` which asserts that
   every key has translations for all 11 languages — if you accidentally
   delete a translation, the test fails with a per-language gap report.

### What to look for

- **Terminology consistency with macOS** — when the string references a
  macOS surface (e.g. "System Settings → Privacy & Security"), use the
  exact wording from Apple's official localization of that surface, not
  a fresh translation.
- **Brand names stay untranslated** — `Latte`, `Mac`, `Wi-Fi`,
  `SF Symbols`, `Esc`. (The "Latte" word in the copyright line is the
  app name, not the drink.)
- **Tone** — Latte's source English is concise and slightly informal.
  Translations should match (avoid overly formal register unless the
  language strongly prefers it for UI text).
- **Length** — UI strings are constrained by layout. Roughly matching
  the source string length avoids truncation in tight menu rows.

## How translations are tested

`Tests/LocalizationCatalogTests.swift` runs on every build:

- `testEveryEntryCoversAllPhaseHLanguages` — every key must have a
  non-empty translation for all 11 languages. Failure reports the
  per-language gap as `[Lang: [Key]]`.
- Other tests verify catalog file shape and key uniqueness.

Run locally:

```bash
xcodebuild test -scheme Latte \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:LatteTests/LocalizationCatalogTests
```

## Adding a brand-new language

If you'd like to add a 12th language not currently in the list, please
open an issue first so we can coordinate — adding a language touches
the catalog, the `LanguagePreference.supported` list, and the
onboarding/Settings pickers. A PR is welcome after the issue
discussion.

## Acknowledgement

Latte's bulk translation pass in S32 (Phase H) was drafted with LLM
assistance over a single afternoon. The developer's view: shipping a
machine-assisted-but-honest translation is better than shipping
English-only and forcing non-English speakers to wait for a "perfect"
release that never arrives. The bar is then continuously raised by
native-speaker community feedback.

If your language is on the list and you noticed something off —
thank you in advance for helping improve it.
