# Screenshot Capture Guide — App Store Marketing Assets

> Owner-facing checklist for capturing the marketing screenshots that ship with the App Store listing. All assets land in `docs/store/screenshots/` for review before App Store Connect upload.

---

## Required output

Apple accepts these macOS screenshot dimensions (all 16:10 Retina):

| Resolution | Marketing label | Required? |
|---|---|---|
| **2880 × 1800** | 16" MacBook Pro Retina | **Yes (primary)** |
| 2560 × 1600 | 13" MacBook Air Retina | Optional (auto-down-scaled) |
| 1440 × 900 | Non-Retina fallback | Skip — Apple auto-generates |

You only need to capture **2880 × 1800** for v1.0. App Store Connect down-scales for the smaller display tiers.

**Format**: PNG (no JPEG). 8-bit RGB, sRGB color space. No transparency on the outer canvas.

**Count**: minimum 1, maximum 10. Recommend 4-5 (the same shots used in marketing site).

---

## Settings tabs auto-open via `latte://` URL scheme (S8c, 2026-04-28)

Latte 1.0 ships with two URL families. The harness (or you, manually) can deep-link straight in without any clicks:

```bash
# Settings tabs (real production windows)
open -a "<path-to-Latte.app>" latte://settings/general    # Shot 2
open -a "<path-to-Latte.app>" latte://settings/triggers   # Shot 3
open -a "<path-to-Latte.app>" latte://settings/about      # Shot 5

# Demo cup (deterministic capture surface)
open -a "<path-to-Latte.app>" "latte://demo/cup?fill=0.55&accent=caramel"  # Shot 1
```

## Window-id capture is now Claude-immune (S8c, 2026-04-28)

Marketing scenarios use `screencapture -l <CGWindowID>` instead of full-screen capture. Owner does NOT need to close Claude / Bartender / always-on-top windows anymore — the window-id capture grabs Latte's pixels even when other windows obscure it.

Scenarios:
- `09-marketing-shot-2-general` → Shot 2 captured automatically
- `10-marketing-shot-3-triggers` → Shot 3 captured automatically
- `11-marketing-shot-5-about` → Shot 5 captured automatically
- `12-marketing-shot-1-cup` → Shot 1 captured automatically (demo cup window)

Run all four with:
```bash
~/dev/smoke-harness/run.sh --project ~/Documents/Claude/Projects/Latte
# Shots end up in .smoke/artifacts/{09,10,11,12}-*.png
```

**Shot 4 (App trigger close-up)** has two acceptable paths now:

1. **Reuse `10-shot-3-triggers.png` cropped** — scenario 10 already enables Calendar + App + Wi-Fi triggers, with App section's `enabled = true` toggling its config form open. Cropping the App section out of that PNG is App Store-acceptable.
2. **Owner manual** (~30 s): use the harness output from `06-marketing-prep` as the prepared state, then click the "Add from running apps" Menu and capture. SwiftUI `Menu`'s hover/highlight state is not externally controllable without Accessibility-mediated `cliclick`, and lifting that state into URL parameters would mean ~150 LOC of production code change for a single screenshot — not worth it.

## TCC permission deep links (S8c, 2026-04-28)

When Latte (or the harness) needs a permission you haven't granted, jump straight to the right pane:

```bash
~/dev/smoke-harness/lib/tcc_bootstrap.sh screen     # Screen Recording
~/dev/smoke-harness/lib/tcc_bootstrap.sh calendar   # Calendar
~/dev/smoke-harness/lib/tcc_bootstrap.sh location   # Location (for Wi-Fi SSID)
~/dev/smoke-harness/lib/tcc_bootstrap.sh accessibility
~/dev/smoke-harness/lib/tcc_bootstrap.sh full-disk
```

## GitHub Pages: one-command deploy (S8c, 2026-04-28)

The `gh-pages` branch is pre-staged at `../latte-gh-pages-staging/`. After creating the GitHub repo:

```bash
~/dev/smoke-harness/deploy_pages.sh git@github.com:bj-park/latte.git
```

Adds the remote, pushes the branch, and prints the Pages URL to validate. The single remaining manual click is enabling Pages in repo Settings → Pages → Source = `gh-pages` (Apple does not provide an API for this).

---

## Pre-capture: harness primes the demo state for you (S8c, 2026-04-28)

**Before manually capturing**, run the smoke-harness marketing-prep scenario. It seeds Latte with deterministic demo defaults (caramel accent, filled icon, all 4 triggers wired with realistic bundles) and auto-captures Shot 6 (onboarding welcome). After it completes, Latte is running in the canonical demo state — go straight to capture.

```bash
~/dev/smoke-harness/run.sh \
  --project ~/Documents/Claude/Projects/Latte \
  --scenario 06-marketing-prep
```

Output:
- `Latte/.smoke/artifacts/06-onboarding-welcome.png` — auto-captured first-run wizard
- Latte running with: filled icon · caramel accent · Calendar/App/Wi-Fi triggers enabled · Zoom + Slack in App trigger list

When done capturing, clean up:
```bash
pkill -x Latte && defaults delete com.parkbyeongjun.latte
```

LSUIElement (menu-bar-only) apps cannot be driven into Settings programmatically — the popover/Settings click chain requires sandbox-restricted UI scripting. Shots 1-5 are owner-manual; the harness reduces setup time but does not replace the click.

---

## Capture environment setup (do once)

