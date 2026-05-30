# App Store Screenshots — generated S50 (2026-05-30)

Five **2880 × 1800** (16" MacBook Pro Retina), sRGB, no-alpha PNGs ready for App
Store Connect upload. Generated automatically (Claude Code drove the app via the
`latte://` URL scheme + `screencapture -l <windowID>`, then composited each
window onto a brand-gradient canvas). The owner's real Latte preferences were
snapshotted before capture and restored after — they were not disturbed.

| File | Content | App state |
|---|---|---|
| `01-cup.png` | Coffee-cup brand hero (mid-fill, caramel, awake) | `latte://demo/cup?fill=0.55&accent=caramel&awake=true` |
| `02-triggers.png` | Triggers tab — Calendar + Running apps enabled | `latte://settings/triggers` |
| `03-general.png` | General tab — Behavior, ⌘⇧L shortcut | `latte://settings/general` |
| `04-language.png` | First-run language picker — 11 languages | onboarding (firstRunCompleted=false) |
| `05-about.png` | About — Latte 1.0.0, "No data" posture | `latte://settings/about` |

All shots use the **English** UI (`AppleLanguages = (en)`) and the **caramel**
accent.

## Before uploading to App Store Connect

1. **Review each PNG** — confirm framing/content reads well at thumbnail size.
2. Apple accepts 1–10 shots; these 5 cover hero + automation + controls + i18n +
   privacy. Reorder in ASC if you prefer a different first impression.
3. Optional **Shot 4 (App-trigger close-up)**: crop the "Running apps" section
   out of `02-triggers.png`, or capture manually per `../screenshot-guide.md`.

## Regenerate

```bash
# 1. capture raw window PNGs into /tmp/latte-shots (snapshots + restores defaults)
bash _scripts/capture.sh
# 2. composite onto 2880x1800 canvases into /tmp/latte-shots/final
python3 _scripts/composite.py
# 3. embed sRGB + copy here
for f in /tmp/latte-shots/final/*.png; do
  sips -m "/System/Library/ColorSync/Profiles/sRGB Profile.icc" "$f" >/dev/null
  cp "$f" .
done
```

`capture.sh` points at the Debug build path and requires **Screen Recording**
permission for the capturing process (already granted on the owner's Mac as of
S50). `composite.py` needs Python 3 + Pillow.
