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

    /// User-selected coffee accent tone. Mirrors `SettingsKey.coffeeAccent`.
    /// Drives the menu-bar accent bar, checkmark, cup liquid, and Settings
    /// status dot — change is reflected instantly in every dependent view.
    @Published public var coffeeAccent: CoffeeAccent {
        didSet {
            guard coffeeAccent != oldValue else { return }
            settings.setString(coffeeAccent.rawValue, for: .coffeeAccent)
        }
    }

    public init(settings: SettingsStore = UserDefaultsSettingsStore()) {
        self.settings = settings
        // Use AwakeManager.shared so AppIntents (out-of-process) and the in-process app
        // operate on the same FSM. Re-creating would split state.
        self.manager = AwakeManager.shared
        self.coordinator = TriggerCoordinator(awakeManager: AwakeManager.shared, settings: settings)
        self.menuBarIconStyle = MenuBarIconStyle.decode(settings.string(.menuBarIconStyle))
        self.coffeeAccent = CoffeeAccent.decode(settings.string(.coffeeAccent))
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
