# 05 — App Icon Spec

| Field | Value |
|---|---|
| **Document version** | 0.1 |
| **Status** | Owner-facing brief — not an implementation contract |
| **Audience** | Designer / image-gen tool prompted by the owner |
| **Depends on** | 01-PRD.md (F-1.C.04 — App icon, Phase 1.C feature ID) |
| **Last updated** | 2026-04-26 |

---

## 1. Purpose & scope

This document is the **icon brief** the owner hands to a designer or to an
image-generation tool. It does **not** ship an icon — that artifact is
produced between sessions and committed as part of the Phase 1.C
deliverables.

In scope:
- the visual brief (motif, palette, style references),
- the export checklist (sizes, formats, naming, asset-catalog layout),
- references to Apple's official guidance.

Out of scope:
- the menu-bar icon variants (filled / outline / clock) — those are
  SF Symbol templates rendered in code; see 02-architecture.md §3.1 and
  the asset entries in `Resources/Assets.xcassets/` added in session 5.
- iOS / iPadOS variants — Latte is macOS-only.

---

## 2. Brand context (from PRD)

From [01-PRD.md §3](01-PRD.md):

> **Latte** keeps your Mac awake when it matters. A menu-bar utility for
> macOS 13+, paid one-shot ($2.99), runs as `LSUIElement`.

The icon should communicate, at a glance:

1. **Coffee** — the product name and metaphor (caffeine ⇒ awake).
2. **Friendly desktop utility** — not enterprise, not playful-to-a-fault.
   This is a tool you trust to sit in your menu bar for years.
3. **macOS-native** — uses the rounded-rectangle ("squircle") canvas
   with a layered, slightly tilted hero subject, per Apple's
   Big-Sur-and-later icon language.

Reference apps for tonal calibration:
- *Bear*, *Things 3*, *Reeder* — friendly, slightly playful, but
  unmistakably macOS-native.
- *Caffeinated* (the inspiration) — too plain. Latte should feel
  warmer and more premium.

---

## 3. Motif

**Primary subject**: a steaming espresso / latte cup, three-quarter view,
slightly tilted, sitting on or in front of a soft circular gradient.

**Optional secondary element** (designer's call):
- a thin crescent moon behind the cup, suggesting "awake at night";
- or a subtle clock-hand sweep around the cup rim.

Hard rules:
- The cup must read clearly at **16 × 16** (Finder list view). If the
  steam disappears at small sizes, that is acceptable; the cup silhouette
  must not.
- The cup body must occupy **roughly 60% of the icon canvas** so the
  squircle's safe area is respected.
- **No text**, **no version numbers**, **no shipping a "1.0" stamp**.

---

## 4. Palette

Aligned with `Theme.Colors` in `Sources/UI/Theme/Theme.swift`:

| Role | Hex (light) | Hex (dark) | Notes |
|---|---|---|---|
| Coffee body / fill | `#5C3317` | `#7A4A28` | Slightly lighter on dark mode for contrast |
| Foam / steam | `#F5EED9` | `#F5EED9` | Same on both modes |
| Cup ceramic | `#F2F2F7` | `#E5E5EA` | Cool off-white |
| Background gradient (start) | `#FFE9C7` | `#3A2614` | Warm cream → deep espresso |
| Background gradient (end) | `#FFD89B` | `#1F1208` | |
| Accent (steam glow / rim light) | `#FFA94D` | `#FFA94D` | The `accentAwake` orange |

Use the warm cream gradient as the base. Avoid full saturation — Latte
is a tool, not a candy.

---

## 5. Style guidelines

- **Layered**, not flat. Apple icons since macOS Big Sur use 2–4
  Photoshop-style layers (background gradient → cup shadow → cup → steam
  → highlight).
- **Soft shadow** under the cup (~8% opacity, 4pt blur) — anchors the
  subject in the canvas.
- **Rim light** on the cup's upper-left edge.
- **No drop shadow** outside the squircle. macOS draws the system shadow
  under the squircle automatically.
- **No outer stroke**. Apple removed icon outlines after Yosemite.

If using Icon Composer (Xcode 16+), prefer it over hand-flattening — it
generates the dark-mode and tinted variants automatically and exports
the full `.icon` package.

---

## 6. Required exports

### 6.1 macOS app icon (Asset Catalog)

Target: `Resources/Assets.xcassets/AppIcon.appiconset/`.

| Size (px) | Filename | `idiom` | `scale` |
|---|---|---|---|
| 16   | `icon_16x16.png`     | mac | 1x |
| 32   | `icon_16x16@2x.png`  | mac | 2x |
| 32   | `icon_32x32.png`     | mac | 1x |
| 64   | `icon_32x32@2x.png`  | mac | 2x |
| 128  | `icon_128x128.png`   | mac | 1x |
| 256  | `icon_128x128@2x.png`| mac | 2x |
| 256  | `icon_256x256.png`   | mac | 1x |
| 512  | `icon_256x256@2x.png`| mac | 2x |
| 512  | `icon_512x512.png`   | mac | 1x |
| 1024 | `icon_512x512@2x.png`| mac | 2x |

All exports: **PNG, sRGB, no alpha at the edges of the squircle** (the
canvas is opaque). Designer should supply a transparent-corner master
at 1024 × 1024 from which the system squircle is cut.

If using Icon Composer, ship the resulting `Latte.icon` bundle and let
Xcode 16+ generate the rasters at build time. The `Contents.json`
listed above is the legacy fallback for Xcode 15.

### 6.2 Dark / tinted variants (macOS 14+)

If using Icon Composer, both are generated automatically.

If hand-rasterizing, supply two additional 1024 × 1024 PNGs:
- `Latte-dark.png` — the dark-mode rendering (deep espresso gradient,
  warmer rim light).
- `Latte-tinted.png` — single-channel mask used for system-tinted
  appearance. White = opaque subject, black = canvas. No color.

### 6.3 Marketing / App Store

| Use | Size | Format |
|---|---|---|
| App Store listing | 1024 × 1024 | PNG, sRGB, no alpha |
| README hero | 256 × 256 | PNG |
| Press kit | 512 × 512, 1024 × 1024 | PNG + SVG master if available |

The 1024 × 1024 marketing asset is the **same artwork** as the largest
asset-catalog raster but with the system squircle baked in (App Store
Connect requires a non-rounded square — Apple applies the squircle
mask itself, but historically reviewers reject icons that don't
preview correctly).

---

## 7. Acceptance checklist

Before marking F-1.C.04 done:

- [ ] All ten asset-catalog rasters present and named per §6.1.
- [ ] Dark / tinted variants present (or Icon Composer bundle that
      generates them).
- [ ] 1024 × 1024 marketing asset committed under
      `docs/design/assets/icon-1024.png`.
- [ ] Icon legible at 16 × 16 (verify in Finder list view).
- [ ] No text, no version stamp, no third-party logos.
- [ ] Color values fall within ±5% of the §4 palette (eyeball OK).
- [ ] `Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
      lists every raster.

---

## 8. References

- [Apple HIG — App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Apple HIG — macOS Icon design](https://developer.apple.com/design/human-interface-guidelines/macos)
- [Icon Composer (Xcode 16+)](https://developer.apple.com/documentation/xcode/icon-composer)
- [01-PRD.md §6.4](01-PRD.md) — Phase 1.C feature list
- [02-architecture.md §3.1](02-architecture.md) — Resources/Assets.xcassets layout

---

## 9. Change log

| Version | Date | Note |
|---|---|---|
| 0.1 | 2026-04-26 | Initial spec — session 5 (Phase 1.C, F-1.C.04) |
