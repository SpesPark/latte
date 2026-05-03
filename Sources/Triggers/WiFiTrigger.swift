import Foundation
#if canImport(CoreWLAN)
import CoreWLAN
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - WiFiSource protocol

@MainActor
public protocol WiFiSource: AnyObject {
    var permissionStatus: TriggerPermissionStatus { get }
    /// Currently joined SSID, or nil if disconnected.
    var currentSSID: String? { get }
    func requestAccess() async -> Bool
}

// MARK: - Real CoreWLAN-backed source

#if canImport(CoreWLAN) && canImport(CoreLocation)
@MainActor
public final class CoreWLANSource: NSObject, WiFiSource, CLLocationManagerDelegate {

    private let client: CWWiFiClient
    private let locationManager: CLLocationManager
    private let logger = LatteLog.wifi
    private var pendingPermissionContinuation: CheckedContinuation<Bool, Never>?

    public init(client: CWWiFiClient = .shared(), locationManager: CLLocationManager = CLLocationManager()) {
        self.client = client
        self.locationManager = locationManager
        super.init()
        self.locationManager.delegate = self
    }

    public var permissionStatus: TriggerPermissionStatus {
        let status: CLAuthorizationStatus = {
            if #available(macOS 11.0, *) {
                return locationManager.authorizationStatus
            } else {
                return CLLocationManager.authorizationStatus()
            }
        }()
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted, .denied: return .denied
        case .authorized, .authorizedAlways: return .granted
        @unknown default: return .notDetermined
        }
    }

    public var currentSSID: String? {
        client.interface()?.ssid()
    }

    public func requestAccess() async -> Bool {
        if permissionStatus == .granted { return true }
        if permissionStatus == .denied { return false }
        return await withCheckedContinuation { continuation in
            pendingPermissionContinuation = continuation
            locationManager.requestAlwaysAuthorization()
        }
    }

    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        Task { @MainActor in
            guard let continuation = self.pendingPermissionContinuation else { return }
            self.pendingPermissionContinuation = nil
            let granted: Bool
            switch status {
            case .authorized, .authorizedAlways: granted = true
            default: granted = false
            }
            continuation.resume(returning: granted)
        }
    }
}
#endif

// MARK: - WiFiTrigger

@MainActor
public final class WiFiTrigger: Trigger {

    public let id = "wifi"
    public let displayName = "Wi-Fi network"
    public let symbol = "wifi"
    public let requiresPermission = true

    public var isEnabled: Bool {
        get { settings.bool(.wifiTriggerEnabled, default: false) }
        set { settings.setBool(newValue, for: .wifiTriggerEnabled) }
    }

    public var permissionStatus: TriggerPermissionStatus { source.permissionStatus }

    public let voteStream: AsyncStream<TriggerVote>
    private let continuation: AsyncStream<TriggerVote>.Continuation

    private let settings: SettingsStore
    private let source: WiFiSource
    private let pollInterval: TimeInterval
    private let logger = LatteLog.wifi

    private var lastVote: Bool? = nil
    private var pollTask: Task<Void, Never>?

    public init(
        settings: SettingsStore,
        source: WiFiSource? = nil,
        pollInterval: TimeInterval = 30
    ) {
        self.settings = settings
        self.pollInterval = pollInterval
        let (voteStream, voteContinuation) = AsyncStream<TriggerVote>.makeStream()
        self.voteStream = voteStream
        self.continuation = voteContinuation
        if let source {
            self.source = source
        } else {
            #if canImport(CoreWLAN) && canImport(CoreLocation)
            self.source = CoreWLANSource()
            #else
            self.source = NoopWiFiSource()
            #endif
        }
    }

