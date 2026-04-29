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

    /// User-visible glyph for the chord, kept here so UI strings don't
    /// drift from the chord that's actually wired up.
    public static let chordGlyph: String = "⌘⇧L"

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
        if initial {
            applyEnabledState()
        }
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
            registrar.register(handler: { [weak self] in self?.onToggleAwake() })
        } else {
            registrar.unregister()
        }
    }
}

// MARK: - HotKeyRegistrar protocol (DI for tests)

/// Indirection for the OS-level hotkey API so tests can substitute a mock.
@MainActor
public protocol HotKeyRegistrar: AnyObject {
    /// Register the chord. Calling twice without an intervening unregister
    /// is a no-op (existing handler is preserved).
    func register(handler: @escaping @MainActor () -> Void)

    /// Unregister the chord. No-op if not currently registered.
    func unregister()

    /// True between a successful `register` and the matching `unregister`.
    var isRegistered: Bool { get }
}

// MARK: - Carbon implementation

/// Default `HotKeyRegistrar`. Wraps Carbon `RegisterEventHotKey` for ⌘⇧L.
@MainActor
public final class CarbonHotKeyRegistrar: HotKeyRegistrar {

    private static let logger = Logger(subsystem: "com.parkbyeongjun.latte", category: "shortcut")
    private static let signature: OSType = 0x4C617474  // 'Latt'
    private static let hotKeyID: UInt32 = 1

    /// Box that owns the closure across the C callback boundary. The callback
    /// reads `Self.activeHandler` directly because installing an EventHandler
    /// per registration would leak handlers on rapid toggle. One handler is
    /// installed lazily on first register().
    private static var activeHandler: (@MainActor () -> Void)?
    private static var eventHandlerInstalled = false

    private var hotKeyRef: EventHotKeyRef?

    public init() {}

    public var isRegistered: Bool { hotKeyRef != nil }

    public func register(handler: @escaping @MainActor () -> Void) {
        if hotKeyRef != nil {
            // Existing registration — keep the prior handler. Idempotent.
            return
        }
        Self.installEventHandlerIfNeeded()
        Self.activeHandler = handler

        var id = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_L)

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRef = ref
            Self.logger.info("global hotkey ⌘⇧L registered")
        } else {
            Self.logger.error("RegisterEventHotKey failed status=\(status)")
            Self.activeHandler = nil
        }
    }

    public func unregister() {
        guard let ref = hotKeyRef else { return }
        let status = UnregisterEventHotKey(ref)
        hotKeyRef = nil
        Self.activeHandler = nil
        if status != noErr {
            Self.logger.error("UnregisterEventHotKey failed status=\(status)")
        } else {
            Self.logger.info("global hotkey ⌘⇧L unregistered")
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
