import AppKit
import XCTest
@testable import Latte

/// Regression coverage for the first-run lockout bug: the onboarding window
/// carries a title-bar close button (`.closable`), but the wizard only marks
/// onboarding complete from its own Skip / Finish buttons. If the user closed
/// the window with the X button, `markCompleted()` was never called, so
/// `hasCompletedOnboarding` stayed false and — because the menu-bar item is
/// gated on that flag — the LSUIElement app was left with NO UI surface for
/// the rest of the session.
///
/// The fix wires the controller as the window's `NSWindowDelegate` and treats
/// a user-initiated close like Skip (finalize onboarding so the menu bar
/// surfaces). These tests pin that contract at the delegate seam without
/// standing up a full `AppEnvironment` / `NSHostingController`.
@MainActor
final class OnboardingWindowControllerTests: XCTestCase {

    func testUserClosingWindowFinalizesOnboarding() {
        let settings = InMemorySettingsStore()
        let state = OnboardingState(settings: settings)
        XCTAssertFalse(state.hasCompletedOnboarding)

        let controller = OnboardingWindowController()
        controller.state = state

        // Simulate the title-bar X: AppKit posts willClose to the delegate.
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))

        XCTAssertTrue(
            state.hasCompletedOnboarding,
            "Closing the onboarding window via the title-bar button must finalize onboarding so the menu bar appears"
        )
        XCTAssertTrue(settings.bool(.firstRunCompleted, default: false))
    }

    func testWindowWillCloseIsIdempotentWhenAlreadyCompleted() {
        let settings = InMemorySettingsStore()
        let state = OnboardingState(settings: settings)
        state.markCompleted()
        XCTAssertTrue(state.hasCompletedOnboarding)

        let controller = OnboardingWindowController()
        controller.state = state
        // A second close (e.g. programmatic + user) must not crash or regress.
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))

        XCTAssertTrue(state.hasCompletedOnboarding)
    }
}
