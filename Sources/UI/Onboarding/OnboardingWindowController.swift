import AppKit
import SwiftUI

/// Same pattern as `SettingsWindowController`: hosts `OnboardingView` in
/// a real `NSWindow` so the LSUIElement (menu-bar-only) app can present
/// a foreground window. Owns one window for the lifetime of the app.
///
/// Lifecycle: presented on app launch when `OnboardingState.hasCompletedOnboarding`
/// is false. The wizard's `onClose` callback marks state and dismisses
/// the window. Subsequent launches do not present.
///
/// The window carries a title-bar close button. Dismissing it that way
/// bypasses the wizard's Skip / Finish buttons, so the controller acts as
/// the window's `NSWindowDelegate` and treats a user-initiated close like
/// Skip — finalizing onboarding so the menu-bar item (gated on
/// `hasCompletedOnboarding`) surfaces. Without this, closing the window with
/// the X button leaves the LSUIElement app with no UI for the session.
@MainActor
public final class OnboardingWindowController: NSObject, NSWindowDelegate {

    public static let shared = OnboardingWindowController()

    private var window: NSWindow?

    /// The onboarding state to finalize when the window is closed by the user.
    /// Captured in `show()`; held weakly because `AppEnvironment` owns it for
    /// the app's lifetime. Internal (not private) so the delegate seam is
    /// unit-testable without standing up a real window.
    weak var state: OnboardingState?

    override init() { super.init() }

    public func show(
        state: OnboardingState,
        coordinator: TriggerCoordinator,
        environment: AppEnvironment
    ) {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = OnboardingView(
            state: state,
            coordinator: coordinator,
            onClose: { [weak self] in self?.close() }
        )
        .environmentObject(environment)
        let host = NSHostingController(rootView: root)

        let newWindow = NSWindow(contentViewController: host)
        newWindow.title = "Welcome to Latte"
        newWindow.styleMask = [.titled, .closable]
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        newWindow.setFrameAutosaveName("LatteOnboardingWindow")
        newWindow.delegate = self

        self.state = state
        self.window = newWindow
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
    }

    public func close() {
        // Programmatic dismissal (wizard Skip / Finish already marked the
        // state). `orderOut` does not post `willClose`, so this never
        // double-fires the delegate path below.
        window?.orderOut(nil)
        window = nil
    }

    /// The user dismissed the onboarding window with the title-bar close
    /// button (rather than the wizard's Skip / Finish). Treat it like Skip:
    /// finalize onboarding so the menu bar surfaces. `markCompleted()` is
    /// idempotent, so this is safe even if onboarding was already finished.
    public func windowWillClose(_ notification: Notification) {
        state?.markCompleted()
        window = nil
    }
}
