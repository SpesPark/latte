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
public final class SettingsWindowController: NSObject, NSWindowDelegate {

    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() { super.init() }

    /// Show the Settings window. If `initialTab` is supplied AND the window
    /// is being created for the first time this session, the given tab is
    /// pre-selected. On subsequent calls the user's last selection is kept
    /// (per macOS HIG — don't yank the user out of where they were).
    ///
    /// LSUIElement apps have `.accessory` activation policy by default, which
    /// makes `NSApp.activate(ignoringOtherApps: true)` a near-no-op for
    /// non-status-bar windows. We temporarily promote to `.regular` so the
    /// Settings window comes to the front, and restore `.accessory` when the
    /// window closes (via `NSWindowDelegate`).
    public func show(
        manager: AwakeManager,
        coordinator: TriggerCoordinator,
        environment: AppEnvironment,
        initialTab: SettingsTab = .general,
        focusedTriggerId: String? = nil
    ) {
        NSApp.setActivationPolicy(.regular)

        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            // Existing-window path: re-emit the focus signal so a second
            // `latte://settings/triggers?focus=wifi` still scrolls.
            if let focusedTriggerId {
                NotificationCenter.default.post(
                    name: .settingsRequestFocusTrigger,
                    object: focusedTriggerId
                )
            }
            return
        }

        let root = SettingsRoot(
            manager: manager,
            coordinator: coordinator,
            initialTab: initialTab,
            initialFocusedTriggerId: focusedTriggerId
        )
            .environmentObject(environment)
        let host = NSHostingController(rootView: root)

        let newWindow = NSWindow(contentViewController: host)
        newWindow.title = String(localized: "Latte Settings")
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        newWindow.isReleasedWhenClosed = false
        newWindow.setContentSize(NSSize(
            width: SettingsRoot.minWindowWidth,
            height: SettingsRoot.minWindowHeight
        ))
        newWindow.center()
        newWindow.setFrameAutosaveName("LatteSettingsWindow")
        newWindow.delegate = self

        self.window = newWindow
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        // Drop back to accessory so we don't leave a Dock icon behind once
        // the user dismisses the Settings window.
        NSApp.setActivationPolicy(.accessory)
    }
}
