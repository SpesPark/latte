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
    public let keyboardShortcut: KeyboardShortcutCoordinator
    /// Activity history store (C-3). Nil when the application support
    /// directory cannot be created (sandbox denial / disk full at boot) —
    /// the app keeps running, the Activity tab shows an empty state.
    public let activityStore: ActivityLogStore?

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

    /// "Activate at launch" — when enabled, Latte holds an indefinite awake
    /// assertion on every app start (after onboarding completes). Mirrors
    /// `SettingsKey.activateOnLaunch`. The toggle only affects subsequent
    /// launches; it does NOT auto-activate the current already-running
    /// session when the user flips it on. See `applyActivateOnLaunchIfEnabled()`.
    @Published public var activateOnLaunch: Bool {
        didSet {
            guard activateOnLaunch != oldValue else { return }
            settings.setBool(activateOnLaunch, for: .activateOnLaunch)
        }
    }

    /// Days of activity history retained on disk. Default 14, valid range
    /// `ActivityLogStore.retentionDayRange` (1…90). Mirrors
    /// `SettingsKey.activityRetentionDays`. Writing here also propagates the
    /// new window into the live actor (`setRetention`) so a shrink GCs
    /// stale entries on the spot — no app restart needed.
    @Published public var activityRetentionDays: Int {
        didSet {
            guard activityRetentionDays != oldValue else { return }
            settings.setInteger(activityRetentionDays, for: .activityRetentionDays)
            if let store = activityStore {
                let seconds = TimeInterval(activityRetentionDays) * ActivityLogStore.secondsPerDay
                Task { await store.setRetention(seconds) }
            }
        }
    }

    /// Per-trigger Activity chart colour overrides. `[:]` = all defaults
    /// from `ActivityChartPalette.defaultHex`. Missing keys per-trigger
    /// fall through to the default. Mirrors `SettingsKey.activityChartColors`.
    @Published public var activityChartColors: [String: String] {
        didSet {
            guard activityChartColors != oldValue else { return }
            settings.setData(
                ActivityChartPalette.encode(overrides: activityChartColors),
                for: .activityChartColors
            )
        }
    }

    /// User-defined recurring quick presets (C-7 v1.7). Mirrors
    /// `SettingsKey.recurringQuickPresets`. Empty list = no user presets
    /// render in the popover. Editing here writes the full list back
    /// (no partial CRUD; the list is small).
    @Published public var recurringQuickPresets: [RecurringQuickPreset] {
        didSet {
            guard recurringQuickPresets != oldValue else { return }
            RecurringQuickPreset.write(recurringQuickPresets, to: settings)
        }
    }

    public init(
        settings: SettingsStore = UserDefaultsSettingsStore(),
        launchAtLoginService: LaunchAtLoginService? = nil,
        hotKeyRegistrar: HotKeyRegistrar? = nil
    ) {
        self.settings = settings
        // Use AwakeManager.shared so AppIntents (out-of-process) and the in-process app
        // operate on the same FSM. Re-creating would split state.
        self.manager = AwakeManager.shared
        let retentionDays = settings.clampedInteger(
            .activityRetentionDays,
            default: 14,
            range: ActivityLogStore.retentionDayRange
        )
        let retentionSeconds = TimeInterval(retentionDays) * ActivityLogStore.secondsPerDay
        let store: ActivityLogStore? = ActivityLogStore.defaultDirectory().map { dir in
            ActivityLogStore(directory: dir, retention: retentionSeconds)
        }
        self.activityStore = store
        self.coordinator = TriggerCoordinator(
            awakeManager: AwakeManager.shared,
            settings: settings,
            activityStore: store
        )
        self.menuBarIconStyle = MenuBarIconStyle.decode(settings.string(.menuBarIconStyle))
        self.coffeeAccent = CoffeeAccent.decode(settings.string(.coffeeAccent))
        self.activateOnLaunch = settings.bool(.activateOnLaunch, default: false)
        self.activityRetentionDays = retentionDays
        self.activityChartColors = ActivityChartPalette.decode(
            overrides: settings.data(.activityChartColors)
        )
        self.recurringQuickPresets = RecurringQuickPreset.read(from: settings)
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
        let resolvedRegistrar: HotKeyRegistrar = hotKeyRegistrar ?? CarbonHotKeyRegistrar()
        // Capture AwakeManager.shared by reference so the closure does not
        // retain `self` (which would be unavailable inside this initializer).
        let managerRef = AwakeManager.shared
        self.keyboardShortcut = KeyboardShortcutCoordinator(
            settings: settings,
            registrar: resolvedRegistrar,
            onToggleAwake: { managerRef.toggle() }
        )
        registerDefaultTriggers()
    }

    private func registerDefaultTriggers() {
        coordinator.register(CalendarTrigger(settings: settings))
        coordinator.register(AppTrigger(settings: settings))
        coordinator.register(WiFiTrigger(settings: settings))
        coordinator.register(ScheduleTrigger(settings: settings))
        coordinator.register(ExternalDisplayTrigger(settings: settings))
        // FocusTrigger is intentionally **not registered for v1.0**.
        // S8b smoke confirmed `INFocusStatusCenter.focusStatus.isFocused`
        // returns false even when a Focus mode is active — sandboxed
        // macOS apps need the `com.apple.developer.usernotifications.communication`
        // entitlement (and Apple Developer Program membership) to read
        // Focus state reliably. Re-register once the Dev Program is
        // active and the entitlement is provisioned. Tracked as
        // V2-03b in `docs/v2-backlog.md`.
        // coordinator.register(FocusTrigger(settings: settings))
    }

    /// If the user has "Activate at launch" enabled, hold an indefinite
    /// awake assertion under `AwakeReason.launch`. Idempotent: a second
    /// call (e.g. duplicate launch hand-off) is a no-op while the manager
    /// is already awake. Intended call site is once per cold start, after
    /// onboarding completes (skipped during first-run wizard so a fresh
    /// install doesn't hold the system awake before the user even consents).
    public func applyActivateOnLaunchIfEnabled() {
        guard activateOnLaunch else { return }
        guard onboarding.hasCompletedOnboarding else { return }
        guard !manager.isAwake else { return }
        manager.activate(for: .indefinite, reason: .launch)
        if !manager.isAwake {
            // requireACForAwake + battery, or another input-boundary
            // constraint, blocked the activate. Surface it so the user
            // (or a future bug-report reader) can see the launch toggle
            // ran but produced no assertion.
            LatteLog.awake.info("activate-at-launch: no-op - manager not awake after activate (blocked by input-boundary gate)")
        }
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
