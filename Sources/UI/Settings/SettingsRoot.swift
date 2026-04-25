import SwiftUI

public struct SettingsRoot: View {

    @ObservedObject public var manager: AwakeManager
    @ObservedObject public var coordinator: TriggerCoordinator

    public init(manager: AwakeManager, coordinator: TriggerCoordinator) {
        self.manager = manager
        self.coordinator = coordinator
    }

    public var body: some View {
        TabView {
            GeneralTab(manager: manager)
                .tabItem { Label("General", systemImage: "gear") }

            TriggersTab(coordinator: coordinator)
                .tabItem { Label("Triggers", systemImage: "bolt") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 360)
    }
}
