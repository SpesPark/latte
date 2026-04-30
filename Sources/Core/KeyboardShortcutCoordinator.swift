import AppKit
import Carbon.HIToolbox
import Combine
import Foundation
import os

/// Owns the global keyboard shortcut (default ⌘⇧L) that toggles Latte's awake
/// state. Backed by Carbon's `RegisterEventHotKey` since it works in adhoc-
/// signed and sandboxed apps without an entitlement and supports system-wide
/// chord capture (NSEvent.addGlobalMonitorForEvents is read-only).
///
/// The chord is hardcoded to ⌘⇧L for v1.1; a custom-shortcut recorder is
/// tracked for v1.2. Persisted enable/disable is mirrored on
/// `SettingsKey.keyboardShortcutEnabled`.
///
/// Lifecycle:
///   * `init` reads the persisted flag; if true, immediately registers the
///     hotkey. If false, stays dormant.
///   * Toggling `isEnabled` writes the flag and registers / unregisters
///     accordingly. Idempotent — registering twice is a no-op, unregistering
///     when not registered is a no-op.
///   * `deinit` unregisters defensively (production AppEnvironment is a
///     singleton so this rarely fires; tests destroy & recreate freely).
@MainActor
public final class KeyboardShortcutCoordinator: ObservableObject {

    /// User-visible glyph for the **default** chord. Kept for callers that
    /// want a stable label without observing the live `chord` (legacy API).
    /// New code should read `chord.glyph` instead.
    public static let chordGlyph: String = KeyChord.default.glyph

    private let settings: SettingsStore
    private let onToggleAwake: @MainActor () -> Void
    private let registrar: HotKeyRegistrar

    /// Mirrors `SettingsKey.keyboardShortcutEnabled`. Setter writes through
    /// to the store *and* registers/unregisters the hotkey.
    @Published public var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            settings.setBool(isEnabled, for: .keyboardShortcutEnabled)
            applyEnabledState()
        }
    }

    /// Currently configured chord. Hydrated from `SettingsKey.shortcutChord`
    /// at init; falls back to `KeyChord.default` (⌘⇧L) when absent or
    /// corrupt — see spec §8 Q4 silent-default migration.
    @Published public private(set) var chord: KeyChord

    /// Surface for register-time failures from `setChord`. Populated when the
    /// OS rejects the new chord (typically `kEventHotKeyExistsErr` — held by
    /// another app or system shortcut); cleared on the next successful
    /// setChord. The Settings recorder UI consumes this to show inline copy.
    @Published public private(set) var registrationError: ChordRegistrationError?

    public init(
        settings: SettingsStore,
        registrar: HotKeyRegistrar = CarbonHotKeyRegistrar(),
        onToggleAwake: @escaping @MainActor () -> Void
    ) {
        self.settings = settings
        self.registrar = registrar
        self.onToggleAwake = onToggleAwake
        let initial = settings.bool(.keyboardShortcutEnabled, default: false)
        self.isEnabled = initial
        self.chord = settings.keyChord(.shortcutChord) ?? .default
        if initial {
            applyEnabledState()
        }
    }

    /// Persist + re-register a new chord. Idempotent if `newChord == chord`.
    /// User-explicit action — assumes the recorder UI already validated
    /// (modifier present, not in `ReservedChord.blocklist`).
    ///
    /// When `isEnabled` is true, the new chord is probed at the OS layer
    /// (`RegisterEventHotKey`). If the OS rejects it (e.g. another app
    /// holds the binding), the live + persisted chord roll back to the
    /// previous value, the prior registration is restored so the user's
    /// existing shortcut keeps working, and `registrationError` is
    /// populated for the recorder UI to surface inline.
    public func setChord(_ newChord: KeyChord) {
        guard newChord != chord else { return }
        let previousChord = chord
        chord = newChord
        settings.setKeyChord(newChord, for: .shortcutChord)
        if isEnabled {
            registrar.unregister()
            applyEnabledState()
            if !registrar.isRegistered {
                // OS rejected the chord. Roll back to the previous binding
                // and re-register it so the user keeps a working shortcut.
                chord = previousChord
                settings.setKeyChord(previousChord, for: .shortcutChord)
                registrationError = .alreadyInUse(newChord)
                applyEnabledState()
                if !registrar.isRegistered {
                    // Narrow race: the previous chord was also grabbed by
                    // another process between unregister and re-register.
                    // The user's shortcut is now dead until they pick a new
                    // working chord — log so the failure is observable.
                    LatteLog.shortcut.error(
                        "rollback re-register failed — shortcut inactive until next setChord"
                    )
                }
                return
            }
        }
        registrationError = nil
    }

    /// Reset to the default chord (⌘⇧L). Idempotent if already default.
    public func resetChord() {
        setChord(.default)
    }

    /// Drop any surfaced register-failure error. The recorder UI calls this
    /// when the user cancels (Esc / click-outside) so the inline red copy
    /// from a previous failed attempt doesn't linger across attempts.
    public func clearRegistrationError() {
        registrationError = nil
    }

    // No deinit-time unregister: deinit is nonisolated and the registrar is
    // @MainActor, so a synchronous call would be a data-race. In production
    // the coordinator is a long-lived singleton (lifetime = process) — Carbon
    // releases the hotkey on process exit. Tests destroy & recreate freely;
    // the mock registrar drops its handler when the new owner calls
    // register() again, and explicit `unregister()` in test teardown is
    // available if needed.

    private func applyEnabledState() {
        if isEnabled {
            registrar.register(
                chord: chord,
                handler: { [weak self] in self?.onToggleAwake() }
            )
        } else {
            registrar.unregister()
        }
    }
}

