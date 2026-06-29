import CoreGraphics

/// Pure layout math for the menu-bar popover.
///
/// Extracted so the height-clamp rule is unit-testable without standing up a
/// real `MenuBarExtra(.window)` popover.
///
/// App Store review (Submission dc78a591, 2026-06-23, Guideline 4 - Design)
/// rejected the build because "the app menubar extra pop-up window is
/// truncated at the bottom so that users can not click some options."
/// `MenuBarRoot` was a fixed-width / unbounded-height `VStack`; with all
/// seven duration presets + an expanded Custom row + recurring presets it
/// overflowed the screen, and `MenuBarExtra(.window)` does NOT auto-clamp or
/// scroll — the bottom (Settings / Quit) ran off-screen. The fix puts the
/// middle section in a `ScrollView` whose height is clamped here and keeps the
/// Settings / Quit footer pinned outside the scroll.
///
/// IMPORTANT (regression history): `MenuBarRoot` measures the middle section's
/// natural height at runtime (from a hidden, `fixedSize` copy) and uses it only
/// to DECIDE whether scrolling is needed (`needsScroll`). When the content fits
/// the screen it is rendered at its natural size with NO `ScrollView`, so the
/// popover window grows and shrinks with the content (e.g. when the Custom row
/// expands) — no fixed window, no scrollbar. Only when the content is taller
/// than the screen does it fall back to a `ScrollView` capped at the screen, so
/// the footer stays reachable. Three earlier attempts informed this design:
/// (1) sizing a `ScrollView` from `min(measured, maxScroll)` with no floor let
/// a transient 0 measurement collapse the whole middle (header + footer only);
/// (2) guessing per-state pixel constants left a visible gap above the footer;
/// (3) a fixed-height `ScrollView` removed the gap but pinned the window size
/// and showed a permanent scrollbar (owner-rejected). Rendering natural-size
/// when it fits avoids all three: it can't collapse (real content has
/// intrinsic height), can't gap (window hugs content), and only scrolls when
/// genuinely necessary.
enum MenuBarLayout {

    /// Vertical space the pinned header + footer + popover chrome + a safety
    /// margin consume, subtracted from the usable screen height to leave the
    /// rest for the scrollable middle section.
    static let reservedChrome: CGFloat = 220

    /// Floor so the scroll fallback stays usable even on unusually short
    /// displays or odd `visibleFrame` readings.
    static let minScrollHeight: CGFloat = 280

    /// Initial seed for the measured-height state, used before the first
    /// geometry read lands. Small enough that the first frame renders
    /// natural-size (not the scroll fallback) on any real screen.
    static let seedContentHeight: CGFloat = 420

    /// Fallback when no screen height is available (headless / test contexts).
    /// A conservative small-laptop usable height.
    static let fallbackScreenHeight: CGFloat = 800

    /// Upper bound for the middle section before it must scroll, from the usable
    /// screen height. Pass a screen's `visibleFrame.height` (already excludes
    /// the menu bar / notch / Dock). Leaves `reservedChrome` for the pinned
    /// header + footer so the truncation that triggered the rejection cannot
    /// recur; never below `minScrollHeight`.
    static func maxScrollHeight(forVisibleScreenHeight height: CGFloat) -> CGFloat {
        max(minScrollHeight, height - reservedChrome)
    }

    /// Whether the measured content is too tall for the screen and must scroll.
    /// When false, `MenuBarRoot` renders the content at natural size so the
    /// window hugs it; when true, it uses a `ScrollView` capped at
    /// `maxScrollHeight`.
    static func needsScroll(
        measuredContentHeight measured: CGFloat,
        visibleScreenHeight height: CGFloat
    ) -> Bool {
        measured > maxScrollHeight(forVisibleScreenHeight: height)
    }
}
