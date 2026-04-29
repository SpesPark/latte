import XCTest
@testable import Latte

@MainActor
final class KeyboardShortcutCoordinatorTests: XCTestCase {

    // MARK: - Mock registrar

    /// Captures register/unregister calls and exposes a way to fire the
    /// handler manually so tests can verify the shortcut → toggle path
    /// without involving Carbon or System Events.
    final class MockHotKeyRegistrar: HotKeyRegistrar {
        private(set) var isRegistered: Bool = false
        private(set) var registerCallCount: Int = 0
        private(set) var unregisterCallCount: Int = 0
        private var handler: (@MainActor () -> Void)?

        func register(handler: @escaping @MainActor () -> Void) {
            // Mirror the production contract: re-registering without an
            // intervening unregister is a no-op (handler preserved).
            registerCallCount += 1
            if isRegistered { return }
            isRegistered = true
            self.handler = handler
        }

        func unregister() {
            unregisterCallCount += 1
            isRegistered = false
            handler = nil
        }

        /// Pretend the chord was pressed — fires the registered handler
        /// (if any), allowing tests to assert on the toggle side-effect.
        func fire() {
            handler?()
        }
    }

    // MARK: - Initial state

    func testStartsDormantWhenSettingDefaultIsFalse() {
        let store = InMemorySettingsStore()
        let registrar = MockHotKeyRegistrar()
        let coord = KeyboardShortcutCoordinator(
            settings: store,
            registrar: registrar,
            onToggleAwake: {}
        )
        XCTAssertFalse(coord.isEnabled)
        XCTAssertFalse(registrar.isRegistered,
                       "Default-off must not touch the OS hotkey API")
    }

    func testHydratesEnabledFromStoreAndRegistersImmediately() {
        let store = InMemorySettingsStore(initial: [.keyboardShortcutEnabled: true])
        let registrar = MockHotKeyRegistrar()
        _ = KeyboardShortcutCoordinator(
            settings: store,
            registrar: registrar,
            onToggleAwake: {}
        )
        XCTAssertTrue(registrar.isRegistered,
                      "Stored isEnabled=true must register the chord on init")
    }

    // MARK: - Toggle wiring

    func testEnablingRegistersAndDisablingUnregisters() {
        let store = InMemorySettingsStore()
        let registrar = MockHotKeyRegistrar()
        let coord = KeyboardShortcutCoordinator(
            settings: store,
            registrar: registrar,
            onToggleAwake: {}
        )

        coord.isEnabled = true
        XCTAssertTrue(registrar.isRegistered)
        XCTAssertEqual(registrar.registerCallCount, 1)

        coord.isEnabled = false
        XCTAssertFalse(registrar.isRegistered)
        XCTAssertEqual(registrar.unregisterCallCount, 1)
    }

    func testEnableThenSameValueDoesNotReRegister() {
        // didSet short-circuits on equality — same as menuBarIconStyle /
        // coffeeAccent. Avoids OS-API churn on redundant SwiftUI reloads.
        let store = InMemorySettingsStore()
        let registrar = MockHotKeyRegistrar()
        let coord = KeyboardShortcutCoordinator(
            settings: store,
            registrar: registrar,
            onToggleAwake: {}
        )
        coord.isEnabled = true
        XCTAssertEqual(registrar.registerCallCount, 1)
        coord.isEnabled = true   // same value
        XCTAssertEqual(registrar.registerCallCount, 1,
                       "Re-assigning the same value must not call register again")
    }

    // MARK: - Settings round-trip

    func testEnablingPersistsToStore() {
        let store = InMemorySettingsStore()
        let registrar = MockHotKeyRegistrar()
        let coord = KeyboardShortcutCoordinator(
            settings: store,
            registrar: registrar,
            onToggleAwake: {}
        )
        coord.isEnabled = true
        XCTAssertTrue(store.bool(.keyboardShortcutEnabled, default: false))

        coord.isEnabled = false
        XCTAssertFalse(store.bool(.keyboardShortcutEnabled, default: true))
    }

    // MARK: - Handler delivery

    func testFiringTheChordCallsTheToggleClosureExactlyOnce() {
        let store = InMemorySettingsStore()
        let registrar = MockHotKeyRegistrar()
        var calls = 0
        let coord = KeyboardShortcutCoordinator(
            settings: store,
            registrar: registrar,
            onToggleAwake: { calls += 1 }
        )
        coord.isEnabled = true
        registrar.fire()
        XCTAssertEqual(calls, 1)
    }

    func testFiringWhileDisabledDoesNotCallTheClosure() {
        let store = InMemorySettingsStore()
        let registrar = MockHotKeyRegistrar()
        var calls = 0
        _ = KeyboardShortcutCoordinator(
            settings: store,
            registrar: registrar,
            onToggleAwake: { calls += 1 }
        )
        // Without enabling, registrar.handler is nil — fire() is a no-op.
        registrar.fire()
        XCTAssertEqual(calls, 0)
    }

    // MARK: - SettingsStore key plumbing

    func testRequiredKeyExists() {
        // Catches typos in the rawValue and keeps the migration matrix
        // honest (mirrors SettingsStoreTests testRequiredKeysExist style).
        XCTAssertEqual(SettingsKey.keyboardShortcutEnabled.rawValue,
                       "latte.keyboardShortcut.enabled")
    }
}
