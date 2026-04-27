# App Store Metadata

Source-of-truth for everything that gets pasted into App Store Connect. Edit here first, copy into App Store Connect second. Owner verifies before paste.

## File map

| File | Purpose | Limit |
|---|---|---|
| `app-name.txt` | App display name | 30 chars |
| `subtitle-en.txt` / `subtitle-ko.txt` | Subtitle on the listing | 30 chars/locale |
| `promotional-text-en.txt` / `promotional-text-ko.txt` | Promo text (changeable without re-review) | 170 chars/locale |
| `description-en.md` / `description-ko.md` | Long description | 4000 chars/locale |
| `whats-new-en.md` / `whats-new-ko.md` | "What's New in This Version" | 4000 chars/locale |
| `keywords-en.txt` / `keywords-ko.txt` | Search keywords (comma-separated) | 100 chars/locale |
| `category.txt` | Primary + secondary category | n/a |
| `pricing.txt` | Tier + territories | n/a |
| `support-url.txt` | Support contact URL | n/a |
| `marketing-url.txt` | Marketing site URL | n/a |
| `privacy-url.txt` | Privacy Policy URL (required) | n/a |
| `privacy-data.md` | App Privacy declaration source-of-truth | n/a |
| `screenshots/` | 2880×1800 PNGs | per `screenshot-guide.md` |
| `age-rating.md` | Age Rating questionnaire answers | n/a |
| `review-notes.md` | Notes for App Store reviewer | n/a |

## Submission day workflow

1. Open App Store Connect → My Apps → Latte → Version 1.0.
2. For each field above, copy from the matching file here and paste into the corresponding App Store Connect field.
3. Upload all `screenshots/` PNGs in numbered order.
4. Pricing & Availability → set per `pricing.txt`.
5. App Privacy → declare per `privacy-data.md` (Apple's questionnaire format).
6. Age Rating → answer per `age-rating.md`.
7. App Review Information → paste `review-notes.md`.
8. Submit for Review.

## Why text files, not direct App Store Connect entry

- **Reviewable**: changes go through git, owner can diff before paste.
- **Localizable**: same shape per locale, easy to add Japanese/Chinese later.
- **Recoverable**: if App Store Connect drops state (it has, historically), re-paste is one minute.
- **Searchable**: `grep` works on the listing copy.
