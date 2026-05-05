import AppKit

/// Pure decision layer for menu-bar popover key handling.
///
/// **S26 / B6 (S22 P-issue-4 close-out)** — `.keyboardShortcut(...)` doesn't
/// fire inside `MenuBarExtra(.window)` popovers (LSUIElement / .accessory
/// status-item context — popover window doesn't enter the SwiftUI
/// keyEquivalent dispatch chain). The fix is an `NSEvent.addLocalMonitor`
/// scoped to popover open/close, with this handler as the pure logic
/// layer so the modifier-mask + character matching is unit-testable
/// without spinning up an `NSEvent`.
public enum PopoverKeyAction: Equatable, Sendable {
    case openSettings
    case quit
    case passthrough
}

public enum PopoverKeyHandler {

    /// Decide what action a key press should trigger inside the popover.
    ///
    /// Strict matching: only an exact `.command` modifier mask (no shift /
    /// option / control admixture) on `,` or `q` is consumed. Any other
    /// modifier combination passes through so system shortcuts (e.g.
    /// ⌘⇧Q = log out) and Carbon-registered hotkeys (e.g. user's
    /// rebound ⌘⇧L global awake-toggle) keep working when typed while
    /// the popover happens to be visible.
    public static func decide(
        modifiers: NSEvent.ModifierFlags,
        character: String?
    ) -> PopoverKeyAction {
        // Only the user-pressed chord modifiers participate in matching.
        // `.capsLock` / `.numericPad` / `.function` / `.help` are state
        // bits the OS sets independently and must not gate the match —
        // a numpad-comma or capslock-on press of ⌘, should still open
        // Settings.
        let chordMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let pressed = modifiers.intersection(chordMask)
        guard pressed == .command else { return .passthrough }
        guard let character, !character.isEmpty else { return .passthrough }
        switch character {
        case ",":
            return .openSettings
        case "q", "Q":
            return .quit
        default:
            return .passthrough
        }
    }
}
