import AppKit
import SwiftUI

/// AppKit delegate so we can run boot logic at `applicationDidFinishLaunching`
/// instead of inside the menu-bar popover's `.task`. The popover-based path
/// caused the popover to render alongside the onboarding wizard at first
/// launch (owner S8b smoke feedback).
@MainActor
final class LatteAppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = AppEnvironment.shared
        Task { @MainActor in
            await env.bootTriggers()
            // Dark in the default build (cloudSync nil, kill-switch off) —
            // no behaviour change. docs/design/10 §11 Phase 1.
            await env.startCloudSyncIfNeeded()
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
        // S25 / P-issue-4: pre-load activity entries off the boot path
        // so the user's first Activity tab visit doesn't pay the actor
        // hop + JSON decode cost on the first frame. Independent of
        // bootTriggers — runs in parallel so neither blocks the other.
        Task { @MainActor in
            await env.loadActivityEntriesEagerly()
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
        // The menu-bar item is ALWAYS inserted — never gated on onboarding.
        // App Store review (Submission dc78a591, 2026-06-23, Guideline 2.1(a))
        // rejected the build because the app "disappeared (no menubar extra,
        // menubar or Dock icon, but still active)" after onboarding. Root
        // cause: this used to bind `isInserted:` to onboarding state to hide
        // the icon during the wizard, then re-insert on completion. That
        // `false → true` re-insertion of a SwiftUI `MenuBarExtra` is
        // unreliable (esp. macOS 26), and since the app is `LSUIElement`
        // (no Dock icon), a failed re-insert leaves NO interactive surface —
        // a zombie process. Keeping the extra permanently inserted removes
        // the fragile path entirely; the onboarding window simply sits on
        // top of an already-present menu-bar icon (the wizard's "Find Latte
        // in the menu bar" copy now matches what the user sees).
        MenuBarExtra(
            "Latte",
            systemImage: environment.menuBarIconStyle.symbolName(awake: manager.isAwake)
        ) {
            MenuBarRoot(manager: environment.manager)
                .environmentObject(environment)
        }
        .menuBarExtraStyle(.window)
    }
}
