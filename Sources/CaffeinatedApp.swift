import SwiftUI

@main
struct CaffeinatedApp: App {
    @StateObject private var awake = AwakeManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(awake)
        } label: {
            Label("Caffeinated", systemImage: awake.isAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(awake)
        }
    }
}
