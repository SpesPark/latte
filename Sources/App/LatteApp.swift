import AppKit
import Combine
import SwiftUI

/// AppKit delegate so we can run boot logic at `applicationDidFinishLaunching`
/// instead of inside the menu-bar popover's `.task`. The popover-based path
/// caused the popover to render alongside the onboarding wizard at first
/// launch (owner S8b smoke feedback).
@MainActor
final class LatteAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    /// Whether the menu-bar icon should be inserted right now. Bound via
    /// `MenuBarExtra(_:systemImage:isInserted:)` so we can hide the icon
    /// while the onboarding wizard is up — owner asked for the wizard to
    /// be the only on-screen UI during first launch.
    @Published var menuBarVisible: Bool = true

    private var onboardingObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = AppEnvironment.shared
        // Sync menu-bar visibility to onboarding state. Hidden while
        // onboarding is active; visible afterward.
        menuBarVisible = env.onboarding.hasCompletedOnboarding
        onboardingObservation = env.onboarding.$hasCompletedOnboarding
            .receive(on: RunLoop.main)
            .sink { [weak self] completed in
                self?.menuBarVisible = completed
            }
        Task { @MainActor in
            await env.bootTriggers()
            if !env.onboarding.hasCompletedOnboarding {
                OnboardingWindowController.shared.show(
                    state: env.onboarding,
                    coordinator: env.coordinator,
                    environment: env
                )
            } else {
                // Belt-and-suspenders: applyActivateOnLaunchIfEnabled
                // gates internally on `hasCompletedOnboarding` too, but
                // routing the call through this branch keeps the boot
                // path's intent explicit at the call site.
                env.applyActivateOnLaunchIfEnabled()
            }
        }
    }

    /// AppKit calls this when the app is launched (or already running) with one
    /// or more `latte://` URLs. Used by `smoke-harness` to open Settings on a
    /// specific tab without requiring Accessibility / UI scripting permissions.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let route = SettingsURLHandler.parseRoute(url) {
                let env = AppEnvironment.shared
                SettingsWindowController.shared.show(
                    manager: env.manager,
                    coordinator: env.coordinator,
                    environment: env,
                    initialTab: route.tab,
                    focusedTriggerId: route.focusedTriggerId
                )
            } else if let target = DemoURLHandler.parse(url) {
                switch target {
                case .cup(let config):
                    DemoCupWindowController.shared.show(config: config)
                }
            }
        }
    }
}

@main
struct LatteApp: App {

    @NSApplicationDelegateAdaptor(LatteAppDelegate.self) private var appDelegate
    /// Observe the singleton `AppEnvironment`. Singleton is needed so the
    /// `LatteAppDelegate` (instantiated by AppKit, separate from SwiftUI's
    /// @StateObject lifecycle) can reach the same instance.
    @ObservedObject private var environment = AppEnvironment.shared
    /// Observe the shared awake manager directly so SwiftUI re-evaluates
    /// the `body` (and the `MenuBarExtra` `systemImage`) on every
    /// `isAwake` transition. Without this observation the menu-bar icon
    /// would never update when triggers vote on/off (V2-01, S8b).
    @ObservedObject private var manager = AwakeManager.shared

    init() {
        AwakeManager.installSignalHandlers()
    }

    var body: some Scene {
        MenuBarExtra(
            "Latte",
            systemImage: environment.menuBarIconStyle.symbolName(awake: manager.isAwake),
            isInserted: Binding(
                get: { appDelegate.menuBarVisible },
                set: { appDelegate.menuBarVisible = $0 }
            )
        ) {
            MenuBarRoot(manager: environment.manager)
                .environmentObject(environment)
        }
        .menuBarExtraStyle(.window)
    }
}
