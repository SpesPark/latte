import SwiftUI

@main
struct LatteApp: App {

    @StateObject private var environment = AppEnvironment()

    init() {
        AwakeManager.installSignalHandlers()
    }

    var body: some Scene {
        MenuBarExtra("Latte", systemImage: "cup.and.saucer.fill") {
            MenuBarRoot(manager: environment.manager)
                .environmentObject(environment)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRoot(manager: environment.manager, coordinator: environment.coordinator)
                .environmentObject(environment)
        }
    }
}
