import SwiftUI

public struct SettingsRoot: View {

    /// Minimum width of the Settings window. Sized so the longest picker
    /// label in GeneralTab fits on a single line.
    public static let minWindowWidth: CGFloat = 460

    /// Minimum height of the Settings window. Sized so the AboutTab content
    /// (hero card + statusCard + footer) fits without the greedy `Spacer()`
    /// compressing to negative and rendering over the TabView's tab bar.
    /// See `SettingsRootLayoutTests` and S20 / P1 for the regression that
    /// motivated 360 → 420.
    public static let minWindowHeight: CGFloat = 420

    @ObservedObject public var manager: AwakeManager
    @ObservedObject public var coordinator: TriggerCoordinator
    @State private var selection: SettingsTab
    /// Set by ActivityTab via the row-tap callback (D). TriggersTab observes
    /// this and scrolls to the matching `TriggerSection` on appear / change.
    @State private var focusedTriggerId: String?

    public init(
        manager: AwakeManager,
        coordinator: TriggerCoordinator,
        initialTab: SettingsTab = .general,
        initialFocusedTriggerId: String? = nil
    ) {
        self.manager = manager
        self.coordinator = coordinator
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
        .frame(minWidth: Self.minWindowWidth, minHeight: Self.minWindowHeight)
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