1. **Display**: connect/use a Retina display set to "More space" scaling (or use a 16" MacBook Pro built-in). Verify with `system_profiler SPDisplaysDataType | grep -i resolution` — target ≥ 2880 × 1800.
2. **Wallpaper**: macOS default Sequoia / Tahoe wallpaper. **Do NOT** use a custom one — Apple flags personal photos.
3. **Menu bar**: hide third-party menu bar utilities (Bartender, etc.) for the capture pass. Latte should be the only third-party item visible.
4. **Time of day**: set the menu-bar clock display to a clean reading (e.g., 10:09 — Apple's marketing convention) via `sudo date 0427100900` (resets after reboot). Optional but professional.
5. **Battery**: ensure menu bar shows ≥ 80% (plug in if needed). Avoid showing low-battery glyph.
6. **Capture tool**: use macOS built-in `Cmd+Shift+4` then `Space` (window capture, retains shadow) or `Cmd+Shift+5` (interactive). Output goes to Desktop by default; `defaults write com.apple.screencapture location ~/Documents/Claude/Projects/Caffeinated-Clone/docs/store/screenshots/` to redirect.

---

## The 5 shots (in App Store display order)

### Shot 1 — Hero: menu bar dropdown with cup mid-fill

**What to capture**: Full menu bar visible at top, Latte's `MenuBarExtra` dropdown open, showing the cup view animating mid-fill (about 50-60% liquid, with steam particles drifting up). Background: clean macOS desktop with no other windows.

**How to set up**:
1. Quit Latte if running.
2. Launch `~/Library/Developer/Xcode/DerivedData/Latte-*/Build/Products/Release/Latte.app`.
3. Click menu bar icon → pick "30m" (gives a long enough fill window to capture).
4. Wait ~10 s so the liquid is visibly partial — not full, not empty.
5. Click menu bar icon again to open dropdown.
6. `Cmd+Shift+4` then `Space`, hover over the dropdown, click. Captures with shadow.

**Caption text** (App Store overlay, ≤30 chars/line, 2 lines max):
```
A coffee cup on your menu bar.
Awake when you need it.
```

### Shot 2 — Settings → General with Coffee tone preview

**What to capture**: Latte Settings window open, General tab selected, scrolled to Appearance section. The CoffeeAccent Picker is **expanded** (showing all 5 presets), with one preset highlighted (suggest "caramel"). The inline 36 pt Preview cup renders that color live.

**How to set up**:
1. Open Latte → Settings… (or `Cmd+,`).
2. General tab → scroll to "Appearance" section.
3. Click the Picker dropdown to expand it.
4. Capture with `Cmd+Shift+4` + `Space` over the Settings window.

**Caption**:
```
Five coffee tones.
Pick your daily brew.
```

### Shot 3 — Settings → Triggers showing all 4 with vote indicators

**What to capture**: Triggers tab. All 4 trigger Sections visible (Calendar, App, Wi-Fi, Focus). At least 2 enabled (showing the voting dot in the header). One Section expanded (suggest the App trigger — it has the richest config form with friendly app names + icons).

**How to set up**:
1. Settings → Triggers tab.
2. Enable Calendar + App triggers (toggle ON). Grant permissions if prompted (do this in a separate setup step before the capture pass — permission prompts ruin marketing shots).
3. Expand the App trigger Section.
4. Verify ≥ 2 watched apps appear with real icons (Zoom + Slack ideally).
5. Capture.

**Caption**:
```
Triggers know when you're busy.
Set them once. Forget them.
```

### Shot 4 — App trigger config detail (close-up)

**What to capture**: Close-up of just the App trigger Section, fully expanded, showing 4-5 real apps with icons + display names + the "Add from running apps" Menu open with one item highlighted.

**How to set up**:
1. From Shot 3 setup, click "Add from running apps" Menu.
2. Hover over a Menu item (don't click — just hover so the highlight shows).
3. Capture the Settings window (will include the open Menu).

**Caption**:
```
Add the apps that matter.
Latte does the rest.
```

### Shot 5 — About tab (humanize the product)

**What to capture**: Settings → About tab. Latte logo + version + tagline + author credit + license info.

**How to set up**:
1. Settings → About tab.
2. Capture.

**Caption**:
```
Built for hybrid work.
Made in Korea.
```

---

## Pre-upload review checklist

Before uploading to App Store Connect, owner verifies:

- [ ] All 5 PNGs are exactly 2880 × 1800 (verify with `sips -g pixelWidth -g pixelHeight <file>`)
- [ ] No personal data visible — no real calendar event titles, no real Wi-Fi SSIDs containing personal names, no Focus mode with personal names
- [ ] No competitor apps visible in the Dock or running-apps Menu (Amphetamine etc.)
- [ ] No notification badges (Mail "47", Slack "12") in the menu bar
- [ ] No low battery indicator
- [ ] Filenames sequential: `01-hero.png`, `02-coffee-tone.png`, `03-triggers-overview.png`, `04-app-trigger-detail.png`, `05-about.png`
- [ ] All saved to `docs/store/screenshots/` and committed

---

## Optional enhancements (post-v1.0)

- Add Korean-locale captures (separate set, App Store Connect supports per-locale screenshots).
- Add a 30-second App Preview video (loop of cup activating + deactivating with a meeting). Apple requires `.mov` H.264, 1920×1080 or higher. Defer to v1.1.
- Localized caption variants (Korean) when ko-KR locale is added to App Store Connect.
