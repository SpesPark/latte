import SwiftUI

@main
struct LatteApp: App {

    @StateObject private var environment = AppEnvironment()
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
            systemImage: environment.menuBarIconStyle.symbolName(awake: manager.isAwake)
        ) {
            MenuBarRoot(manager: environment.manager)
                .environmentObject(environment)
                .task {
                    await environment.bootTriggers()
                    presentOnboardingIfNeeded()
                }
        }
        .menuBarExtraStyle(.window)
    }

    /// Show the first-run onboarding window the first time the menu bar
    /// becomes interactive. Idempotent — subsequent launches read the
    /// persisted flag and no-op.
    @MainActor
    private func presentOnboardingIfNeeded() {
        guard !environment.onboarding.hasCompletedOnboarding else { return }
        OnboardingWindowController.shared.show(
            state: environment.onboarding,
            coordinator: environment.coordinator,
            environment: environment
        )
    }
}
