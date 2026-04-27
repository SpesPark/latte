# V2-11 — Icon Composer dark / tinted variants (owner guide)

> **Status**: deferred to v1.2 per `docs/v2-backlog.md`. Pure cosmetic;
> not gating App Store submission. v1.0 ships with the single light
> AppIcon raster set landed in S7.11.

## Why bother

macOS 26 Tahoe applies an icon theme system that distinguishes light /
dark / tinted appearances. Apps that ship only the light variant look
like out-of-place legacy software in System Settings → Appearance →
Tinted, and reviewers / "looks native" buyers notice immediately.

Shipping all three variants is a polish signal that pays off on the
storefront browse and in user word-of-mouth.

## Owner-side workflow (~1h, no Claude work)

1. Open Xcode 15+ (Icon Composer ships with it).
2. Open `Resources/Assets.xcassets/AppIcon.appiconset/` in the project
   navigator.
3. Drag `icon-master-1254.png` (the master raster from S7.11) into the
   Icon Composer well. Click "Generate dark variant" and "Generate
   tinted variant" — Apple's compositor produces sensible defaults
   from a single master.
4. Hand-tune if needed: dark variant should feel less luminous; tinted
   variant should be a single-channel monochrome that takes the
   user's chosen tint without losing detail.
5. Save. Confirm `AppIcon.appiconset/Contents.json` lists three
   variants (light/dark/tinted) under each size bucket.
6. `xcodegen generate` to refresh the project (the asset catalog
   doesn't need explicit regeneration but the project file may).
7. Build + smoke test on macOS 26: Settings → Appearance → Light /
   Dark / Tinted. Verify the icon switches correctly in Finder, Dock,
   and Launchpad.

## Out of scope for this guide

- **Custom design**: if you want non-default dark/tinted variants
  (e.g. a different cup glyph in dark mode), that's design work
  outside Icon Composer's scope. Defer to a designer.
- **Liquid Glass app icon material**: macOS 26 Tahoe app icons can
  opt into Liquid Glass at the OS level via Asset Catalog flags;
  that's already enabled by Xcode 15+ defaults for new asset sets.
  No action required unless owner wants to disable it.

## Verification before App Store submission

Run on a fresh macOS 26 Tahoe machine (or the dev box):

```bash
defaults write -g AppleInterfaceStyle Dark
defaults write -g AppleAccentColor 5  # tinted
killall Dock
```

Re-launch Latte. Confirm the menu-bar icon and the Dock icon both
respect the chosen appearance. If only the menu-bar icon updates and
the Dock icon stays light, the asset catalog is missing variants.

## Recovery

```bash
defaults delete -g AppleInterfaceStyle
defaults delete -g AppleAccentColor
killall Dock
```
