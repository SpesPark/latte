import CoreGraphics

/// Pure layout math for the menu-bar popover.
///
/// Extracted so the "never taller than the screen" rule is unit-testable
/// without standing up a real `MenuBarExtra(.window)` popover.
///
/// App Store review (Submission dc78a591, 2026-06-23, Guideline 4 - Design)
/// rejected the build because "the app menubar extra pop-up window is
/// truncated at the bottom so that users can not click some options."
/// `MenuBarRoot` was a fixed-width / unbounded-height `VStack`; with all
/// seven duration presets + an expanded Custom row + recurring presets it
/// overflowed the screen, and `MenuBarExtra(.window)` does NOT auto-clamp or
/// scroll — the bottom (Settings / Quit) ran off-screen. The fix caps the
/// scrollable middle section at the height computed here and keeps the
/// Settings / Quit footer pinned outside the scroll so it is always
/// reachable, even on notched 14"/16" displays where the menu bar eats more
/// vertical space.
enum MenuBarLayout {

    /// Vertical space the fixed header + footer + popover chrome + a safety
    /// margin consume, subtracted from the usable screen height to leave the
    /// rest for the scrollable middle section.
    static let reservedChrome: CGFloat = 220

    /// Floor so the scroll area stays usable even on unusually short
    /// displays (or odd `visibleFrame` readings).
    static let minScrollHeight: CGFloat = 280

    /// Fallback when `NSScreen.main?.visibleFrame.height` is unavailable
    /// (headless / test contexts). A conservative small-laptop height.
    static let fallbackScreenHeight: CGFloat = 800

    /// Seed for the measured-content-height state before the first geometry
    /// read lands — a typical popover content height (header-excluded). Close
    /// to the real value so the first opened frame doesn't visibly resize:
    /// too large would flash a tall empty popover on big displays, too small
    /// would flash a collapsed one. The measurement corrects it either way.
    static let estimatedContentHeight: CGFloat = 600

    /// Max height for the scrollable middle section, given the usable screen
    /// height. Pass `NSScreen.main?.visibleFrame.height` — `visibleFrame`
    /// already excludes the menu bar / notch inset and the Dock.
    ///
    /// Always returns at least `minScrollHeight` so the area never collapses,
    /// and always leaves `reservedChrome` for the pinned header + footer so
    /// the truncation that triggered the rejection cannot recur.
    static func maxScrollHeight(forVisibleScreenHeight height: CGFloat) -> CGFloat {
        max(minScrollHeight, height - reservedChrome)
    }
}