// MARK: - ChordRegistrationError

/// Surfaced from `KeyboardShortcutCoordinator.registrationError` after a
/// failed `setChord`. The `KeyChord` payload is the chord that was rejected.
public enum ChordRegistrationError: Equatable, Sendable {
    /// `RegisterEventHotKey` returned a non-`noErr` status — typically
    /// `kEventHotKeyExistsErr` (-9878), meaning another app or a macOS
    /// system shortcut already owns this chord globally.
    case alreadyInUse(KeyChord)
}

// MARK: - HotKeyRegistrar protocol (DI for tests)

/// Indirection for the OS-level hotkey API so tests can substitute a mock.
///
/// v1.2 (B1.2) introduced the `chord:` overload. The legacy `register(handler:)`
/// is kept as a default-impl shim that delegates to the new method with the
/// default chord — existing callers that haven't migrated still compile and
/// behave identically.
@MainActor
public protocol HotKeyRegistrar: AnyObject {
    /// Register a specific chord. Calling twice without an intervening
    /// unregister is a no-op (existing handler is preserved).
    func register(chord: KeyChord, handler: @escaping @MainActor () -> Void)

    /// Legacy entry-point — registers the default chord (⌘⇧L). New callers
    /// should use `register(chord:handler:)`.
    func register(handler: @escaping @MainActor () -> Void)

    /// Unregister the chord. No-op if not currently registered.
    func unregister()

    /// True between a successful `register` and the matching `unregister`.
    var isRegistered: Bool { get }

    /// The chord the registrar currently has installed at the OS level,
    /// or nil when not registered. Settings UI uses this to display the
    /// active chord without round-tripping through the store.
    var currentChord: KeyChord? { get }
}

public extension HotKeyRegistrar {
    /// Default-impl shim for the legacy `register(handler:)` callsite.
    func register(handler: @escaping @MainActor () -> Void) {
        register(chord: .default, handler: handler)
    }
}

// MARK: - Carbon implementation

/// Default `HotKeyRegistrar`. Wraps Carbon `RegisterEventHotKey` for ⌘⇧L.
///
/// **Process-global state** — `activeHandler` and `eventHandlerInstalled` are
/// `static` so the single Carbon EventHandler installed on first `register()`
/// can dispatch to whichever instance currently owns the chord. Consequence:
/// only one `CarbonHotKeyRegistrar` should be live per process. Production
/// instantiates one (`AppEnvironment.keyboardShortcutCoordinator`); tests
/// substitute `MockHotKeyRegistrar`. Direct unit tests of this class would
/// share global state across cases — the static handler latches and is not
/// reset between runs.
@MainActor
public final class CarbonHotKeyRegistrar: HotKeyRegistrar {

    private static let logger = LatteLog.shortcut
    private static let signature: OSType = 0x4C617474  // 'Latt'
    private static let hotKeyID: UInt32 = 1

    /// Box that owns the closure across the C callback boundary. The callback
    /// reads `Self.activeHandler` directly because installing an EventHandler
    /// per registration would leak handlers on rapid toggle. One handler is
    /// installed lazily on first register().
    private static var activeHandler: (@MainActor () -> Void)?
    private static var eventHandlerInstalled = false

    private var hotKeyRef: EventHotKeyRef?
    public private(set) var currentChord: KeyChord?

    public init() {}

    public var isRegistered: Bool { hotKeyRef != nil }

    public func register(chord: KeyChord, handler: @escaping @MainActor () -> Void) {
        if hotKeyRef != nil {
            // Existing registration — keep the prior handler. Idempotent.
            return
        }
        Self.installEventHandlerIfNeeded()
        Self.activeHandler = handler

        let id = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            chord.keyCode,
            chord.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            hotKeyRef = ref
            currentChord = chord
            Self.logger.info("global hotkey \(chord.glyph, privacy: .public) registered")
        } else {
            Self.logger.error("RegisterEventHotKey failed status=\(status)")
            Self.activeHandler = nil
        }
    }

    public func unregister() {
        guard let ref = hotKeyRef else { return }
        let status = UnregisterEventHotKey(ref)
        hotKeyRef = nil
        let glyph = currentChord?.glyph ?? "?"
        currentChord = nil
        Self.activeHandler = nil
        if status != noErr {
            Self.logger.error("UnregisterEventHotKey failed status=\(status)")
        } else {
            Self.logger.info("global hotkey \(glyph, privacy: .public) unregistered")
        }
    }

    private static func installEventHandlerIfNeeded() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var receivedID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &receivedID
            )
            guard status == noErr,
                  receivedID.signature == CarbonHotKeyRegistrar.signature,
                  receivedID.id == CarbonHotKeyRegistrar.hotKeyID
            else {
                return OSStatus(eventNotHandledErr)
            }
            // Bounce onto the main actor to call the handler safely.
            Task { @MainActor in
                CarbonHotKeyRegistrar.activeHandler?()
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
