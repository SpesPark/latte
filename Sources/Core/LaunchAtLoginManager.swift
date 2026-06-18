import Foundation
import os
#if canImport(ServiceManagement)
import ServiceManagement
#endif

/// Wrapper around `SMAppService.mainApp` that registers the app as a
/// login item. Persists the user's choice to `SettingsKey.launchAtLogin`
/// so the toggle UI can reflect it without consulting the system service
/// on every render.
///
/// Why a protocol + concrete pair: the system `SMAppService` is final
/// and cannot be subclassed; tests inject `InMemoryLaunchAtLoginService`
/// to verify the SettingsStore wiring without touching the real launch
/// item registry.
public protocol LaunchAtLoginService: AnyObject {
    /// Whether the app is currently registered as a login item.
    /// Reads the live system status (not the cached settings flag).
    var isEnabled: Bool { get }
    /// Register or unregister. Returns `true` on success, `false` if the
    /// system rejects the call (e.g. user denied in System Settings).
    func setEnabled(_ enabled: Bool) -> Bool
}

#if canImport(ServiceManagement)
/// Production-grade `LaunchAtLoginService` backed by `SMAppService.mainApp`.
public final class SMAppServiceLaunchAtLogin: LaunchAtLoginService {

    private let service: SMAppService
    private let logger = Logger(subsystem: "com.araforge.latte", category: "launchAtLogin")

    public init(service: SMAppService = .mainApp) {
        self.service = service
    }

    public var isEnabled: Bool {
        switch service.status {
        case .enabled: return true
        case .notRegistered, .notFound, .requiresApproval: return false
        @unknown default: return false
        }
    }

    public func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            return true
        } catch {
            logger.error("setEnabled(\(enabled)) failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
#endif

/// Test-only stub. Mirrors the protocol contract without touching the
/// system service registry.
public final class InMemoryLaunchAtLoginService: LaunchAtLoginService {

    private var enabled: Bool

    public init(initiallyEnabled: Bool = false) {
        self.enabled = initiallyEnabled
    }

    public var isEnabled: Bool { enabled }

    public func setEnabled(_ enabled: Bool) -> Bool {
        self.enabled = enabled
        return true
    }
}

/// Coordinator that bridges the `LaunchAtLoginService` and the
/// `SettingsStore`. Exposes a published boolean for SwiftUI binding.
@MainActor
public final class LaunchAtLoginCoordinator: ObservableObject {

    /// Observable mirror. Setting this triggers `service.setEnabled` and
    /// persists the desired state to `SettingsKey.launchAtLogin`. If the
    /// service rejects the change, the published value reverts to the
    /// previous state and the persisted flag is left untouched.
    @Published public var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            let succeeded = service.setEnabled(isEnabled)
            if succeeded {
                settings.setBool(isEnabled, for: .launchAtLogin)
            } else {
                // Roll back without re-firing didSet by mutating the
                // underlying _isEnabled directly is not possible with
                // @Published, so we use a guarded re-assignment.
                let target = oldValue
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if self.isEnabled != target { self.isEnabled = target }
                }
            }
        }
    }

    private let service: LaunchAtLoginService
    private let settings: SettingsStore

    public init(
        service: LaunchAtLoginService,
        settings: SettingsStore
    ) {
        self.service = service
        self.settings = settings
        // Reconcile: prefer the live system status over the cached flag.
        // If the user disabled the login item via System Settings while
        // the app wasn't running, the cache would be stale.
        let live = service.isEnabled
        let cached = settings.bool(.launchAtLogin, default: false)
        if live != cached {
            settings.setBool(live, for: .launchAtLogin)
        }
        self.isEnabled = live
    }
}
