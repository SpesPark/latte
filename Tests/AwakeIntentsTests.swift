import XCTest
@testable import Latte

/// Coverage for the out-of-process AppIntents (Shortcuts / Spotlight) — the
/// only public entry point a user can invoke independently of the UI. They
/// delegate to `AwakeManager.shared`, so — like `AppEnvironmentTests` — reset
/// the singleton before and after each test to prevent awake-state leaking
/// across cases.
@MainActor
final class AwakeIntentsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AwakeManager.shared.deactivate()
    }

    override func tearDown() {
        AwakeManager.shared.deactivate()
        super.tearDown()
    }

    func testToggleIntentWakesFromAsleep() async throws {
        XCTAssertFalse(AwakeManager.shared.isAwake)
        _ = try await ToggleAwakeIntent().perform()
        XCTAssertTrue(AwakeManager.shared.isAwake,
                      "toggle from asleep must acquire the assertion")
    }

    func testToggleIntentSleepsFromAwake() async throws {
        _ = try await StartAwakeIntent(minutes: 30).perform()
        XCTAssertTrue(AwakeManager.shared.isAwake)
        _ = try await ToggleAwakeIntent().perform()
        XCTAssertFalse(AwakeManager.shared.isAwake,
                       "toggle from awake must release the assertion")
    }

    func testStartIntentActivatesForGivenMinutes() async throws {
        let minutes = 30
        let before = Date()
        _ = try await StartAwakeIntent(minutes: minutes).perform()
        XCTAssertTrue(AwakeManager.shared.isAwake)
        let endsAt = try XCTUnwrap(AwakeManager.shared.endsAt)
        let expected = before.addingTimeInterval(Double(minutes) * 60)
        XCTAssertEqual(endsAt.timeIntervalSinceReferenceDate,
                       expected.timeIntervalSinceReferenceDate,
                       accuracy: 5,
                       "timed activation deadline should be ~minutes from now")
    }

    /// `StartAwakeIntent` re-declares the 1...1440 minutes range as a literal
    /// (the @Parameter macro needs a compile-time literal). Guard both ends.
    func testStartIntentHonorsMinuteBoundaries() async throws {
        for minutes in [1, 1440] {
            AwakeManager.shared.deactivate()
            let before = Date()
            _ = try await StartAwakeIntent(minutes: minutes).perform()
            XCTAssertTrue(AwakeManager.shared.isAwake, "minutes=\(minutes) must activate")
            let endsAt = try XCTUnwrap(AwakeManager.shared.endsAt)
            let expected = before.addingTimeInterval(Double(minutes) * 60)
            XCTAssertEqual(endsAt.timeIntervalSinceReferenceDate,
                           expected.timeIntervalSinceReferenceDate,
                           accuracy: 5,
                           "minutes=\(minutes) deadline should be ~minutes from now")
        }
    }

    func testStopIntentDeactivates() async throws {
        _ = try await StartAwakeIntent(minutes: 30).perform()
        XCTAssertTrue(AwakeManager.shared.isAwake)
        _ = try await StopAwakeIntent().perform()
        XCTAssertFalse(AwakeManager.shared.isAwake)
    }
}
