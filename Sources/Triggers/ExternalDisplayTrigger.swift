import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - DisplaySource protocol

/// Stable identity + display name for a single attached external screen.
/// Used by the per-display whitelist (V2-06 deferred H) and surfaced in
/// Settings → Triggers → External Display.
public struct DisplayInfo: Equatable, Sendable, Identifiable {
    /// CGDisplay UUID (stable across reboots and display reorders).
    public let uuid: String
    /// Localized display name (e.g. "DELL U2723QE", "Studio Display").
    public let name: String

    public var id: String { uuid }

    public init(uuid: String, name: String) {
        self.uuid = uuid
        self.name = name
    }
}

@MainActor
public protocol DisplaySource: AnyObject {
    /// Number of attached external displays (excludes the built-in screen).
    var externalDisplayCount: Int { get }

    /// Localized name of the first external display, when available.
    /// Used for the vote reason string. `nil` falls back to "External Display".
    var firstExternalDisplayName: String? { get }

    /// True when the built-in display is absent from `NSScreen.screens`
    /// while at least one external is connected — the canonical clamshell
    /// case (MacBook lid closed, used as a desktop). When `false`, either
    /// the built-in is present (lid open) OR no external is attached.
    /// V2-06 deferred G — surfaces in the vote reason for owner debugging.
    var isInClamshellMode: Bool { get }

    /// All currently-attached external displays with their stable UUIDs.
    /// V2-06 deferred H — used by the per-display whitelist setting.
    /// Order is implementation-defined; whitelist matching is by UUID,
    /// not position.
    var attachedExternalDisplays: [DisplayInfo] { get }

    /// Emits whenever the screen configuration changes (attach, detach,
    /// resolution change, sleep/wake). The trigger consumes this to decide
    /// when to re-evaluate. The production adapter forwards every
    /// `NSApplication.didChangeScreenParametersNotification` raw — burst
    /// dedup actually lives in `ExternalDisplayTrigger.evaluate()` via
    /// the `lastVote == wantsAwake` guard. Tests drive change events
    /// directly through `MockDisplaySource.emitChange()`.
    var changeStream: AsyncStream<Void> { get }
}

// MARK: - NSScreen-backed production adapter

#if canImport(AppKit)
@MainActor
public final class NSScreenSource: DisplaySource {

    public let changeStream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private var observer: NSObjectProtocol?

    public init() {
        let (stream, cont) = AsyncStream<Void>.makeStream()
        self.changeStream = stream
        self.continuation = cont
        self.observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.continuation.yield(())
        }
    }

    isolated deinit {
        // `isolated deinit` (SE-0371) runs on the main actor so the teardown
        // can read the @MainActor-isolated `observer` token.
        if let observer { NotificationCenter.default.removeObserver(observer) }
        continuation.finish()
    }

    public var externalDisplayCount: Int {
        NSScreen.screens.filter { !Self.isBuiltIn($0) }.count
    }

    public var firstExternalDisplayName: String? {
        NSScreen.screens.first { !Self.isBuiltIn($0) }?.localizedName
    }

    public var isInClamshellMode: Bool {
        let screens = NSScreen.screens
        let hasExternal = screens.contains { !Self.isBuiltIn($0) }
        let hasBuiltIn = screens.contains { Self.isBuiltIn($0) }
        return hasExternal && !hasBuiltIn
    }

    public var attachedExternalDisplays: [DisplayInfo] {
        NSScreen.screens.compactMap { screen -> DisplayInfo? in
            guard !Self.isBuiltIn(screen) else { return nil }
            guard let id = Self.displayID(screen) else { return nil }
            guard let uuidRef = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
            let uuid = CFUUIDCreateString(nil, uuidRef) as String? ?? ""
            return DisplayInfo(uuid: uuid, name: screen.localizedName)
        }
    }

    private static func displayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return screen.deviceDescription[key] as? CGDirectDisplayID
    }

    private static func isBuiltIn(_ screen: NSScreen) -> Bool {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let displayID = screen.deviceDescription[key] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(displayID) != 0
    }
}
#endif

// MARK: - Debouncing decorator (V2-06 deferred I)

