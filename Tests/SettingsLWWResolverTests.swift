import XCTest
@testable import Latte

/// Domain A (Settings) last-writer-wins resolver — pure, CloudKit-free
/// (docs/design/10 §6, §10). Phase 2 pre-built dark in S42; no live iCloud
/// needed. The activity log (Domain B) must NEVER reach this path — that is an
/// append-only union merge and lives elsewhere (§6 invariant).
final class SettingsLWWResolverTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Core LWW rule (strictly-later wins)

    func testRemoteStrictlyNewerWins() {
        let local = LWWRecord(value: 1, updatedAt: t0)
        let remote = LWWRecord(value: 2, updatedAt: t0.addingTimeInterval(1))
        XCTAssertEqual(SettingsLWWResolver.resolve(local: local, remote: remote), remote)
    }

    func testLocalStrictlyNewerWins() {
        let local = LWWRecord(value: 1, updatedAt: t0.addingTimeInterval(1))
        let remote = LWWRecord(value: 2, updatedAt: t0)
        XCTAssertEqual(SettingsLWWResolver.resolve(local: local, remote: remote), local)
    }

    // MARK: - Tie-break (conservative: keep local on exact equality)

    func testExactTimestampTieKeepsLocal() {
        // §3: settings are low-frequency single-user; a same-instant collision is
        // vanishingly rare and re-toggle-recoverable. Conservative rule: don't
        // clobber on a tie — adopt remote only when it is *strictly* newer.
        let local = LWWRecord(value: "local", updatedAt: t0)
        let remote = LWWRecord(value: "remote", updatedAt: t0)
        XCTAssertEqual(SettingsLWWResolver.resolve(local: local, remote: remote), local)
    }

    // MARK: - Purity / determinism

    func testResolutionIsDeterministic() {
        let local = LWWRecord(value: 1, updatedAt: t0)
        let remote = LWWRecord(value: 2, updatedAt: t0.addingTimeInterval(5))
        let first = SettingsLWWResolver.resolve(local: local, remote: remote)
        let second = SettingsLWWResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(first, second)
    }

    func testEqualValuesResolveRegardlessOfTimestamp() {
        // Identical values are not a real conflict; the result still equals that value.
        let local = LWWRecord(value: true, updatedAt: t0)
        let remote = LWWRecord(value: true, updatedAt: t0.addingTimeInterval(99))
        XCTAssertEqual(SettingsLWWResolver.resolve(local: local, remote: remote).value, true)
    }

    // MARK: - Generic over the settings value trichotomy

    func testResolvesStringValues() {
        let local = LWWRecord(value: "old", updatedAt: t0)
        let remote = LWWRecord(value: "new", updatedAt: t0.addingTimeInterval(10))
        XCTAssertEqual(SettingsLWWResolver.resolve(local: local, remote: remote).value, "new")
    }

    func testResolvesDataValues() {
        let local = LWWRecord(value: Data([0x01]), updatedAt: t0.addingTimeInterval(10))
        let remote = LWWRecord(value: Data([0x02]), updatedAt: t0)
        XCTAssertEqual(SettingsLWWResolver.resolve(local: local, remote: remote).value, Data([0x01]))
    }

    func testResolvesBoolValues() {
        let local = LWWRecord(value: false, updatedAt: t0)
        let remote = LWWRecord(value: true, updatedAt: t0.addingTimeInterval(2))
        XCTAssertEqual(SettingsLWWResolver.resolve(local: local, remote: remote).value, true)
    }

    // MARK: - Convenience winner reporting

    func testWinnerReportsRemoteWhenRemoteNewer() {
        let local = LWWRecord(value: 1, updatedAt: t0)
        let remote = LWWRecord(value: 2, updatedAt: t0.addingTimeInterval(1))
        XCTAssertEqual(SettingsLWWResolver.winner(local: local, remote: remote), .remote)
    }

    func testWinnerReportsLocalOnTie() {
        let local = LWWRecord(value: 1, updatedAt: t0)
        let remote = LWWRecord(value: 2, updatedAt: t0)
        XCTAssertEqual(SettingsLWWResolver.winner(local: local, remote: remote), .local)
    }
}
