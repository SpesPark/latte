import XCTest
@testable import Latte

@MainActor
final class OnboardingStateTests: XCTestCase {

    func testHasCompletedFalseByDefault() {
        let settings = InMemorySettingsStore()
        let state = OnboardingState(settings: settings)
        XCTAssertFalse(state.hasCompletedOnboarding)
    }

    func testHasCompletedTrueIfPersistedFlagIsTrue() {
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .firstRunCompleted)
        let state = OnboardingState(settings: settings)
        XCTAssertTrue(state.hasCompletedOnboarding)
    }

    func testMarkCompletedFlipsFlagAndStampsDate() {
        let fixed = Date(timeIntervalSince1970: 1_750_000_000)
        let settings = InMemorySettingsStore()
        let state = OnboardingState(settings: settings, dateProvider: { fixed })
        state.markCompleted()
        XCTAssertTrue(state.hasCompletedOnboarding)
        XCTAssertTrue(settings.bool(.firstRunCompleted, default: false))
        XCTAssertEqual(
            settings.double(.firstRunCompletedAt, default: -1),
            fixed.timeIntervalSince1970
        )
    }

    func testMarkCompletedIsIdempotent() {
        var calls = 0
        let provider: @Sendable () -> Date = {
            calls += 1
            return Date(timeIntervalSince1970: 100)
        }
        let settings = InMemorySettingsStore()
        let state = OnboardingState(settings: settings, dateProvider: provider)
        state.markCompleted()
        state.markCompleted()
        state.markCompleted()
        // Date provider only consulted on the first markCompleted.
        XCTAssertEqual(calls, 1, "Date provider should only run on the first markCompleted call")
    }

    func testResetClearsFlagAndDate() {
        let settings = InMemorySettingsStore()
        let state = OnboardingState(settings: settings)
        state.markCompleted()
        XCTAssertTrue(state.hasCompletedOnboarding)
        state.reset()
        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertFalse(settings.bool(.firstRunCompleted, default: true))
        // Date stamp is removed (not just zeroed).
        XCTAssertEqual(settings.double(.firstRunCompletedAt, default: -1), -1)
    }
}
