import SwiftUI

@main
struct LatteApp: App {

    @StateObject private var environment = AppEnvironment()

    init() {
        AwakeManager.installSignalHandlers()
    }

    var body: some Scene {
        MenuBarExtra("Latte", systemImage: environment.menuBarIconStyle.symbolName) {
            MenuBarRoot(manager: environment.manager)
                .environmentObject(environment)
                .task {
                    await environment.bootTriggers()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
