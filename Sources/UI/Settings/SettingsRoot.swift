import SwiftUI

public struct SettingsRoot: View {

    @ObservedObject public var manager: AwakeManager
    @ObservedObject public var coordinator: TriggerCoordinator
    public let activityStore: ActivityLogStore?
    @State private var selection: SettingsTab

    public init(
        manager: AwakeManager,
        coordinator: TriggerCoordinator,
        activityStore: ActivityLogStore? = nil,
        initialTab: SettingsTab = .general
    ) {
        self.manager = manager
        self.coordinator = coordinator
        self.activityStore = activityStore
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

            ActivityTab(coordinator: coordinator, store: activityStore)
                .tabItem { Label("Activity", systemImage: "chart.bar.xaxis") }
                .tag(SettingsTab.activity)

            AboutTab(manager: manager, coordinator: coordinator)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 460, minHeight: 360)
    }
}
