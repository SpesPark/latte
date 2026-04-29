import XCTest
@testable import Latte

final class KeyChordTests: XCTestCase {

    func testDefaultChordIsCommandShiftL() {
        let d = KeyChord.default
        XCTAssertNotEqual(d.modifiers & UInt32(KeyChord.cmdMask), 0,
                          "default must include ⌘")
        XCTAssertNotEqual(d.modifiers & UInt32(KeyChord.shiftMask), 0,
                          "default must include ⇧")
        XCTAssertEqual(d.keyCode, 0x25, "kVK_ANSI_L = 0x25")
        XCTAssertEqual(d.glyph, "⌘⇧L")
    }

    func testGlyphRendersModifiersInCanonicalOrderCmdOptCtrlShiftLetter() {
        let chord = KeyChord(
            modifiers: UInt32(KeyChord.cmdMask
                            | KeyChord.optionMask
                            | KeyChord.ctrlMask
                            | KeyChord.shiftMask),
            keyCode: 0x25  // L
        )
        XCTAssertEqual(chord.glyph, "⌘⌥⌃⇧L")
    }

    func testCodableRoundtripPreservesModifiersAndKeyCode() throws {
        let original = KeyChord(
            modifiers: UInt32(KeyChord.cmdMask | KeyChord.optionMask),
            keyCode: 0x28  // K
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyChord.self, from: encoded)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.modifiers, original.modifiers)
        XCTAssertEqual(decoded.keyCode, original.keyCode)
    }

    func testDecodeGarbageReturnsNilThroughSettingsStore() {
        // The lenient form is exposed via the SettingsStore extension.
        let store = InMemorySettingsStore()
        store.setData(Data([0xDE, 0xAD, 0xBE, 0xEF]), for: .shortcutChord)
        XCTAssertNil(store.keyChord(.shortcutChord),
                     "Bogus payload must round-trip as nil, not crash")
    }

    func testEqualChordCompareEqualAndHashIdentically() {
        let a = KeyChord(modifiers: UInt32(KeyChord.cmdMask), keyCode: 0x0C)
        let b = KeyChord(modifiers: UInt32(KeyChord.cmdMask), keyCode: 0x0C)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
        var set: Set<KeyChord> = []
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1, "Hashable conformance dedupes equal chords")
    }

    func testChordWithOnlyShiftIsRejectedAtValidationLayer() {
        // Bare ⇧ + letter is rejected — see hasRequiredModifier doc.
        let invalid = KeyChord(
            modifiers: UInt32(KeyChord.shiftMask),
            keyCode: 0x25  // L
        )
        XCTAssertFalse(invalid.hasRequiredModifier,
                       "⇧L alone is a typing chord, not a global hotkey")

        let valid = KeyChord(
            modifiers: UInt32(KeyChord.cmdMask | KeyChord.shiftMask),
            keyCode: 0x25
        )
        XCTAssertTrue(valid.hasRequiredModifier)
    }

    // MARK: - Reserved chord blocklist (spec §3 + §8 Q1)

    func testReservedSystemChordsAreBlocked() {
        // ⌘Q must not be reassigned to Latte.
        let cmdQ = KeyChord(modifiers: UInt32(KeyChord.cmdMask), keyCode: 0x0C)
        XCTAssertTrue(ReservedChord.contains(cmdQ))

        // ⌘V (paste) must not be reassigned.
        let cmdV = KeyChord(modifiers: UInt32(KeyChord.cmdMask), keyCode: 0x09)
        XCTAssertTrue(ReservedChord.contains(cmdV))

        // The default chord is allowed.
        XCTAssertFalse(ReservedChord.contains(.default),
                       "⌘⇧L is the project default and must not be on the blocklist")
    }
}