/// Wraps any `DisplaySource` and coalesces bursts of `changeStream` events
/// into one yield per `debounceInterval`. `didChangeScreenParametersNotification`
/// fires multiple times during a single attach (resolution adjust, mirror
/// negotiation, sleep/wake) — without coalescing, `ExternalDisplayTrigger.evaluate()`
/// runs N times per attach. The `lastVote` guard already squashes duplicate
/// emissions; debouncing additionally squashes the *evaluate calls* themselves.
@MainActor
public final class DebouncingDisplaySource: DisplaySource {

    public static let defaultDebounceInterval: TimeInterval = 0.3

    public let changeStream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private let upstream: DisplaySource
    private let debounceInterval: TimeInterval
    /// Monotonic counter bumped on every upstream event; the in-flight
    /// flush task captures its value at scheduling and yields only when
    /// no newer event has arrived during the debounce window. Replaces
    /// a cancel-and-create pattern that was racy under bursts (cancelled
    /// tasks could finish their sleep before the cancellation propagated).
    private var pendingSeq: Int = 0
    private var observeTask: Task<Void, Never>?

    public init(wrapping upstream: DisplaySource,
                debounceInterval: TimeInterval = DebouncingDisplaySource.defaultDebounceInterval) {
        self.upstream = upstream
        self.debounceInterval = debounceInterval
        let (stream, cont) = AsyncStream<Void>.makeStream()
        self.changeStream = stream
        self.continuation = cont
        // Capture `upstream` (the iterated stream's owner) but reach `self`
        // weakly inside the loop — a strong `self` ahead of the `for await`
        // retains the source across the suspension so `deinit` never runs
        // (project_latte_status.md trap #8).
        self.observeTask = Task { @MainActor [weak self, upstream] in
            for await _ in upstream.changeStream {
                if Task.isCancelled { break }
                self?.scheduleFlush()
            }
        }
    }

    deinit {
        observeTask?.cancel()
        continuation.finish()
    }

    public var externalDisplayCount: Int { upstream.externalDisplayCount }
    public var firstExternalDisplayName: String? { upstream.firstExternalDisplayName }
    public var isInClamshellMode: Bool { upstream.isInClamshellMode }
    public var attachedExternalDisplays: [DisplayInfo] { upstream.attachedExternalDisplays }

    private func scheduleFlush() {
        pendingSeq += 1
        let mySeq = pendingSeq
        let interval = debounceInterval
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard let self else { return }
            // Only the latest scheduled flush wins — earlier ones see
            // their seq superseded and bow out silently.
            if mySeq == self.pendingSeq {
                self.continuation.yield(())
            }
        }
    }
}

// MARK: - ExternalDisplayTrigger

@MainActor
public final class ExternalDisplayTrigger: Trigger {

    public let id = "external-display"
    public let displayName = "External Display"
    public let symbol = "display"
    public let requiresPermission = false

    public var isEnabled: Bool {
        get { settings.bool(.externalDisplayEnabled, default: false) }
        set { settings.setBool(newValue, for: .externalDisplayEnabled) }
    }

    public var permissionStatus: TriggerPermissionStatus { .notRequired }

    public let voteStream: AsyncStream<TriggerVote>
    private let continuation: AsyncStream<TriggerVote>.Continuation

    private let settings: SettingsStore
    private let source: DisplaySource
    private let logger = LatteLog.display

    private var lastVote: Bool? = nil
    private var observeTask: Task<Void, Never>?
    /// Gate that lets `evaluate()` emit. `source.changeStream` is single-
    /// consumer, so the observe task is installed once at the first
    /// `start()` and lives for the trigger's full lifetime. `stop()` flips
    /// the gate off (and resets `lastVote`); the next `start()` flips it
    /// back on and triggers a fresh evaluate against current source state.
    private var isRunning = false

    public init(settings: SettingsStore, source: DisplaySource? = nil) {
        self.settings = settings
        let (stream, cont) = AsyncStream<TriggerVote>.makeStream()
        self.voteStream = stream
        self.continuation = cont
        if let source {
            self.source = source
        } else {
            #if canImport(AppKit)
            // Production default: wrap NSScreenSource in a 300ms debouncer
            // so a single attach (which fires the screen-change notification
            // multiple times during resolution / mirror negotiation) drives
            // exactly one evaluate. Tests inject MockDisplaySource directly
            // and stay raw — debounce is upstream-only.
            self.source = DebouncingDisplaySource(wrapping: NSScreenSource())
            #else
            self.source = NoopDisplaySource()
            #endif
        }
    }

