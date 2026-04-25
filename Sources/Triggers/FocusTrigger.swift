import Foundation
#if canImport(Intents)
import Intents
#endif

// MARK: - FocusSource protocol

@MainActor
public protocol FocusSource: AnyObject {
    var permissionStatus: TriggerPermissionStatus { get }
    /// Whether *any* Focus is currently active. Apple's `INFocusStatus` does not expose
    /// the specific Focus identifier for privacy reasons, so v1 treats `focusTriggerFocusIDs`
    /// as a "Focus filter is on or off" enable rather than per-Focus selection. This is
    /// intentional and documented in 04 §4.5 footnote.
    var isFocusActive: Bool { get }
    func requestAccess() async -> Bool
    /// Subscribe to focus-status changes. Source must invoke `onChange` whenever
    /// `isFocusActive` flips. Returns a cancellation handle.
    func observe(onChange: @escaping @MainActor (Bool) -> Void) -> FocusObservation
}

public final class FocusObservation {
    private let cancelClosure: @MainActor () -> Void
    private var cancelled = false

    public init(cancel: @escaping @MainActor () -> Void) {
        self.cancelClosure = cancel
    }

    @MainActor
    public func cancel() {
        guard !cancelled else { return }
        cancelled = true
        cancelClosure()
    }
}

// MARK: - Real INFocusStatusCenter-backed source

#if canImport(Intents)
@MainActor
public final class INFocusSource: FocusSource {

    private let center: INFocusStatusCenter
    private let logger = LatteLog.focus
    private var kvoToken: NSKeyValueObservation?

    public init(center: INFocusStatusCenter = .default) {
        self.center = center
    }

    public var permissionStatus: TriggerPermissionStatus {
        switch center.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .restricted, .denied: return .denied
        case .authorized: return .granted
        @unknown default: return .notDetermined
        }
    }

    public var isFocusActive: Bool {
        center.focusStatus.isFocused ?? false
    }

    public func requestAccess() async -> Bool {
        let status = await center.requestAuthorization()
        return status == .authorized
    }

    public func observe(onChange: @escaping @MainActor (Bool) -> Void) -> FocusObservation {
        // INFocusStatusCenter.focusStatus is KVO-compliant.
        kvoToken = center.observe(\.focusStatus, options: [.new]) { [weak self] _, _ in
            guard let self else { return }
            let isActive = self.isFocusActive
            Task { @MainActor in onChange(isActive) }
        }
        return FocusObservation { [weak self] in
            self?.kvoToken?.invalidate()
            self?.kvoToken = nil
        }
    }
}
#endif

// MARK: - FocusTrigger

@MainActor
public final class FocusTrigger: Trigger {

    public let id = "focus"
    public let displayName = "Focus mode"
    public let symbol = "moon.fill"
    public let requiresPermission = true

    public var isEnabled: Bool {
        get { settings.bool(.focusTriggerEnabled, default: false) }
        set { settings.setBool(newValue, for: .focusTriggerEnabled) }
    }

    public var permissionStatus: TriggerPermissionStatus { source.permissionStatus }

    public let voteStream: AsyncStream<TriggerVote>
    private let continuation: AsyncStream<TriggerVote>.Continuation

    private let settings: SettingsStore
    private let source: FocusSource
    private let logger = LatteLog.focus

    private var observation: FocusObservation?
    private var lastVote: Bool? = nil

    public init(settings: SettingsStore, source: FocusSource? = nil) {
        self.settings = settings
        let (stream, continuation) = AsyncStream<TriggerVote>.makeStream()
        self.voteStream = stream
        self.continuation = continuation
        if let source {
            self.source = source
        } else {
            #if canImport(Intents)
            self.source = INFocusSource()
            #else
            self.source = NoopFocusSource()
            #endif
        }
    }

    public func start() async {
        guard observation == nil else { return }
        logger.info("FocusTrigger.start")
        evaluate(currentlyActive: source.isFocusActive)
        observation = source.observe { [weak self] isActive in
            self?.evaluate(currentlyActive: isActive)
        }
    }

    public func stop() {
        logger.info("FocusTrigger.stop")
        observation?.cancel()
        observation = nil
        lastVote = nil
        continuation.finish()
    }

    public func requestPermissionIfNeeded() async -> Bool {
        switch source.permissionStatus {
        case .granted: return true
        case .denied: return false
        case .notRequired, .notDetermined: return await source.requestAccess()
        }
    }

    /// Test seam — evaluate the trigger's vote given a known focus-active state.
    public func evaluate(currentlyActive: Bool) {
        guard isEnabled else { return }
        guard source.permissionStatus == .granted else { return }
        // v1: list non-empty + Focus active ⇒ ON. We can't filter by specific ID.
        let configured = !settings.focusTriggerFocusIDs.isEmpty
        let wantsAwake = configured && currentlyActive
        if lastVote == nil && !wantsAwake { return }
        if lastVote == wantsAwake { return }
        lastVote = wantsAwake
        continuation.yield(TriggerVote(
            wantsAwake: wantsAwake,
            reason: wantsAwake ? "Focus: active" : "Focus: inactive"
        ))
    }
}

// MARK: - Mock source

@MainActor
public final class MockFocusSource: FocusSource {
    public var permissionStatus: TriggerPermissionStatus
    public var isFocusActive: Bool {
        didSet {
            if isFocusActive != oldValue { onChange?(isFocusActive) }
        }
    }
    public private(set) var requestAccessCalls = 0
    private var onChange: ((Bool) -> Void)?

    public init(
        permissionStatus: TriggerPermissionStatus = .granted,
        isFocusActive: Bool = false
    ) {
        self.permissionStatus = permissionStatus
        self.isFocusActive = isFocusActive
    }

    public func requestAccess() async -> Bool {
        requestAccessCalls += 1
        if permissionStatus == .notDetermined { permissionStatus = .granted }
        return permissionStatus == .granted
    }

    public func observe(onChange: @escaping @MainActor (Bool) -> Void) -> FocusObservation {
        self.onChange = onChange
        return FocusObservation { [weak self] in
            self?.onChange = nil
        }
    }
}

#if !canImport(Intents)
@MainActor
final class NoopFocusSource: FocusSource {
    var permissionStatus: TriggerPermissionStatus { .denied }
    var isFocusActive: Bool { false }
    func requestAccess() async -> Bool { false }
    func observe(onChange: @escaping @MainActor (Bool) -> Void) -> FocusObservation {
        FocusObservation(cancel: {})
    }
}
#endif

// MARK: - SettingsStore typed extension (unchanged from S3)

public extension SettingsStore {
    var focusTriggerFocusIDs: [String] {
        get {
            let raw = decodeStringArray(.focusTriggerFocusIDs)
            return raw.isEmpty ? ["work"] : raw
        }
        set { encodeStringArray(newValue, for: .focusTriggerFocusIDs) }
    }
}
