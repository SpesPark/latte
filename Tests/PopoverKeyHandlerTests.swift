import XCTest
import AppKit
@testable import Latte

/// **S26 / B6 (S22 P-issue-4 close-out)** — pure-logic tests for
/// `PopoverKeyHandler.decide`. The NSEvent.addLocalMonitor wiring in
/// `MenuBarRoot` is owner-side manual smoke; this layer guarantees
/// the modifier-mask + character matching is correct so the wiring
/// only needs to forward NSEvent fields straight through.
///
/// **S27 update** — owner judged ⌘, popover binding low-value (popover
/// already requires mouse for trigger selection, so ⌘, → Settings is a
/// 1-step shortcut to a context the user is already mouse-bound to).
/// Removed in S27. Only ⌘Q remains as a popover-scoped consumer; all
/// other chords pass through so Carbon-registered global hotkeys + system
/// shortcuts (⌘⇧Q logout / user-rebound ⌘L awake-toggle / etc.) keep
/// working when typed while the popover happens to be visible.
final class PopoverKeyHandlerTests: XCTestCase {

    func testCommandQLowercaseQuits() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: .command, character: "q"),
            .quit
        )
    }

    func testCommandQUppercaseQuits() {
        // `charactersIgnoringModifiers` returns "q" without shift, but
        // some keyboard layouts may feed "Q"; accept both for robustness.
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: .command, character: "Q"),
            .quit
        )
    }

    // S27: ⌘, no longer consumed; ensure passthrough so macOS / other
    // apps see the chord normally if it's typed while the popover is
    // visible.
    func testCommandCommaPassesThrough() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: .command, character: ","),
            .passthrough
        )
    }

    func testBareCommaPassesThrough() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: [], character: ","),
            .passthrough
        )
    }

    func testCommandShiftQPassesThrough() {
        // ⌘⇧Q is the system "log out" shortcut — must not be consumed
        // even though the character matches.
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: [.command, .shift], character: "Q"),
            .passthrough
        )
    }

    func testCommandControlQPassesThrough() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: [.command, .control], character: "q"),
            .passthrough
        )
    }

    func testCommandOptionQPassesThrough() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: [.command, .option], character: "q"),
            .passthrough
        )
    }

    func testNilCharacterPassesThrough() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: .command, character: nil),
            .passthrough
        )
    }

    func testEmptyCharacterPassesThrough() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: .command, character: ""),
            .passthrough
        )
    }

    func testCommandLetterOtherThanQPassesThrough() {
        // ⌘L is the user's default global awake-toggle (B1) — must
        // pass through so Carbon registration stays authoritative even
        // if popover happens to be visible when the chord is pressed.
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: .command, character: "l"),
            .passthrough
        )
    }

    func testCommandPunctuationOtherThanQPassesThrough() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: .command, character: "."),
            .passthrough
        )
    }

    func testNumPadModifierIgnoredForQuit() {
        // `.numericPad` lives outside `.deviceIndependentFlagsMask`; the
        // handler should ignore it and still match ⌘Q exactly. (Numpad
        // doesn't actually have a Q key in practice, but the principle
        // — OS state bits don't break chord matching — still applies.)
        let mods: NSEvent.ModifierFlags = [.command, .numericPad]
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: mods, character: "q"),
            .quit
        )
    }

    func testCapsLockIgnoredForQuit() {
        // Same principle: capslock-on must not break ⌘Q matching.
        let mods: NSEvent.ModifierFlags = [.command, .capsLock]
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: mods, character: "q"),
            .quit
        )
    }
}
