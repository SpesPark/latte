import AppKit
import SwiftUI

/// Same pattern as `SettingsWindowController`: hosts `OnboardingView` in
/// a real `NSWindow` so the LSUIElement (menu-bar-only) app can present
/// a foreground window. Owns one window for the lifetime of the app.
///
/// Lifecycle: presented on app launch when `OnboardingState.hasCompletedOnboarding`
/// is false. The wizard's `onClose` callback marks state and dismisses
/// the window. Subsequent launches do not present.
@MainActor
public final class OnboardingWindowController {

    public static let shared = OnboardingWindowController()

    private var window: NSWindow?

    private init() {}

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

        self.window = newWindow
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
    }

    public func close() {
        window?.orderOut(nil)
        window = nil
    }
}
