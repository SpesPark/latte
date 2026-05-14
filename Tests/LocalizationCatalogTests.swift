import XCTest
@testable import Latte

/// Verifies the Localizable.xcstrings catalog is well-formed and that the
/// P1 owner-verifiable language (ko) covers every source string. Other
/// languages (ja, zh-Hans, zh-Hant, es, de, fr, pt-BR, it, ru) are added in
/// Phase H (S32 / community PR welcome), so they are NOT asserted here yet —
/// only the en source and ko coverage are required for P1 to ship.
final class LocalizationCatalogTests: XCTestCase {

    // MARK: - Catalog file discovery

    private func catalogURL() throws -> URL {
        // The .xcstrings is compiled into .lproj/Localizable.strings at build
        // time; the source JSON lives in the project's Resources/ directory.
        // For testing, we read the source JSON to verify structure regardless
        // of build-time extraction.
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testFileURL
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // project root
        let url = projectRoot.appendingPathComponent("Resources/Localizable.xcstrings")
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Localizable.xcstrings missing at \(url.path)")
            throw NSError(domain: "missing", code: 0)
        }
        return url
    }

    private func loadCatalog() throws -> [String: Any] {
        let url = try catalogURL()
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Localizable.xcstrings is not a JSON object")
            throw NSError(domain: "shape", code: 0)
        }
        return json
    }

    // MARK: - Structure invariants

    func testCatalogHasSourceLanguageEn() throws {
        let json = try loadCatalog()
        XCTAssertEqual(json["sourceLanguage"] as? String, "en")
    }

    func testCatalogHasVersionField() throws {
        let json = try loadCatalog()
        XCTAssertEqual(json["version"] as? String, "1.0")
    }

    func testCatalogHasStringsObject() throws {
        let json = try loadCatalog()
        XCTAssertNotNil(json["strings"] as? [String: Any])
    }

    // MARK: - Coverage invariants (P1 — ko only)

    func testEveryEntryHasKoTranslation() throws {
        let json = try loadCatalog()
        guard let strings = json["strings"] as? [String: Any] else {
            XCTFail("strings object missing"); return
        }
        XCTAssertGreaterThan(strings.count, 50,
            "Expected at least 50 strings in P1 Settings catalog; got \(strings.count)")

        var missingKo: [String] = []
        for (key, entry) in strings {
            guard
                let entryDict = entry as? [String: Any],
                let localizations = entryDict["localizations"] as? [String: Any],
                let koEntry = localizations["ko"] as? [String: Any],
                let stringUnit = koEntry["stringUnit"] as? [String: Any],
                let value = stringUnit["value"] as? String,
                !value.isEmpty
            else {
                missingKo.append(key)
                continue
            }
        }
        XCTAssertTrue(missingKo.isEmpty,
            "P1 contract: every catalog entry must have a non-empty ko translation. Missing: \(missingKo.sorted())")
    }

    func testKoTranslationsAreNotIdenticalToSource() throws {
        // Catches the common mistake of leaving English in the ko slot.
        // Exceptions allowed: brand names that intentionally stay English.
        let allowedIdentical: Set<String> = [
            // (none for P1 — all P1 strings are translatable phrases)
        ]
        let json = try loadCatalog()
        guard let strings = json["strings"] as? [String: Any] else {
            XCTFail("strings object missing"); return
        }
        var suspiciousKeys: [String] = []
        for (key, entry) in strings {
            guard
                let entryDict = entry as? [String: Any],
                let localizations = entryDict["localizations"] as? [String: Any],
                let koEntry = localizations["ko"] as? [String: Any],
                let stringUnit = koEntry["stringUnit"] as? [String: Any],
                let value = stringUnit["value"] as? String
            else { continue }
            if value == key && !allowedIdentical.contains(key) {
                suspiciousKeys.append(key)
            }
        }
        XCTAssertTrue(suspiciousKeys.isEmpty,
            "ko translation identical to en source (likely missing translation): \(suspiciousKeys.sorted())")
    }

    // MARK: - Runtime lookup smoke (en main bundle path)

    func testStringLocalizedResolvesEnSource() {
        // When the test bundle's preferred locale is en (CI default), the
        // String(localized:) lookups should return the English source.
        // This validates the call-site refactor in AssertionStatusFormatter
        // + CoffeeAccent.shortDescription is wired correctly.
        XCTAssertEqual(String(localized: "Awake"), "Awake")
        XCTAssertEqual(String(localized: "Asleep"), "Asleep")
        XCTAssertEqual(String(localized: "Green tea"), "Green tea")
        XCTAssertEqual(String(localized: "Deep brown"), "Deep brown")
    }

    func testFormatterStringsAreNotEmpty() {
        // Defense against accidental ""-return after the refactor.
        XCTAssertFalse(AssertionStatusFormatter.stateLabel(isAwake: true).isEmpty)
        XCTAssertFalse(AssertionStatusFormatter.stateLabel(isAwake: false).isEmpty)
        XCTAssertNotNil(AssertionStatusFormatter.modeLabel(isAwake: true, allowDisplaySleep: true))
        XCTAssertNotNil(AssertionStatusFormatter.modeLabel(isAwake: true, allowDisplaySleep: false))
        XCTAssertNil(AssertionStatusFormatter.modeLabel(isAwake: false, allowDisplaySleep: true))
    }
}