    deinit {
        observeTask?.cancel()
    }

    public func start() async {
        logger.info("ExternalDisplayTrigger.start")
        if observeTask == nil {
            // Install once — see `isRunning` doc. `source.changeStream`
            // can only be iterated by a single consumer for its entire
            // lifetime, so we keep this task alive across start/stop
            // cycles and gate evaluation through `isRunning`.
            // Capture `source` (the iterated stream's owner) but re-acquire
            // `self` weakly inside the loop. Binding a strong `self` ahead of
            // the `for await` retains the trigger across the suspension, so its
            // `deinit` (below) never runs and the trigger leaks
            // (project_latte_status.md trap #8).
            observeTask = Task { @MainActor [weak self] in
                guard let source = self?.source else { return }
                for await _ in source.changeStream {
                    if Task.isCancelled { break }
                    guard let self else { break }
                    // Gate observe-driven evaluation on the isRunning
                    // flag so source events during a stop window are
                    // ignored; the next start() will pick up fresh state.
                    if self.isRunning { self.evaluate() }
                }
            }
        }
        guard !isRunning else { return }
        isRunning = true
        evaluate()
    }

    public func stop() {
        logger.info("ExternalDisplayTrigger.stop")
        isRunning = false
        lastVote = nil
        // Per S7.11: do NOT call `continuation.finish()`. The AsyncStream
        // stays open for the trigger's registered lifetime so a future
        // start() can resume yielding to the existing consumer.
        // Note: observeTask is intentionally NOT cancelled here — see
        // `isRunning` doc for the single-consumer rationale.
    }

    public func requestPermissionIfNeeded() async -> Bool { true }

    /// Live count exposed for the Settings tab status row.
    public var externalDisplayCount: Int { source.externalDisplayCount }

    /// Live name exposed for the Settings tab status row.
    public var firstExternalDisplayName: String? { source.firstExternalDisplayName }

    /// V2-02 parity — re-evaluate immediately after a UI edit. No-op when
    /// stopped (the running indicator is `isRunning`); the next start()
    /// will read fresh state on its initial evaluate.
    public func reevaluateWatched() {
        guard isRunning else { return }
        evaluate()
    }

    /// **S22 / P-issue-6d** — see `Trigger.reemitCurrentVote()` doc.
    /// Clears `lastVote` so `evaluate()` bypasses its dedup and re-emits
    /// the current vote. No emission when no external display is
    /// connected (the `lastVote == nil && !wantsAwake` early-return
    /// holds — manager is already asleep).
    public func reemitCurrentVote() {
        guard isRunning else { return }
        lastVote = nil
        evaluate()
    }

    /// Test seam — evaluate the source against the lastVote and emit only
    /// on transition. The `isRunning` gate is enforced inside the
    /// `observeTask` callback (see `start()`) so source events during a
    /// stop window don't reach this method; tests can still call
    /// `evaluate()` directly to assert vote semantics.
    public func evaluate() {
        guard isEnabled else { return }
        let (wantsAwake, preferredName) = resolveVoteState()

        if lastVote == nil && !wantsAwake { return }
        if lastVote == wantsAwake { return }
        lastVote = wantsAwake

        let reason: String
        if wantsAwake {
            let name = preferredName ?? source.firstExternalDisplayName ?? "External Display"
            // V2-06 deferred G — surface clamshell so the owner reading
            // About → Status (or the Activity tab "Currently active" row)
            // can tell "is the lid closed" at a glance.
            reason = source.isInClamshellMode
                ? "Display: \(name) (clamshell)"
                : "Display: \(name)"
        } else {
            reason = "Display: disconnected"
        }
        continuation.yield(TriggerVote(wantsAwake: wantsAwake, reason: reason))
    }

