import Foundation

@MainActor
public final class AppEnvironment: ObservableObject {

    /// Process-wide singleton so `LatteAppDelegate` (instantiated by AppKit,
    /// outside the SwiftUI @StateObject lifecycle) can reach the same
    /// instance the SwiftUI scene observes. Tests construct their own
    /// instances via the public init below.
    public static let shared = AppEnvironment()

    public let settings: SettingsStore
    public let manager: AwakeManager
    public let coordinator: TriggerCoordinator
    public let launchAtLogin: LaunchAtLoginCoordinator
    public let onboarding: OnboardingState

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

    public init(
        settings: SettingsStore = UserDefaultsSettingsStore(),
        launchAtLoginService: LaunchAtLoginService? = nil
    ) {
        self.settings = settings
        // Use AwakeManager.shared so AppIntents (out-of-process) and the in-process app
        // operate on the same FSM. Re-creating would split state.
        self.manager = AwakeManager.shared
        self.coordinator = TriggerCoordinator(awakeManager: AwakeManager.shared, settings: settings)
        self.menuBarIconStyle = MenuBarIconStyle.decode(settings.string(.menuBarIconStyle))
        self.coffeeAccent = CoffeeAccent.decode(settings.string(.coffeeAccent))
        let resolvedLaunchService: LaunchAtLoginService
        if let launchAtLoginService {
            resolvedLaunchService = launchAtLoginService
        } else {
            #if canImport(ServiceManagement)
            resolvedLaunchService = SMAppServiceLaunchAtLogin()
            #else
            resolvedLaunchService = InMemoryLaunchAtLoginService()
            #endif
        }
        self.launchAtLogin = LaunchAtLoginCoordinator(
            service: resolvedLaunchService,
            settings: settings
        )
        self.onboarding = OnboardingState(settings: settings)
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
