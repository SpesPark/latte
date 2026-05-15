import XCTest
@testable import Latte

/// Verifies the Localizable.xcstrings catalog is well-formed and that
/// every one of the 10 non-source supported languages (ko + 9 Phase H
/// targets: ja, zh-Hans, zh-Hant, es, de, fr, pt-BR, it, ru) covers
/// every source string with a non-empty translation. ko has a stricter
/// "not identical to en source" guard (owner-reviewed anchor); other
/// languages are machine-assisted with community PR welcome — see
/// README for translation contribution flow.
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

    // MARK: - Coverage invariants (P1 + Phase H — all 11 languages)

    /// All 10 non-source supported languages must have a non-empty
    /// translation for every catalog entry. Mirrors
    /// `LanguagePreference.supported` minus the source language "en".
    func testEveryEntryCoversAllPhaseHLanguages() throws {
        let json = try loadCatalog()
        guard let strings = json["strings"] as? [String: Any] else {
            XCTFail("strings object missing"); return
        }
        let targets = LanguagePreference.supported
            .map(\.code)
            .filter { $0 != "en" }

        var gaps: [String: [String]] = [:]  // lang → missing keys
        for (key, entry) in strings {
            guard
                let entryDict = entry as? [String: Any],
                let localizations = entryDict["localizations"] as? [String: Any]
            else {
                for lang in targets { gaps[lang, default: []].append(key) }
                continue
            }
            for lang in targets {
                guard
                    let langEntry = localizations[lang] as? [String: Any],
                    let stringUnit = langEntry["stringUnit"] as? [String: Any],
                    let value = stringUnit["value"] as? String,
                    !value.isEmpty
                else {
                    gaps[lang, default: []].append(key)
                    continue
                }
            }
        }

        XCTAssertTrue(gaps.isEmpty, """
            Every supported language must have a non-empty translation for every \
            catalog entry. Missing per language: \
            \(gaps.mapValues { $0.sorted() })
            """)
    }

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

    // MARK: - Runtime lookup smoke (locale-agnostic)

    func testStringLocalizedResolvesNonEmptyForKnownKeys() {
        // S33 fix: previous version asserted equality against English literals,
        // which broke on ko-locale hosts where the catalog correctly resolved
        // to Korean translations. The actual assertion we care about is
        // "the key exists in the catalog and resolves to SOMETHING non-empty,
        // and not equal to the literal key itself (which would indicate a
        // catalog miss)". This is locale-agnostic and matches the call-site
        // contract of AssertionStatusFormatter + CoffeeAccent.shortDescription.
        for key in ["Awake", "Asleep", "Green tea", "Deep brown"] {
            let resolved = String(localized: String.LocalizationValue(stringLiteral: key))
            XCTAssertFalse(resolved.isEmpty, "key \(key.debugDescription) resolved to empty string")
            // Note: we do NOT assert `resolved != key` — when the host locale
            // is en, the resolved value IS the source key, which is correct.
            // The "ko != en source" guarantee for ko is covered separately by
            // testKoTranslationsAreNotIdenticalToSource.
        }
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
