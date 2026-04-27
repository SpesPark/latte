import SwiftUI

public struct SettingsRoot: View {

    @ObservedObject public var manager: AwakeManager
    @ObservedObject public var coordinator: TriggerCoordinator
    @State private var selection: SettingsTab

    public init(manager: AwakeManager, coordinator: TriggerCoordinator, initialTab: SettingsTab = .general) {
        self.manager = manager
        self.coordinator = coordinator
        _selection = State(initialValue: initialTab)
    }

    public var body: some View {
        TabView(selection: $selection) {
            GeneralTab(manager: manager)
                .tabItem { Label("General", systemImage: "gear") }
                .tag(SettingsTab.general)

            TriggersTab(coordinator: coordinator)
                .tabItem { Label("Triggers", systemImage: "bolt") }
                .tag(SettingsTab.triggers)

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 460, height: 360)
    }
}
