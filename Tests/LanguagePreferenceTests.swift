import XCTest
@testable import Latte

final class LanguagePreferenceTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "com.araforge.latte.tests.LanguagePreference"

    override func setUp() {
        super.setUp()
        let suite = UserDefaults(suiteName: suiteName)
        suite?.removePersistentDomain(forName: suiteName)
        defaults = suite
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Static catalog invariants

    func testSupportedListIs11Languages() {
        XCTAssertEqual(LanguagePreference.supported.count, 11,
            "P1 contract: 11 languages must remain in sync with project.yml knownRegions")
    }

    func testSupportedListMirrorsXcstringsKnownRegions() {
        let codes = Set(LanguagePreference.supported.map(\.code))
        let expected: Set<String> = [
            "en", "ko", "ja", "zh-Hans", "zh-Hant",
            "es", "de", "fr", "pt-BR", "it", "ru"
        ]
        XCTAssertEqual(codes, expected,
            "Supported list must mirror project.yml knownRegions + xcstrings localizations exactly")
    }

    func testSupportedCodesAreUnique() {
        let codes = LanguagePreference.supported.map(\.code)
        XCTAssertEqual(Set(codes).count, codes.count,
            "Duplicate codes would break Picker selection identity")
    }

    func testNativeNamesAreNonEmpty() {
        for option in LanguagePreference.supported {
            XCTAssertFalse(option.nativeName.isEmpty,
                "\(option.code) must have a native name for the onboarding button")
        }
    }

    // MARK: - Pure resolver (no UserDefaults — works on any host machine)

    func testResolveReturnsEnglishWhenRawIsNil() {
        XCTAssertEqual(LanguagePreference.resolve(rawLanguages: nil), "en")
    }

    func testResolveReturnsEnglishWhenRawIsEmpty() {
        XCTAssertEqual(LanguagePreference.resolve(rawLanguages: []), "en")
    }

    func testResolveReturnsExactMatch() {
        XCTAssertEqual(LanguagePreference.resolve(rawLanguages: ["ko"]), "ko")
        XCTAssertEqual(LanguagePreference.resolve(rawLanguages: ["pt-BR"]), "pt-BR")
    }

    func testResolveFoldsRegionTaggedSystemValue() {
        // macOS often stores ["ko-KR"] when the user picks Korean in
        // System Settings → Language & Region. We must resolve it
        // back to the supported "ko" so the Picker reflects reality.
        XCTAssertEqual(LanguagePreference.resolve(rawLanguages: ["ko-KR"]), "ko")
    }

    func testResolveFoldsPortugueseVariantToPtBR() {
        // "pt-PT" should resolve to "pt-BR" since we only ship one
        // Portuguese variant — closer than the "en" fallback.
        XCTAssertEqual(LanguagePreference.resolve(rawLanguages: ["pt-PT"]), "pt-BR")
    }

    func testResolveFallsBackToEnglishForUnknownLanguage() {
        XCTAssertEqual(LanguagePreference.resolve(rawLanguages: ["xx-Latn"]), "en")
    }

    // MARK: - UserDefaults round-trip (writes are isolated to the suite)

    func testApplyWritesToAppleLanguagesAndRoundTrips() {
        LanguagePreference.apply("ko", to: defaults)
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["ko"])
    }

    func testApplyIgnoresUnsupportedCode() {
        LanguagePreference.apply("ko", to: defaults)
        LanguagePreference.apply("xx-Latn", to: defaults)
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["ko"],
            "Unsupported codes must not corrupt the persisted selection")
    }
}