    public func start() async {
        guard pollTask == nil else { return }
        logger.info("WiFiTrigger.start")
        evaluate()
        pollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                if Task.isCancelled { break }
                self.evaluate()
            }
        }
    }

    public func stop() {
        logger.info("WiFiTrigger.stop")
        pollTask?.cancel()
        pollTask = nil
        lastVote = nil
        // Per S7.9 / S7.11: do NOT call `continuation.finish()`. See
        // CalendarTrigger.stop() for the rationale — the AsyncStream stays
        // open for the trigger's lifetime so Toggle OFF→ON cycles work.
    }

    public func requestPermissionIfNeeded() async -> Bool {
        switch source.permissionStatus {
        case .granted: return true
        case .denied: return false
        case .notRequired, .notDetermined: return await source.requestAccess()
        }
    }

    /// Currently joined SSID (or `nil` if disconnected / unauthorized).
    /// Exposed for the Settings UI's "Add current network" picker.
    public var currentSSID: String? {
        source.currentSSID
    }

    /// V2-02 — re-evaluate immediately after a UI edit so settings changes
    /// commit within one render pass instead of waiting up to 30 s for the
    /// next poll. No-op when the trigger is stopped (running indicator is
    /// `pollTask`); the next `start()` will read fresh settings on its
    /// initial evaluate.
    public func reevaluateWatched() {
        guard pollTask != nil else { return }
        evaluate()
    }

    /// **S22 / P-issue-6d** — see `Trigger.reemitCurrentVote()` doc.
    /// Clears `lastVote` so `evaluate()` bypasses its dedup and re-emits
    /// the current vote. No emission when condition is false (the
    /// `lastVote == nil && !wantsAwake` early-return holds — manager is
    /// already asleep, redundant OFF would be noise).
    public func reemitCurrentVote() {
        guard pollTask != nil else { return }
        lastVote = nil
        evaluate()
    }

    /// Test seam — evaluate current SSID against settings and emit if vote changed.
    public func evaluate() {
        guard isEnabled else { return }
        guard source.permissionStatus == .granted else { return }
        let ssids = Set(settings.wifiTriggerSSIDs)
        let inverse = settings.wifiTriggerInverseLogic
        let currentSSID = source.currentSSID

        let onList = currentSSID.map(ssids.contains) ?? false
        let wantsAwake: Bool
        if inverse {
            // Vote ON when not on listed networks AND we have any list configured.
            // (Empty list under inverse = always ON, which is silly; treat empty list as no-op.)
            wantsAwake = !ssids.isEmpty && !onList
        } else {
            wantsAwake = onList
        }

        if lastVote == nil && !wantsAwake { return }
        if lastVote == wantsAwake { return }
        lastVote = wantsAwake
        let reason: String
        if wantsAwake {
            reason = inverse
                ? "Wi-Fi: off allowlist (\(currentSSID ?? "none"))"
                : "Wi-Fi: on \(currentSSID ?? "unknown")"
        } else {
            reason = "Wi-Fi: condition no longer met"
        }
        continuation.yield(TriggerVote(wantsAwake: wantsAwake, reason: reason))
    }
}

// MARK: - Mock source

@MainActor
public final class MockWiFiSource: WiFiSource {
    public var permissionStatus: TriggerPermissionStatus
    public var currentSSID: String?
    public private(set) var requestAccessCalls = 0

    public init(
        permissionStatus: TriggerPermissionStatus = .granted,
        currentSSID: String? = nil
    ) {
        self.permissionStatus = permissionStatus
        self.currentSSID = currentSSID
    }

    public func requestAccess() async -> Bool {
        requestAccessCalls += 1
        if permissionStatus == .notDetermined { permissionStatus = .granted }
        return permissionStatus == .granted
    }
}

#if !(canImport(CoreWLAN) && canImport(CoreLocation))
@MainActor
final class NoopWiFiSource: WiFiSource {
    var permissionStatus: TriggerPermissionStatus { .denied }
    var currentSSID: String? { nil }
    func requestAccess() async -> Bool { false }
}
#endif

// MARK: - SettingsStore typed extensions (unchanged from S3)

public extension SettingsStore {
    var wifiTriggerSSIDs: [String] {
        get { decodeStringArray(.wifiTriggerSSIDs).filter { !$0.isEmpty && $0.utf8.count <= 32 } }
        set {
            let cleaned = newValue.filter { !$0.isEmpty && $0.utf8.count <= 32 }
            encodeStringArray(cleaned, for: .wifiTriggerSSIDs)
        }
    }

    var wifiTriggerInverseLogic: Bool {
        get { bool(.wifiTriggerInverseLogic, default: false) }
        set { setBool(newValue, for: .wifiTriggerInverseLogic) }
    }
}
