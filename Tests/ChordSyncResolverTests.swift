import XCTest
@testable import Latte

/// B1.2 chord sync-in resolution — pure, CloudKit-free (docs/design/10 §7/§10).
/// Pre-built dark in S42. The chord *value* rides Domain A's LWW sync; this
/// resolver decides what each device actually registers, honouring the §7
/// rules: a local override wins locally, a failed registration keeps the synced
/// value (never clobbers it) and surfaces the already-shipped disabled-state
/// cue. No live iCloud / Carbon — `MockHotKeyRegistrar` scripts the outcomes.
@MainActor
final class ChordSyncResolverTests: XCTestCase {

    /// Failable registrar mirroring the production contract: re-register without
    /// an intervening unregister is a no-op; `failNextRegister` simulates a
    /// chord reserved by another app on this Mac.
    final class MockHotKeyRegistrar: HotKeyRegistrar {
        private(set) var isRegistered = false
        private(set) var currentChord: KeyChord?
        private(set) var unregisterCallCount = 0
        var failNextRegister = false

        func register(chord: KeyChord, handler: @escaping @MainActor () -> Void) {
            if isRegistered { return }
            if failNextRegister { failNextRegister = false; return }
            isRegistered = true
            currentChord = chord
        }

        func unregister() {
            unregisterCallCount += 1
            isRegistered = false
            currentChord = nil
        }
    }

    private let synced = KeyChord(modifiers: 0x100, keyCode: 0x25)   // ⌘L
    private let localOverride = KeyChord(modifiers: 0x300, keyCode: 0x31) // ⌘⇧Space

    func testRegistersSyncedChordWhenAvailable() {
        let reg = MockHotKeyRegistrar()
        let res = ChordSyncResolver.apply(syncedChord: synced, registrar: reg) {}
        XCTAssertEqual(res.effectiveChord, synced)
        XCTAssertTrue(res.registered)
        XCTAssertFalse(res.showsDisabledCue)
        XCTAssertEqual(reg.currentChord, synced)
    }

    func testFailedRegistrationRetainsSyncedValueAndShowsCue() {
        let reg = MockHotKeyRegistrar()
        reg.failNextRegister = true
        let res = ChordSyncResolver.apply(syncedChord: synced, registrar: reg) {}
        XCTAssertEqual(res.effectiveChord, synced,
                       "Synced value is kept, never dropped/rewritten (§7)")
        XCTAssertFalse(res.registered)
        XCTAssertTrue(res.showsDisabledCue, "Failed register surfaces the disabled-state cue")
    }

    func testDeviceOverrideWinsLocally() {
        let reg = MockHotKeyRegistrar()
        let res = ChordSyncResolver.apply(syncedChord: synced, deviceOverride: localOverride, registrar: reg) {}
        XCTAssertEqual(res.effectiveChord, localOverride, "A local override wins on this device")
        XCTAssertNotEqual(res.effectiveChord, synced)
        XCTAssertTrue(res.registered)
        XCTAssertEqual(reg.currentChord, localOverride)
    }

    func testNilOverrideUsesSyncedChord() {
        let reg = MockHotKeyRegistrar()
        let res = ChordSyncResolver.apply(syncedChord: synced, deviceOverride: nil, registrar: reg) {}
        XCTAssertEqual(res.effectiveChord, synced)
    }

    func testOverrideFailedRegistrationShowsCue() {
        let reg = MockHotKeyRegistrar()
        reg.failNextRegister = true
        let res = ChordSyncResolver.apply(syncedChord: synced, deviceOverride: localOverride, registrar: reg) {}
        XCTAssertEqual(res.effectiveChord, localOverride)
        XCTAssertFalse(res.registered)
        XCTAssertTrue(res.showsDisabledCue)
    }

    func testReplacesPreviouslyRegisteredChord() {
        let reg = MockHotKeyRegistrar()
        _ = ChordSyncResolver.apply(syncedChord: synced, registrar: reg) {}
        let res = ChordSyncResolver.apply(syncedChord: localOverride, registrar: reg) {}
        XCTAssertEqual(res.effectiveChord, localOverride)
        XCTAssertEqual(reg.currentChord, localOverride, "A new synced chord replaces the prior one")
        XCTAssertGreaterThanOrEqual(reg.unregisterCallCount, 1)
    }
}
