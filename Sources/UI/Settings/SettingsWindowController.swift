import AppKit
import SwiftUI

/// Hosts `SettingsRoot` in a real `NSWindow` instead of relying on SwiftUI's
/// `Settings { }` scene. `Settings { }` does not reliably wire into the menu
/// system for `LSUIElement` (menu-bar-only) apps, so `SettingsLink` and
/// `Selector(("showSettingsWindow:"))` both no-op silently.
///
/// This controller owns one window for the lifetime of the app, brings it to
/// front on each `show()`, and reuses the same instance on subsequent calls.
@MainActor
public final class SettingsWindowController {

    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    public func show(manager: AwakeManager, coordinator: TriggerCoordinator, environment: AppEnvironment) {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = SettingsRoot(manager: manager, coordinator: coordinator)
            .environmentObject(environment)
        let host = NSHostingController(rootView: root)

        let newWindow = NSWindow(contentViewController: host)
        newWindow.title = "Latte Settings"
        newWindow.styleMask = [.titled, .closable, .miniaturizable]
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        newWindow.setFrameAutosaveName("LatteSettingsWindow")

        self.window = newWindow
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
    }
}
