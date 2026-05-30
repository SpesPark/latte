# App Store Screenshots — generated S50 (2026-05-30)

Eight **2880 × 1800** (16" MacBook Pro Retina), sRGB, no-alpha PNGs ready for App
Store Connect upload. Generated automatically (Claude Code drove the app via the
`latte://` URL scheme + a status-item click + `screencapture -l <windowID>`,
then composited each window onto a brand-gradient canvas). The owner's real
Latte preferences and activity log were snapshotted before capture and restored
after — nothing was left modified.

| File | Content | Source |
|---|---|---|
| `01-cup.png` | Coffee-cup brand hero (mid-fill, caramel, awake) | `latte://demo/cup?fill=0.55&accent=caramel&awake=true` |
| `02-menubar.png` | **Core feature, ACTIVE** — menu-bar popover in the awake state ("Latte is awake", Indefinitely ✓, Turn off enabled) with the full keep-awake duration menu | `activateOnLaunch=true` + status-item click |
| `03-triggers.png` | Triggers tab — automatic context detection (Calendar + apps) | `latte://settings/triggers` |
| `04-general.png` | General tab — Behavior, ⌘⇧L shortcut | `latte://settings/general` |
| `05-activity.png` | Activity tab — usage history charts (24 h + 14 d, per-trigger) | `latte://settings/activity` (seeded demo history) |
| `06-accents.png` | **Six coffee tones** — the cup in all 6 accent colors (Espresso / Caramel / Mocha / Latte / Matcha / Noir), composited into one tile | 6× `latte://demo/cup?accent=…&awake=true` |
| `07-language.png` | First-run language picker — 11 languages | onboarding (firstRunCompleted=false) |
| `08-about.png` | About — Latte 1.0.0, privacy posture | `latte://settings/about` |

All shots use the **English** UI (`AppleLanguages = (en)`). The menu-bar /
settings / language shots use the **caramel** accent; `06-accents.png` shows all
six. The Activity shot is populated with **synthetic, privacy-safe** history
(only trigger IDs + on/off + timestamps — the same non-PII fields the app
actually persists); the owner's real activity log (empty) was restored after.

## Recommended ordering for App Store Connect

`01 cup` (brand) → `02 menubar` (**the core promise: keep your Mac awake**) →
`03 triggers` (automation wedge) → `04 general` → `05 activity` →
`06 accents` (personalization) → `07 language` → `08 about`. Apple accepts 1–10;
reorder freely in ASC.

## Before uploading

1. **Review each PNG** — confirm framing reads well at thumbnail size.
2. Optionally add marketing captions or a separate App-trigger close-up cropped
   from `03-triggers.png`.

## Regenerate

```bash
bash _scripts/capture.sh          # raw window/popover/activity/accent PNGs into /tmp/latte-shots (snapshots + restores app state)
python3 _scripts/composite.py     # 7 single-window shots -> /tmp/latte-shots/final
python3 _scripts/accent-grid.py   # 06-accents.png (6-cup grid) -> /tmp/latte-shots/final
for f in /tmp/latte-shots/final/*.png; do
  sips -m "/System/Library/ColorSync/Profiles/sRGB Profile.icc" "$f" >/dev/null
  cp "$f" .
done
```

Requirements: the **Debug** build at the path in `capture.sh`; **Screen
Recording** + **Accessibility** permissions for the capturing process (both
granted on the owner's Mac as of S50 — the menu-bar popover needs an
Accessibility-driven status-item click); Python 3 + Pillow for compositing.
`capture.sh` backs up and restores the defaults domain and the sandbox-container
`activity-log.json`, and resets the temporary `activateOnLaunch` flag used for
the awake menu-bar shot.
