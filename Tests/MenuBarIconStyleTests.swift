import XCTest
@testable import Latte

final class MenuBarIconStyleTests: XCTestCase {

    // MARK: - Coverage

    func testAllCasesAreEnumerated() {
        // Guard against accidentally adding a case without updating tests/UI.
        XCTAssertEqual(
            Set(MenuBarIconStyle.allCases),
            Set([.filled, .outline, .clock])
        )
    }

    func testRawValuesAreStableForPersistence() {
        // Raw values are persisted in UserDefaults — changing them silently
        // would orphan every existing user's saved preference.
        XCTAssertEqual(MenuBarIconStyle.filled.rawValue, "filled")
        XCTAssertEqual(MenuBarIconStyle.outline.rawValue, "outline")
        XCTAssertEqual(MenuBarIconStyle.clock.rawValue, "clock")
    }

    // MARK: - SF Symbol mapping

    func testSymbolNamesAreSFSymbolFormatted() {
        for style in MenuBarIconStyle.allCases {
            for awake in [false, true] {
                let name = style.symbolName(awake: awake)
                XCTAssertFalse(name.isEmpty, "\(style) awake=\(awake) has an empty symbol name")
                XCTAssertFalse(name.contains(" "), "\(style) awake=\(awake) symbol name must not contain spaces")
            }
        }
    }

    // V2-01 (S8b): asleep glyph and awake glyph differ for *every* style,
    // so the menu-bar icon visibly reflects state. This is the core
    // contract of the awake-state visualization feature.
    func testAsleepGlyphDiffersFromAwakeGlyphForEveryStyle() {
        for style in MenuBarIconStyle.allCases {
            let asleep = style.symbolName(awake: false)
            let awake = style.symbolName(awake: true)
            XCTAssertNotEqual(
                asleep, awake,
                "\(style) must use distinct SF Symbols for asleep vs awake (else V2-01 has no visible effect for this style)"
            )
        }
    }

    func testFilledAsleepIsCupAndSaucerFill() {
        XCTAssertEqual(MenuBarIconStyle.filled.symbolName(awake: false), "cup.and.saucer.fill")
    }

    func testOutlineAsleepIsCupAndSaucer() {
        XCTAssertEqual(MenuBarIconStyle.outline.symbolName(awake: false), "cup.and.saucer")
    }

    func testClockAsleepIsMug() {
        XCTAssertEqual(MenuBarIconStyle.clock.symbolName(awake: false), "mug")
    }

    func testAllStylesShareSameAwakeGlyph() {
        // Per S8b owner-feedback fix: every style awake glyph is the
        // steam-cup so "active" reads identically across the three
        // styles, while at-rest glyphs stay distinct so the user's
        // option choice still matters.
        for style in MenuBarIconStyle.allCases {
            XCTAssertEqual(
                style.symbolName(awake: true),
                "cup.and.heat.waves.fill",
                "\(style) awake variant must be the universal steam cup"
            )
        }
    }

    func testAtRestGlyphsAreDistinctPerStyle() {
        // The user's icon-style choice is preserved by giving each style
        // its own at-rest glyph; awake glyphs converge.
        let atRestGlyphs = MenuBarIconStyle.allCases.map { $0.symbolName(awake: false) }
        XCTAssertEqual(
            atRestGlyphs.count,
            Set(atRestGlyphs).count,
            "Each style must have a distinct at-rest glyph (got \(atRestGlyphs))"
        )
    }

    func testZeroArgSymbolNameMatchesAsleepVariant() {
        // The bare `symbolName` accessor must return the asleep variant
        // (back-compat with v1 callers and the asleep-default convention).
        for style in MenuBarIconStyle.allCases {
            XCTAssertEqual(style.symbolName, style.symbolName(awake: false))
        }
    }

    // MARK: - Display names

    func testDisplayNamesAreNonEmpty() {
        for style in MenuBarIconStyle.allCases {
            XCTAssertFalse(style.displayName.isEmpty)
        }
    }

    func testDisplayNamesAreUnique() {
        let names = MenuBarIconStyle.allCases.map(\.displayName)
        XCTAssertEqual(names.count, Set(names).count)
    }

    // MARK: - Default + tolerant decode

    func testDefaultIsFilled() {
        XCTAssertEqual(MenuBarIconStyle.default, .filled)
    }

    func testDecodeNilReturnsDefault() {
        XCTAssertEqual(MenuBarIconStyle.decode(nil), .default)
    }

    func testDecodeEmptyStringReturnsDefault() {
        XCTAssertEqual(MenuBarIconStyle.decode(""), .default)
    }

    func testDecodeUnknownReturnsDefault() {
        XCTAssertEqual(MenuBarIconStyle.decode("unknown-variant"), .default)
        XCTAssertEqual(MenuBarIconStyle.decode("FILLED"), .default,
                       "Decode is case-sensitive — uppercase is treated as unknown")
    }

    func testDecodeKnownReturnsExactValue() {
        XCTAssertEqual(MenuBarIconStyle.decode("filled"), .filled)
        XCTAssertEqual(MenuBarIconStyle.decode("outline"), .outline)
        XCTAssertEqual(MenuBarIconStyle.decode("clock"), .clock)
    }

    // MARK: - Identifiable

    func testIdMatchesRawValue() {
        for style in MenuBarIconStyle.allCases {
            XCTAssertEqual(style.id, style.rawValue)
        }
    }
}
