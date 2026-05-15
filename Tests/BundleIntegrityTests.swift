import XCTest
@testable import Latte

/// Verifies the *built* `Latte.app` bundle actually contains the localization
/// `.lproj` directories and asset catalog. Catches the regression class that
/// surfaced in S33: xcodegen 2.45.4 silently dropped the `resources:` block,
/// so Localizable.xcstrings (1188 cells across S31~S33) and AppIcon never
/// shipped despite tests + JSON-level catalog validation + smoke all passing.
/// Bundle-level inspection is the only verification that proves i18n work
/// reaches end users.
final class BundleIntegrityTests: XCTestCase {

    /// 11 languages declared in `project.yml` `knownRegions` (S31).
    /// en is source; the other 10 are translation targets (ko + Phase H 9).
    private static let expectedLocalizations: Set<String> = [
        "en", "ko", "ja", "zh-Hans", "zh-Hant",
        "es", "de", "fr", "pt-BR", "it", "ru",
    ]

    private func appBundleURL() throws -> URL {
        // In a hosted macOS unit test (bundle.unit-test + Latte dependency),
        // the test bundle lives at `Latte.app/Contents/PlugIns/LatteTests.xctest`
        // and `Bundle.main` resolves to the host `Latte.app`. That is the
        // simplest and most reliable path.
        let mainURL = Bundle.main.bundleURL
        if mainURL.pathExtension == "app",
           FileManager.default.fileExists(atPath: mainURL.path) {
            return mainURL
        }
        // Fallback for non-hosted invocations (direct swift-test, future
        // refactor): walk up from the test bundle URL until we hit a `.app`.
        var url = Bundle(for: type(of: self)).bundleURL
        for _ in 0..<8 {
            if url.pathExtension == "app",
               FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            let parent = url.deletingLastPathComponent()
            if parent == url { break }
            url = parent
        }
        throw XCTSkip(
            "Latte.app not resolvable from Bundle.main or test-bundle walk " +
            "— bundle integrity check requires the app target to have built " +
            "alongside tests."
        )
    }

    /// S33 P0 failed this invariant exactly: 0 `.lproj` instead of 11.
    func testBundleContainsAllKnownRegionLproj() throws {
        let appURL = try appBundleURL()
        let resourcesURL = appURL.appendingPathComponent("Contents/Resources")
        let contents = try FileManager.default.contentsOfDirectory(
            atPath: resourcesURL.path
        )
        let lprojNames = Set(
            contents
                .filter { $0.hasSuffix(".lproj") }
                .map { String($0.dropLast(".lproj".count)) }
        )
        let missing = Self.expectedLocalizations.subtracting(lprojNames)
        XCTAssertTrue(
            missing.isEmpty,
            "Bundle missing .lproj for: " +
            "\(missing.sorted().joined(separator: ", ")). " +
            "Found: \(lprojNames.sorted().joined(separator: ", "))."
        )
    }

    /// S33 P0 also dropped `Assets.car`; app icon fell back to macOS placeholder.
    func testBundleContainsAssetsCar() throws {
        let appURL = try appBundleURL()
        let assetsURL = appURL.appendingPathComponent("Contents/Resources/Assets.car")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: assetsURL.path),
            "Bundle missing Assets.car — app icon and accent colour would " +
            "fall back to system defaults. Path checked: \(assetsURL.path)."
        )
    }

    /// Spot-check: a single owner-reviewed Korean string actually lands in the
    /// shipped `ko.lproj/Localizable.strings`. "Awake" → "깨어 있음" is the
    /// S31 anchor that the owner hand-reviewed; verified post-fix in S33.
    /// If S31~S33 catalog cells stop reaching the bundle for any reason, this
    /// surfaces immediately instead of waiting for a user report.
    func testKoreanResourceFileContainsKoreanTranslation() throws {
        let appURL = try appBundleURL()
        let stringsURL = appURL.appendingPathComponent(
            "Contents/Resources/ko.lproj/Localizable.strings"
        )
        guard FileManager.default.fileExists(atPath: stringsURL.path) else {
            XCTFail("ko.lproj/Localizable.strings missing at \(stringsURL.path)")
            return
        }
        guard let dict = NSDictionary(contentsOf: stringsURL) as? [String: String] else {
            XCTFail(
                "ko.lproj/Localizable.strings at \(stringsURL.path) could " +
                "not be parsed as a plist dictionary (format may have changed)."
            )
            return
        }
        XCTAssertEqual(
            dict["Awake"], "깨어 있음",
            "ko.lproj 'Awake' should map to '깨어 있음' (owner-reviewed S31 " +
            "anchor). Got: \(dict["Awake"] ?? "<missing>")."
        )
    }
}
