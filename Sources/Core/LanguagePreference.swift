import Foundation
import os

/// Catalog of the 11 P1-supported display languages plus thin
/// `AppleLanguages` read/write helpers used by the Onboarding
/// LanguageStep (S32 Phase D) and the Settings Language Picker
/// (S32 Phase E).
///
/// AppleLanguages is a system-defined UserDefaults key macOS
/// consults at launch to pick the runtime locale; writing to it
/// takes effect on the **next** launch. We therefore advertise
/// "Restart Latte to apply" in the Settings caption — in-flight
/// `String(localized:)` lookups read tables resolved at startup
/// and won't flip mid-run regardless of `.environment(\.locale)`.
public enum LanguagePreference {

    public struct Option: Identifiable, Hashable, Sendable {
        /// BCP-47 code — matches an `xcstrings` localizations key
        /// and `project.yml`'s `knownRegions` entry.
        public let code: String
        /// Shown verbatim in the picker — never translated.
        public let nativeName: String

        public var id: String { code }

        public init(code: String, nativeName: String) {
            self.code = code
            self.nativeName = nativeName
        }
    }

    /// Ordered for the Onboarding picker: owner's language first,
    /// then English baseline, then by geographic / script proximity.
    /// Must stay in sync with `project.yml` `knownRegions` and
    /// `Resources/Localizable.xcstrings` localizations — covered by
    /// `LanguagePreferenceTests.testSupportedListCoversAllXcstringsLocales`.
    public static let supported: [Option] = [
        Option(code: "ko",      nativeName: "한국어"),
        Option(code: "en",      nativeName: "English"),
        Option(code: "ja",      nativeName: "日本語"),
        Option(code: "zh-Hans", nativeName: "中文"),
        Option(code: "zh-Hant", nativeName: "繁體中文"),
        Option(code: "es",      nativeName: "Español"),
        Option(code: "de",      nativeName: "Deutsch"),
        Option(code: "fr",      nativeName: "Français"),
        Option(code: "pt-BR",   nativeName: "Português"),
        Option(code: "it",      nativeName: "Italiano"),
        Option(code: "ru",      nativeName: "Русский"),
    ]

    static let appleLanguagesKey = "AppleLanguages"

    /// First supported code from AppleLanguages, falling back to
    /// `"en"` (catalog source language) when unset or unrecognised.
    /// Region-tagged system values ("ko-KR", "pt-PT", "zh-HK") fold
    /// to the closest supported code by language prefix.
    public static func current(in defaults: UserDefaults = .standard) -> String {
        resolve(rawLanguages: defaults.stringArray(forKey: appleLanguagesKey))
    }

    /// Pure resolver — exposed for unit tests so they don't depend on
    /// UserDefaults suite isolation (AppleLanguages lookup chains
    /// through `NSGlobalDomain`, so a fresh suite still returns the
    /// host machine's system language).
    public static func resolve(rawLanguages raw: [String]?) -> String {
        guard let first = raw?.first else { return "en" }
        if let exact = supported.first(where: { $0.code == first }) {
            return exact.code
        }
        let prefix = first.split(separator: "-").first.map(String.init) ?? first
        if let byPrefix = supported.first(where: { option in
            option.code == prefix ||
            option.code.split(separator: "-").first.map(String.init) == prefix
        }) {
            return byPrefix.code
        }
        return "en"
    }

    /// Writes `[code]` to AppleLanguages so the next launch boots in
    /// the chosen language. Silently ignored when `code` is not in
    /// `supported` — guards the system key against typos.
    public static func apply(_ code: String, to defaults: UserDefaults = .standard) {
        guard supported.contains(where: { $0.code == code }) else {
            logger.notice("ignoring apply for unsupported code \(code, privacy: .public)")
            return
        }
        defaults.set([code], forKey: appleLanguagesKey)
        logger.info("applied AppleLanguages = [\(code, privacy: .public)]")
    }

    private static let logger = Logger(subsystem: "com.araforge.latte", category: "i18n")
}
