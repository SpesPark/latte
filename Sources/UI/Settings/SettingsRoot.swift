import SwiftUI

public struct SettingsRoot: View {

    @ObservedObject public var manager: AwakeManager
    @ObservedObject public var coordinator: TriggerCoordinator
    public let activityStore: ActivityLogStore?
    @State private var selection: SettingsTab
    /// Set by ActivityTab via the row-tap callback (D). TriggersTab observes
    /// this and scrolls to the matching `TriggerSection` on appear / change.
    @State private var focusedTriggerId: String?

    public init(
        manager: AwakeManager,
        coordinator: TriggerCoordinator,
        activityStore: ActivityLogStore? = nil,
        initialTab: SettingsTab = .general,
        initialFocusedTriggerId: String? = nil
    ) {
        self.manager = manager
        self.coordinator = coordinator
        self.activityStore = activityStore
        _selection = State(initialValue: initialTab)
        _focusedTriggerId = State(initialValue: initialFocusedTriggerId)
    }

    public var body: some View {
        TabView(selection: $selection) {
            GeneralTab(manager: manager)
                .tabItem { Label("General", systemImage: "gear") }
                .tag(SettingsTab.general)

            TriggersTab(coordinator: coordinator, focusedTriggerId: $focusedTriggerId)
                .tabItem { Label("Triggers", systemImage: "bolt") }
                .tag(SettingsTab.triggers)

            ActivityTab(
                coordinator: coordinator,
                store: activityStore,
                onJumpToTrigger: { id in
                    focusedTriggerId = id
                    selection = .triggers
                }
            )
                .tabItem { Label("Activity", systemImage: "chart.bar.xaxis") }
                .tag(SettingsTab.activity)

            AboutTab(manager: manager, coordinator: coordinator)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 460, minHeight: 360)
        .onReceive(NotificationCenter.default.publisher(for: .settingsRequestFocusTrigger)) { note in
            guard let id = note.object as? String else { return }
            focusedTriggerId = id
            selection = .triggers
        }
    }
}

extension Notification.Name {
    /// Posted by SettingsWindowController on a re-show with focus= URL —
    /// SettingsRoot listens and routes to TriggersTab. Used so a second
    /// `latte://settings/triggers?focus=wifi` re-scrolls when the window
    /// is already open.
    public static let settingsRequestFocusTrigger = Notification.Name("LatteSettingsRequestFocusTrigger")
}
