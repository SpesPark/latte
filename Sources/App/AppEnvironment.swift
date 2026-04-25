import Foundation

@MainActor
public final class AppEnvironment: ObservableObject {

    public let settings: SettingsStore
    public let manager: AwakeManager
    public let coordinator: TriggerCoordinator

    public init(settings: SettingsStore = UserDefaultsSettingsStore()) {
        self.settings = settings
        // Use AwakeManager.shared so AppIntents (out-of-process) and the in-process app
        // operate on the same FSM. Re-creating would split state.
        self.manager = AwakeManager.shared
        self.coordinator = TriggerCoordinator(awakeManager: AwakeManager.shared, settings: settings)
        registerDefaultTriggers()
    }

    private func registerDefaultTriggers() {
        coordinator.register(CalendarTrigger(settings: settings))
        coordinator.register(AppTrigger(settings: settings))
        coordinator.register(WiFiTrigger(settings: settings))
        coordinator.register(FocusTrigger(settings: settings))
    }
}
