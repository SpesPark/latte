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
            let name = style.symbolName
            XCTAssertFalse(name.isEmpty, "\(style) has an empty symbol name")
            XCTAssertFalse(name.contains(" "), "\(style) symbol name must not contain spaces")
        }
    }

    func testSymbolNamesAreUnique() {
        let names = MenuBarIconStyle.allCases.map(\.symbolName)
        XCTAssertEqual(names.count, Set(names).count, "Each variant must use a distinct SF Symbol")
    }

    func testFilledSymbolIsCupAndSaucerFill() {
        XCTAssertEqual(MenuBarIconStyle.filled.symbolName, "cup.and.saucer.fill")
    }

    func testOutlineSymbolIsCupAndSaucer() {
        XCTAssertEqual(MenuBarIconStyle.outline.symbolName, "cup.and.saucer")
    }

    func testClockSymbolIsCupAndHeatWavesFill() {
        XCTAssertEqual(MenuBarIconStyle.clock.symbolName, "cup.and.heat.waves.fill")
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