    /// V2-06 deferred H — folds the whitelist setting into the source state.
    /// Returns the awake decision plus an optional preferred display name
    /// (the first whitelist match, when filtering is in effect; nil when
    /// the legacy bare-count path applies and the caller should fall back
    /// to `source.firstExternalDisplayName`).
    private func resolveVoteState() -> (wantsAwake: Bool, preferredName: String?) {
        let whitelist = settings.decodeStringArray(.externalDisplayWhitelist)
        if whitelist.isEmpty {
            // No filter — preserve v1.2 behaviour. `attachedExternalDisplays`
            // may be empty even with count >= 1 if the source is a count-only
            // mock fixture, so fall back to the bare count signal.
            let attached = source.attachedExternalDisplays
            if !attached.isEmpty {
                return (true, attached.first?.name)
            }
            return (source.externalDisplayCount >= 1, nil)
        }
        let allow = Set(whitelist)
        let matches = source.attachedExternalDisplays.filter { allow.contains($0.uuid) }
        return (!matches.isEmpty, matches.first?.name)
    }

    /// V2-06 deferred H — exposes the live attached list for the Settings
    /// picker. Non-mutating; the picker writes its selection back to
    /// `SettingsKey.externalDisplayWhitelist`.
    public var attachedExternalDisplays: [DisplayInfo] { source.attachedExternalDisplays }

    /// V2-06 deferred H — returns the currently-stored whitelist UUIDs.
    public var whitelistedUUIDs: [String] {
        settings.decodeStringArray(.externalDisplayWhitelist)
    }

    /// V2-06 deferred H — persists a new whitelist + re-evaluates so the
    /// vote flips on the spot when the owner narrows or widens the filter.
    public func setWhitelistedUUIDs(_ uuids: [String]) {
        settings.encodeStringArray(uuids, for: .externalDisplayWhitelist)
        if isRunning { evaluate() }
    }
}

// MARK: - Mock source (production-shipped, used only by tests + smoke env-var)

@MainActor
public final class MockDisplaySource: DisplaySource {

    public var externalDisplayCount: Int
    public var firstExternalDisplayName: String?
    public var isInClamshellMode: Bool
    public var attachedExternalDisplays: [DisplayInfo]

    public let changeStream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    public init(externalDisplayCount: Int = 0,
                firstExternalDisplayName: String? = nil,
                isInClamshellMode: Bool = false,
                attachedExternalDisplays: [DisplayInfo] = []) {
        self.externalDisplayCount = externalDisplayCount
        self.firstExternalDisplayName = firstExternalDisplayName
        self.isInClamshellMode = isInClamshellMode
        self.attachedExternalDisplays = attachedExternalDisplays
        let (stream, cont) = AsyncStream<Void>.makeStream()
        self.changeStream = stream
        self.continuation = cont
    }

    /// Update attached display list + emit a change event so the trigger
    /// re-evaluates against the new whitelist match set.
    public func setAttachedDisplays(_ displays: [DisplayInfo]) {
        attachedExternalDisplays = displays
        externalDisplayCount = displays.count
        firstExternalDisplayName = displays.first?.name
        continuation.yield(())
    }

    /// Update clamshell flag + emit a change event so the trigger
    /// re-evaluates with the new lid-state context.
    public func setClamshellMode(_ value: Bool) {
        isInClamshellMode = value
        continuation.yield(())
    }

    /// Update count + emit a change event so the trigger re-evaluates.
    public func setCount(_ count: Int) {
        externalDisplayCount = count
        continuation.yield(())
    }

    /// Update first-display name + emit a change event.
    public func setFirstName(_ name: String?) {
        firstExternalDisplayName = name
        continuation.yield(())
    }

    /// Emit a raw change event without changing state — useful for testing
    /// observe-task wiring without state transitions.
    public func emitChange() {
        continuation.yield(())
    }

    deinit { continuation.finish() }
}

#if !canImport(AppKit)
@MainActor
final class NoopDisplaySource: DisplaySource {
    var externalDisplayCount: Int { 0 }
    var firstExternalDisplayName: String? { nil }
    var isInClamshellMode: Bool { false }
    var attachedExternalDisplays: [DisplayInfo] { [] }
    let changeStream: AsyncStream<Void>
    init() {
        let (stream, cont) = AsyncStream<Void>.makeStream()
        self.changeStream = stream
        cont.finish()
    }
}
#endif
