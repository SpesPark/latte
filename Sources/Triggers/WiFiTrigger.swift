import Foundation

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

    public private(set) var permissionStatus: TriggerPermissionStatus = .notDetermined

    public let voteStream: AsyncStream<TriggerVote>
    private let continuation: AsyncStream<TriggerVote>.Continuation

    private let settings: SettingsStore
    private let logger = LatteLog.wifi

    public init(settings: SettingsStore) {
        self.settings = settings
        let (stream, continuation) = AsyncStream<TriggerVote>.makeStream()
        self.voteStream = stream
        self.continuation = continuation
    }

    public func start() async {
        // Real CWWiFiClient wiring lands in session 4.
        logger.info("WiFiTrigger.start (stub)")
    }

    public func stop() {
        logger.info("WiFiTrigger.stop (stub)")
        continuation.finish()
    }

    public func requestPermissionIfNeeded() async -> Bool {
        // Location permission required for SSID access on macOS 10.15+.
        return false
    }
}

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
