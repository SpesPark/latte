import AppKit
import XCTest
@testable import Latte

/// Regression coverage for the first-run close path: the onboarding window
/// carries a title-bar close button (`.closable`), but the wizard only marks
/// onboarding complete from its own Skip / Finish buttons. If the user closed
/// the window with the X button, `markCompleted()` was never called, so
/// `hasCompletedOnboarding` stayed false.
///
/// The fix wires the controller as the window's `NSWindowDelegate` and treats
/// a user-initiated close like Skip (finalize onboarding). These tests pin that
/// contract at the delegate seam without standing up a full `AppEnvironment` /
/// `NSHostingController`.
///
/// NOTE (App Store rejection dc78a591, 2026-06-23, Guideline 2.1(a)): the
/// menu-bar item is no longer gated on `hasCompletedOnboarding` — `LatteApp`
/// keeps the `MenuBarExtra` permanently inserted, so the LSUIElement app can
/// never be left with NO UI surface even if onboarding is dismissed oddly.
/// Persisting completion here is now purely about NOT re-showing the wizard on
/// the next launch, rather than being the load-bearing line that surfaces the
/// menu bar. See the comment on `LatteApp.body`.
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

    /// `show()` assigning `newWindow.delegate = self` is the load-bearing
    /// line of the lockout fix — the seam tests in this file call
    /// `windowWillClose` directly, so without this assertion deleting that
    /// line would leave every test green while resurrecting the bug
    /// (S51 audit).
    func testShowWiresControllerAsWindowDelegate() {
        let settings = InMemorySettingsStore()
        let env = AppEnvironment(settings: settings)
        let state = OnboardingState(settings: settings)
        let controller = OnboardingWindowController()

        controller.show(state: state, coordinator: env.coordinator, environment: env)
        defer { controller.close() }

        XCTAssertNotNil(controller.window)
        XCTAssertTrue(
            controller.window?.delegate === controller,
            "show() must wire the controller as the window's NSWindowDelegate"
        )
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
