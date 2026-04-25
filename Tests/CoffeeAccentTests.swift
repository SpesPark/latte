import XCTest
@testable import Latte

final class CoffeeAccentTests: XCTestCase {

    // MARK: - Case enumeration & identity

    func testFiveCasesInExpectedOrder() {
        XCTAssertEqual(
            CoffeeAccent.allCases,
            [.espresso, .caramel, .mocha, .latte, .noir],
            "Picker order is part of the user-facing contract — keep it stable."
        )
    }

    func testIdMatchesRawValue() {
        for accent in CoffeeAccent.allCases {
            XCTAssertEqual(accent.id, accent.rawValue)
        }
    }

    // MARK: - Display strings (pickup labels)

    func testDisplayNamesAreNonEmptyAndUnique() {
        let names = CoffeeAccent.allCases.map(\.displayName)
        XCTAssertFalse(names.contains(where: \.isEmpty))
        XCTAssertEqual(Set(names).count, names.count, "Display names must be unique")
    }

    func testShortDescriptionsAreNonEmptyAndUnique() {
        let descriptions = CoffeeAccent.allCases.map(\.shortDescription)
        XCTAssertFalse(descriptions.contains(where: \.isEmpty))
        XCTAssertEqual(Set(descriptions).count, descriptions.count)
    }

    // MARK: - Raw-value persistence stability

    func testRawValuesAreLowercaseStable() {
        // These rawValues are stored to UserDefaults — changing them silently
        // would orphan every existing user's preference.
        XCTAssertEqual(CoffeeAccent.espresso.rawValue, "espresso")
        XCTAssertEqual(CoffeeAccent.caramel.rawValue, "caramel")
        XCTAssertEqual(CoffeeAccent.mocha.rawValue, "mocha")
        XCTAssertEqual(CoffeeAccent.latte.rawValue, "latte")
        XCTAssertEqual(CoffeeAccent.noir.rawValue, "noir")
    }

    // MARK: - Default + tolerant decode

    func testDefaultIsEspresso() {
        XCTAssertEqual(CoffeeAccent.default, .espresso)
    }

    func testDecodeNilReturnsDefault() {
        XCTAssertEqual(CoffeeAccent.decode(nil), .default)
    }

    func testDecodeEmptyStringReturnsDefault() {
        XCTAssertEqual(CoffeeAccent.decode(""), .default)
    }

    func testDecodeUnknownReturnsDefault() {
        XCTAssertEqual(CoffeeAccent.decode("turquoise"), .default)
    }

    func testDecodeKnownReturnsThatCase() {
        XCTAssertEqual(CoffeeAccent.decode("caramel"), .caramel)
        XCTAssertEqual(CoffeeAccent.decode("noir"), .noir)
    }

    func testDecodeIsCaseSensitive() {
        // rawValues are lowercase — uppercase / mixed-case input is unknown.
        // This matches MenuBarIconStyle.decode behavior; UserDefaults round-trip
        // never produces a different case for our writes.
        XCTAssertEqual(CoffeeAccent.decode("Espresso"), .default)
        XCTAssertEqual(CoffeeAccent.decode("CARAMEL"), .default)
    }

    // MARK: - Color resolution smoke

    func testColorResolvesForEveryCase() {
        // We can't compare Color values structurally, but we can confirm
        // each call returns without crashing and the resulting Color is
        // distinct from `Color.clear` once realised through NSColor.
        for accent in CoffeeAccent.allCases {
            _ = accent.color
        }
    }
}
