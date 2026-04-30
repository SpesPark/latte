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
        private(set) var currentChord: KeyChord?
        private var handler: (@MainActor () -> Void)?
        /// When true, the next `register(chord:handler:)` returns without
        /// flipping `isRegistered` true — used to simulate `RegisterEventHotKey`
        /// failure (e.g. chord already taken globally).
        var failNextRegister: Bool = false

        func register(chord: KeyChord, handler: @escaping @MainActor () -> Void) {
            // Mirror the production contract: re-registering without an
            // intervening unregister is a no-op (handler preserved).
            registerCallCount += 1
            if isRegistered { return }
            if failNextRegister {
                failNextRegister = false
                return
            }
            isRegistered = true
            currentChord = chord
            self.handler = handler
        }

        func unregister() {
            unregisterCallCount += 1
            isRegistered = false
            currentChord = nil
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
        XCTAssertEqual(SettingsKey.shortcutChord.rawValue,
                       "latte.keyboardShortcut.chord")
    }

    // MARK: - B1.2 chord management

    private func makeFixtureForChordTests(
        initialChord: KeyChord? = nil,
        enabled: Bool = false
    ) -> (KeyboardShortcutCoordinator, MockHotKeyRegistrar, InMemorySettingsStore) {
        let store = InMemorySettingsStore()
        if let initialChord {
            store.setKeyChord(initialChord, for: .shortcutChord)
        }
        store.setBool(enabled, for: .keyboardShortcutEnabled)
        let registrar = MockHotKeyRegistrar()
        let coord = KeyboardShortcutCoordinator(
            settings: store,
            registrar: registrar,
            onToggleAwake: {}
        )
        return (coord, registrar, store)
    }

    func testInitFallsBackToDefaultChordWhenStoreIsEmpty() {
        let (coord, _, _) = makeFixtureForChordTests()
        XCTAssertEqual(coord.chord, .default)
        XCTAssertEqual(coord.chord.glyph, "⌘⇧L")
    }

    func testInitHydratesChordFromStoreWhenPresent() {
        let custom = KeyChord(
            modifiers: UInt32(KeyChord.cmdMask | KeyChord.optionMask),
            keyCode: 0x28  // K
        )
        let (coord, _, _) = makeFixtureForChordTests(initialChord: custom)
        XCTAssertEqual(coord.chord, custom)
        XCTAssertEqual(coord.chord.glyph, "⌘⌥K")
    }

    func testSetChordPersistsAndReRegistersWhenEnabled() {
        let (coord, registrar, store) = makeFixtureForChordTests(enabled: true)
        XCTAssertTrue(registrar.isRegistered)
        XCTAssertEqual(registrar.currentChord, .default)
        let initialRegisterCalls = registrar.registerCallCount

        let newChord = KeyChord(
            modifiers: UInt32(KeyChord.cmdMask | KeyChord.optionMask),
            keyCode: 0x28  // K
        )
        coord.setChord(newChord)

        XCTAssertEqual(coord.chord, newChord)
        // The `unregister + applyEnabledState` path → 1 unregister + 1 register.
        XCTAssertEqual(registrar.unregisterCallCount, 1)
        XCTAssertEqual(registrar.registerCallCount, initialRegisterCalls + 1)
        XCTAssertEqual(registrar.currentChord, newChord)

        // Persisted to store.
        let stored = store.keyChord(.shortcutChord)
        XCTAssertEqual(stored, newChord)
    }

    func testSetChordWithSameValueIsNoOp() {
        let (coord, registrar, _) = makeFixtureForChordTests(enabled: true)
        let beforeReg = registrar.registerCallCount
        let beforeUnreg = registrar.unregisterCallCount

        coord.setChord(.default)  // same as current

        XCTAssertEqual(registrar.registerCallCount, beforeReg,
                       "Same-value setChord must not re-register")
        XCTAssertEqual(registrar.unregisterCallCount, beforeUnreg)
    }

    func testResetChordReturnsToDefaultAndReRegisters() {
        let custom = KeyChord(
            modifiers: UInt32(KeyChord.cmdMask | KeyChord.ctrlMask),
            keyCode: 0x06  // Z
        )
        let (coord, registrar, store) = makeFixtureForChordTests(
            initialChord: custom,
            enabled: true
        )
        XCTAssertEqual(coord.chord, custom)
        XCTAssertEqual(registrar.currentChord, custom)

        coord.resetChord()

        XCTAssertEqual(coord.chord, .default)
        XCTAssertEqual(registrar.currentChord, .default)
        XCTAssertEqual(store.keyChord(.shortcutChord), .default)
    }

    func testInitFallsBackToDefaultWhenStoredValueIsGarbage() {
        let store = InMemorySettingsStore()
        // Bogus blob that won't decode as KeyChord JSON.
        store.setData(Data([0xDE, 0xAD, 0xBE, 0xEF]), for: .shortcutChord)
        let registrar = MockHotKeyRegistrar()
        let coord = KeyboardShortcutCoordinator(
            settings: store,
            registrar: registrar,
            onToggleAwake: {}
        )
        XCTAssertEqual(coord.chord, .default,
                       "Corrupt stored chord must fall back to .default silently")
    }

    func testRegistrarFailureLeavesIsRegisteredFalse() {
        let store = InMemorySettingsStore()
        let registrar = MockHotKeyRegistrar()
        registrar.failNextRegister = true
        let coord = KeyboardShortcutCoordinator(
            settings: store,
            registrar: registrar,
            onToggleAwake: {}
        )
        coord.isEnabled = true
        XCTAssertFalse(registrar.isRegistered,
                       "Register failure must not flip the registrar's flag")
        XCTAssertNil(registrar.currentChord)
    }
}

