import Foundation
#if canImport(Carbon)
import Carbon.HIToolbox
#endif

/// A captured keyboard chord — Carbon-style modifier mask + virtual key code.
///
/// `Codable` so it can round-trip through `SettingsStore` as a JSON-encoded
/// blob (the same approach the rest of the project uses for compound values
/// like `MenuBarIconStyle` or `ScheduleEntry`). `Hashable` so duplicate-chord
/// detection in the recorder UI is a one-liner. `Sendable` so it can cross
/// actor boundaries when the recorder hands the chord to the
/// `KeyboardShortcutCoordinator`.
public struct KeyChord: Codable, Hashable, Sendable {

    /// Carbon-style modifier mask (`cmdKey`, `shiftKey`, `optionKey`,
    /// `controlKey`). Stored as `UInt32` so it round-trips losslessly through
    /// `Carbon.HIToolbox` APIs without bit-mask conversions at every callsite.
    public let modifiers: UInt32

    /// Carbon virtual key code (`kVK_ANSI_L = 0x25`, `kVK_Space = 0x31`, …).
    public let keyCode: UInt32

    public init(modifiers: UInt32, keyCode: UInt32) {
        self.modifiers = modifiers
        self.keyCode = keyCode
    }

    /// Default chord (⌘⇧L). Used as the silent-default fallback when no
    /// custom chord has been persisted, and as the "Reset" target.
    public static let `default`: KeyChord = {
        #if canImport(Carbon)
        return KeyChord(
            modifiers: UInt32(cmdKey | shiftKey),
            keyCode: UInt32(kVK_ANSI_L)
        )
        #else
        // Stable raw values matching the Carbon constants above so non-Carbon
        // platforms (test build slices that exclude HIToolbox) get the same
        // bit pattern. cmdKey=0x100, shiftKey=0x200, kVK_ANSI_L=0x25.
        return KeyChord(modifiers: 0x300, keyCode: 0x25)
        #endif
    }()

    /// Human-readable glyph string, e.g. `"⌘⇧L"`.
    ///
    /// Modifier order matches the spec test
    /// `glyph_renders_modifiers_in_canonical_order_cmd_opt_ctrl_shift_letter`:
    /// ⌘ → ⌥ → ⌃ → ⇧, then the key glyph. (Apple HIG actually prefers
    /// ⌃⌥⇧⌘ for menu shortcuts; the recorder's purpose is recognition not
    /// menu reproduction, so the glyph is rendered in the order the spec
    /// committed to.)
    public var glyph: String {
        var s = ""
        if (modifiers & UInt32(KeyChord.cmdMask))    != 0 { s += "⌘" }
        if (modifiers & UInt32(KeyChord.optionMask)) != 0 { s += "⌥" }
        if (modifiers & UInt32(KeyChord.ctrlMask))   != 0 { s += "⌃" }
        if (modifiers & UInt32(KeyChord.shiftMask))  != 0 { s += "⇧" }
        s += KeyChord.keyGlyph(forKeyCode: keyCode)
        return s
    }

    /// Validation: at least one of ⌘ / ⌃ / ⌥ must be present. Bare ⇧ +
    /// letter is rejected because it would conflict with normal typing.
    /// The recorder UI uses this to keep the FSM in `recording` until the
    /// user produces a valid chord.
    public var hasRequiredModifier: Bool {
        let required = UInt32(KeyChord.cmdMask | KeyChord.ctrlMask | KeyChord.optionMask)
        return (modifiers & required) != 0
    }

    // MARK: - Constants (broken out so non-Carbon build slices still compile)

    /// `cmdKey`  in `Carbon.HIToolbox`.
    public static let cmdMask:    Int = 0x100
    /// `shiftKey` in `Carbon.HIToolbox`.
    public static let shiftMask:  Int = 0x200
    /// `optionKey` in `Carbon.HIToolbox`.
    public static let optionMask: Int = 0x800
    /// `controlKey` in `Carbon.HIToolbox`.
    public static let ctrlMask:   Int = 0x1000

    // MARK: - Key-code → glyph

    /// Maps the most common Carbon key codes to their glyphs. Falls back to
    /// the raw hex code in parentheses for unknown keys so the user can at
    /// least see *something* deterministic (vs. an empty string).
    static func keyGlyph(forKeyCode code: UInt32) -> String {
        if let letter = letterMap[code] { return letter }
        if let digit  = digitMap[code]  { return digit }
        if let named  = namedMap[code]  { return named }
        return String(format: "(0x%02X)", code)
    }

    private static let letterMap: [UInt32: String] = [
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F",
        0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L",
        0x2E: "M", 0x2D: "N", 0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R",
        0x01: "S", 0x11: "T", 0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X",
        0x10: "Y", 0x06: "Z"
    ]
    private static let digitMap: [UInt32: String] = [
        0x1D: "0", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4",
        0x17: "5", 0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9"
    ]
    private static let namedMap: [UInt32: String] = [
        0x31: "Space", 0x30: "Tab",  0x24: "Return", 0x35: "Esc",
        0x33: "⌫",     0x75: "⌦",
        0x7B: "←",     0x7C: "→",   0x7D: "↓",      0x7E: "↑",
        0x7A: "F1",    0x78: "F2",  0x63: "F3",     0x76: "F4",
        0x60: "F5",    0x61: "F6",  0x62: "F7",     0x64: "F8",
        0x65: "F9",    0x6D: "F10", 0x67: "F11",    0x6F: "F12"
    ]
}

// MARK: - SettingsStore round-trip helper

public extension SettingsStore {
    /// Returns the persisted chord, or `nil` if absent / corrupt. Callers
    /// fall back to `.default` when nil — see `KeyboardShortcutCoordinator`.
    func keyChord(_ key: SettingsKey) -> KeyChord? {
        guard let raw = data(key) else { return nil }
        return try? JSONDecoder().decode(KeyChord.self, from: raw)
    }

    func setKeyChord(_ chord: KeyChord?, for key: SettingsKey) {
        guard let chord else { remove(key); return }
        if let encoded = try? JSONEncoder().encode(chord) {
            setData(encoded, for: key)
        }
    }
}

// MARK: - Reserved chord blocklist (system-only per spec §8 Q1)

public enum ReservedChord {
    /// System-level chords that must not be reassigned to Latte. Uses Carbon
    /// raw constants instead of the `KeyChord` static masks so this list is
    /// readable in isolation.
    public static let blocklist: Set<KeyChord> = [
        KeyChord(modifiers: UInt32(KeyChord.cmdMask), keyCode: 0x0C),  // ⌘Q
        KeyChord(modifiers: UInt32(KeyChord.cmdMask), keyCode: 0x0D),  // ⌘W
        KeyChord(modifiers: UInt32(KeyChord.cmdMask), keyCode: 0x08),  // ⌘C
        KeyChord(modifiers: UInt32(KeyChord.cmdMask), keyCode: 0x09),  // ⌘V
        KeyChord(modifiers: UInt32(KeyChord.cmdMask), keyCode: 0x07),  // ⌘X
        KeyChord(modifiers: UInt32(KeyChord.cmdMask), keyCode: 0x30),  // ⌘Tab
        KeyChord(modifiers: UInt32(KeyChord.cmdMask), keyCode: 0x31)   // ⌘Space
    ]

    public static func contains(_ chord: KeyChord) -> Bool {
        blocklist.contains(chord)
    }
}
