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
                }
        }
        .menuBarExtraStyle(.window)
    }
}
