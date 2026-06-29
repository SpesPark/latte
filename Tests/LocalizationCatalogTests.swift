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

    /// Pulls the localized string value out of a per-language entry.
    /// xcstrings supports two shapes: a flat `stringUnit.value` for simple
    /// keys, and a `variations.plural.{one,few,many,other,…}` map for
    /// plural-aware keys. Returns the first non-empty value found —
    /// preferring `other` (always present per CLDR) and falling back to
    /// other forms — so coverage tests treat both shapes uniformly.
    private func extractValue(from langEntry: [String: Any]) -> String? {
        if let stringUnit = langEntry["stringUnit"] as? [String: Any],
           let value = stringUnit["value"] as? String,
           !value.isEmpty {
            return value
        }
        if let variations = langEntry["variations"] as? [String: Any],
           let plural = variations["plural"] as? [String: Any] {
            for form in ["other", "one", "few", "many", "two", "zero"] {
                if let formEntry = plural[form] as? [String: Any],
                   let stringUnit = formEntry["stringUnit"] as? [String: Any],
                   let value = stringUnit["value"] as? String,
                   !value.isEmpty {
                    return value
                }
            }
        }
        return nil
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
                    extractValue(from: langEntry) != nil
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
                extractValue(from: koEntry) != nil
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
                let value = extractValue(from: koEntry)
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

    // MARK: - Russian CLDR plural forms

    /// Russian cardinals require four CLDR forms (one/few/many/other), not the
    /// two (one/other) the S35 migration shipped as a baseline. The pre-fix
    /// `one` slot also hard-coded the literal "1" ("1 минута"), which is
    /// CLDR-wrong: n = 21, 31, 101… are also Russian `one` but rendered via
    /// `other` ("%lld минут" → "21 минут", grammatically incorrect; correct is
    /// "21 минута"). Lock in: all four forms present AND every form keeps the
    /// `%lld` placeholder so the count renders for 21/31/… too.
    func testRussianPluralKeysHaveAllFourCLDRForms() throws {
        let json = try loadCatalog()
        guard let strings = json["strings"] as? [String: Any] else {
            XCTFail("strings object missing"); return
        }
        let pluralKeys = ["%lld minutes", "%lld hours", "Currently: %lld external displays"]
        let required = ["one", "few", "many", "other"]
        for key in pluralKeys {
            guard
                let entry = strings[key] as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any],
                let ru = localizations["ru"] as? [String: Any],
                let variations = ru["variations"] as? [String: Any],
                let plural = variations["plural"] as? [String: Any]
            else {
                XCTFail("ru variations.plural missing for key \(key.debugDescription)")
                continue
            }
            for form in required {
                guard
                    let formEntry = plural[form] as? [String: Any],
                    let stringUnit = formEntry["stringUnit"] as? [String: Any],
                    let value = stringUnit["value"] as? String,
                    !value.isEmpty
                else {
                    XCTFail("ru \(key.debugDescription) missing non-empty CLDR form \(form.debugDescription)")
                    continue
                }
                XCTAssertTrue(value.contains("%lld"),
                    "ru \(key.debugDescription) form \(form.debugDescription) lost the %lld placeholder (\(value.debugDescription)); n=21/31/… would not show the count")
            }
        }
    }
}
