import Foundation

/// Resolves an incoming synced B1.2 chord value on the receiving device
/// (docs/design/10 §7). The chord *value* itself rides Domain A's
/// last-writer-wins sync (`SettingsLWWResolver`); this type owns the
/// device-physical half: registration is per-Mac and may fail when the chord is
/// reserved by another app. Pure and CloudKit-free (§10) — pre-built dark in
/// S42; a `MockHotKeyRegistrar` scripts every outcome without Carbon or iCloud.
///
/// §7 rules, made structural here:
/// - **A local override wins locally.** `deviceOverride` is a non-synced,
///   device-only chord; when present it is what this device registers and it
///   never propagates back to the synced value.
/// - **The synced value is never clobbered.** This resolver only *reads* the
///   synced chord and *registers* on the OS; it persists nothing. A failed
///   registration keeps the value and reports `showsDisabledCue` so the UI can
///   surface the already-shipped disabled-state hint (07-spec polish "J",
///   shipped S17) — it does not silently drop or rewrite the value.
@MainActor
public enum ChordSyncResolver {

    public struct Resolution: Equatable, Sendable {
        /// The chord this device should use (override if set, else the synced value).
        public let effectiveChord: KeyChord
        /// Whether the OS accepted the chord on this Mac.
        public let registered: Bool
        /// Surface the disabled-state cue exactly when registration failed.
        public var showsDisabledCue: Bool { !registered }

        public init(effectiveChord: KeyChord, registered: Bool) {
            self.effectiveChord = effectiveChord
            self.registered = registered
        }
    }

    /// Apply a synced (or overridden) chord on this device. Unregisters any
    /// prior chord first so a newly-synced value replaces the old one, then
    /// attempts registration and reports the outcome. Persists nothing.
    public static func apply(
        syncedChord: KeyChord,
        deviceOverride: KeyChord? = nil,
        registrar: HotKeyRegistrar,
        handler: @escaping @MainActor () -> Void
    ) -> Resolution {
        let effective = deviceOverride ?? syncedChord
        registrar.unregister()
        registrar.register(chord: effective, handler: handler)
        let registered = registrar.isRegistered && registrar.currentChord == effective
        return Resolution(effectiveChord: effective, registered: registered)
    }
}
