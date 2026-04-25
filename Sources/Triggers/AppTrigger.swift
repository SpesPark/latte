import Foundation

@MainActor
public final class AppTrigger: Trigger {

    public let id = "app"
    public let displayName = "Running apps"
    public let symbol = "app.badge"
    public let requiresPermission = false

    public var isEnabled: Bool {
        get { settings.bool(.appTriggerEnabled, default: false) }
        set { settings.setBool(newValue, for: .appTriggerEnabled) }
    }

    public let permissionStatus: TriggerPermissionStatus = .notRequired

    public let voteStream: AsyncStream<TriggerVote>
    private let continuation: AsyncStream<TriggerVote>.Continuation

    private let settings: SettingsStore
    private let logger = LatteLog.app

    public init(settings: SettingsStore) {
        self.settings = settings
        let (stream, continuation) = AsyncStream<TriggerVote>.makeStream()
        self.voteStream = stream
        self.continuation = continuation
    }

    public func start() async {
        // Real NSWorkspace.didLaunchApplicationNotification wiring lands in session 4.
        logger.info("AppTrigger.start (stub)")
    }

    public func stop() {
        logger.info("AppTrigger.stop (stub)")
        continuation.finish()
    }

    public func requestPermissionIfNeeded() async -> Bool { true }
}

public enum AppTriggerDefaults {
    public static let bundleIDs: [String] = [
        "us.zoom.xos",
        "com.microsoft.teams2",
        "com.cisco.webex.meetings",
        "com.hnc.Discord",
        "com.tinyspeck.slackmacgap",
        "com.google.Chrome.helper.meet"
    ]

    /// Drops invalid entries silently per 04 §4.3.2.
    public static func sanitize(_ ids: [String]) -> [String] {
        let pattern = "^[a-zA-Z0-9.-]+$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return ids.filter { id in
            guard id.count <= 200, !id.isEmpty else { return false }
            let range = NSRange(id.startIndex..., in: id)
            return regex.firstMatch(in: id, range: range) != nil
        }
    }
}

public extension SettingsStore {
    var appTriggerBundleIDs: [String] {
        get {
            let raw = decodeStringArray(.appTriggerBundleIDs)
            if raw.isEmpty {
                // First read; provide curated defaults.
                return AppTriggerDefaults.bundleIDs
            }
            return AppTriggerDefaults.sanitize(raw)
        }
        set {
            encodeStringArray(AppTriggerDefaults.sanitize(newValue), for: .appTriggerBundleIDs)
        }
    }
}
