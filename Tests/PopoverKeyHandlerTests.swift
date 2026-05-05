import XCTest
import AppKit
@testable import Latte

/// **S26 / B6 (S22 P-issue-4 close-out)** — pure-logic tests for
/// `PopoverKeyHandler.decide`. The NSEvent.addLocalMonitor wiring in
/// `MenuBarRoot` is owner-side manual smoke; this layer guarantees
/// the modifier-mask + character matching is correct so the wiring
/// only needs to forward NSEvent fields straight through.
final class PopoverKeyHandlerTests: XCTestCase {

    func testCommandCommaOpensSettings() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: .command, character: ","),
            .openSettings
        )
    }

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

    func testCommandOptionCommaPassesThrough() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: [.command, .option], character: ","),
            .passthrough
        )
    }

    func testCommandControlQPassesThrough() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: [.command, .control], character: "q"),
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

    func testCommandPunctuationOtherThanCommaPassesThrough() {
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: .command, character: "."),
            .passthrough
        )
    }

    func testNumPadModifierIgnored() {
        // `.numericPad` lives outside `.deviceIndependentFlagsMask`; the
        // handler should ignore it and still match ⌘, exactly.
        let mods: NSEvent.ModifierFlags = [.command, .numericPad]
        XCTAssertEqual(
            PopoverKeyHandler.decide(modifiers: mods, character: ","),
            .openSettings
        )
    }
}
