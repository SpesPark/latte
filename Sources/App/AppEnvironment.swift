import Foundation

@MainActor
public final class AppEnvironment: ObservableObject {

    public let settings: SettingsStore
    public let manager: AwakeManager
    public let coordinator: TriggerCoordinator

    /// User-selected menu bar icon variant. Mirrors `SettingsKey.menuBarIconStyle`
    /// — writing here persists to the underlying `SettingsStore`.
    @Published public var menuBarIconStyle: MenuBarIconStyle {
        didSet {
            guard menuBarIconStyle != oldValue else { return }
            settings.setString(menuBarIconStyle.rawValue, for: .menuBarIconStyle)
        }
    }

    public init(settings: SettingsStore = UserDefaultsSettingsStore()) {
        self.settings = settings
        // Use AwakeManager.shared so AppIntents (out-of-process) and the in-process app
        // operate on the same FSM. Re-creating would split state.
        self.manager = AwakeManager.shared
        self.coordinator = TriggerCoordinator(awakeManager: AwakeManager.shared, settings: settings)
        self.menuBarIconStyle = MenuBarIconStyle.decode(settings.string(.menuBarIconStyle))
        registerDefaultTriggers()
    }

    private func registerDefaultTriggers() {
        coordinator.register(CalendarTrigger(settings: settings))
        coordinator.register(AppTrigger(settings: settings))
        coordinator.register(WiFiTrigger(settings: settings))
        coordinator.register(FocusTrigger(settings: settings))
    }

    /// Boot path: request permission for each enabled trigger that requires it,
    /// then start the trigger's vote stream. Triggers whose permission is denied
    /// stay registered but inactive — user can re-enable via System Settings,
    /// the next launch will pick them up.
    public func bootTriggers() async {
        for trigger in coordinator.triggers where trigger.isEnabled {
            if trigger.requiresPermission {
                let granted = await trigger.requestPermissionIfNeeded()
                if !granted { continue }
            }
            await coordinator.start(trigger)
        }
    }
}
