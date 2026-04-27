import AppKit
import SwiftUI

/// Hosts a single `CoffeeCupView` in its own borderless window for marketing
/// capture (Shot 1 in `docs/store/screenshot-guide.md`). The harness opens
/// this window via `latte://demo/cup?fill=...&accent=...` and uses
/// `screencapture -l <wid>` to grab the deterministic surface.
///
/// Why a dedicated window: the actual menu-bar popover requires a click on
/// the status item (mouse-position dependent, hard to script reliably). The
/// rendered cup view is identical to what the popover shows, so for App Store
/// marketing screenshots — which are about the visual content, not the OS
/// chrome — this is faithful.
@MainActor
public final class DemoCupWindowController: NSObject, NSWindowDelegate {

    public static let shared = DemoCupWindowController()

    private var window: NSWindow?

    private override init() { super.init() }

    public func show(config: DemoCupConfig) {
        NSApp.setActivationPolicy(.regular)

        if let window {
            window.contentView = NSHostingView(rootView: Self.makeRoot(config: config))
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: Self.makeRoot(config: config))
        let newWindow = NSWindow(contentViewController: hosting)
        // Title is still set so CGWindowListCopyWindowInfo can find this
        // window by title even though the bar is hidden.
        newWindow.title = "Latte Demo Cup"
        newWindow.styleMask = [.titled, .closable, .fullSizeContentView]
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.standardWindowButton(.closeButton)?.isHidden = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true
        newWindow.isMovableByWindowBackground = true
        newWindow.backgroundColor = NSColor.clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        newWindow.setContentSize(NSSize(width: 220, height: 220))
        newWindow.delegate = self

        self.window = newWindow
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private static func makeRoot(config: DemoCupConfig) -> some View {
        // Match the menu-bar popover's chrome — rounded background, clean
        // shadow, cup centered. This is what the App Store reviewer sees in
        // Shot 1, so it has to look like the real popover.
        VStack {
            CoffeeCupView(
                isAwake: config.isAwake,
                fillRatio: config.fillRatio,
                liquidColor: config.accent.color,
                size: 144
            )
        }
        .frame(width: 220, height: 220)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(nsColor: NSColor.windowBackgroundColor))
        )
    }
}
