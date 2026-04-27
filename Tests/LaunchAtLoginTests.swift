import XCTest
@testable import Latte

@MainActor
final class LaunchAtLoginTests: XCTestCase {

    // MARK: - InMemoryLaunchAtLoginService contract

    func testInMemoryServiceStartsDisabledByDefault() {
        let service = InMemoryLaunchAtLoginService()
        XCTAssertFalse(service.isEnabled)
    }

    func testInMemoryServiceCanStartEnabled() {
        let service = InMemoryLaunchAtLoginService(initiallyEnabled: true)
        XCTAssertTrue(service.isEnabled)
    }

    func testInMemoryServiceSetEnabledReturnsTrueAndUpdates() {
        let service = InMemoryLaunchAtLoginService()
        XCTAssertTrue(service.setEnabled(true))
        XCTAssertTrue(service.isEnabled)
        XCTAssertTrue(service.setEnabled(false))
        XCTAssertFalse(service.isEnabled)
    }

    // MARK: - LaunchAtLoginCoordinator binding

    func testCoordinatorMirrorsLiveServiceStateOnInit() {
        let service = InMemoryLaunchAtLoginService(initiallyEnabled: true)
        let settings = InMemorySettingsStore()
        let coord = LaunchAtLoginCoordinator(service: service, settings: settings)
        XCTAssertTrue(coord.isEnabled)
        // Settings cache reconciled to live state.
        XCTAssertTrue(settings.bool(.launchAtLogin, default: false))
    }

    func testCoordinatorReconcilesStaleSettingsCacheToLiveStatus() {
        // User disabled the login item via System Settings while the
        // app wasn't running. On next launch the cached flag should
        // get rewritten to match the live status.
        let service = InMemoryLaunchAtLoginService(initiallyEnabled: false)
        let settings = InMemorySettingsStore()
        settings.setBool(true, for: .launchAtLogin)
        let coord = LaunchAtLoginCoordinator(service: service, settings: settings)
        XCTAssertFalse(coord.isEnabled)
        XCTAssertFalse(settings.bool(.launchAtLogin, default: true),
                       "Stale settings cache must be reconciled to live service status")
    }

    func testCoordinatorPersistsToggleToSettings() {
        let service = InMemoryLaunchAtLoginService()
        let settings = InMemorySettingsStore()
        let coord = LaunchAtLoginCoordinator(service: service, settings: settings)
        coord.isEnabled = true
        XCTAssertTrue(service.isEnabled)
        XCTAssertTrue(settings.bool(.launchAtLogin, default: false))
        coord.isEnabled = false
        XCTAssertFalse(service.isEnabled)
        XCTAssertFalse(settings.bool(.launchAtLogin, default: true))
    }

    // MARK: - Failure path: rejecting service

    private final class RejectingLaunchAtLoginService: LaunchAtLoginService {
        var isEnabled: Bool = false
        func setEnabled(_ enabled: Bool) -> Bool { false }
    }

    func testCoordinatorDoesNotPersistWhenServiceRejects() {
        let service = RejectingLaunchAtLoginService()
        let settings = InMemorySettingsStore()
        let coord = LaunchAtLoginCoordinator(service: service, settings: settings)
        XCTAssertFalse(coord.isEnabled)
        coord.isEnabled = true
        // didSet attempts setEnabled, sees false, schedules a rollback.
        // We don't await the rollback here (it's a Task) but the
        // important contract is: settings is NOT persisted on failure.
        XCTAssertFalse(settings.bool(.launchAtLogin, default: false),
                       "Settings must not be persisted when the service rejects the change")
    }
}
