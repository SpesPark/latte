import Foundation

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

    public private(set) var permissionStatus: TriggerPermissionStatus = .notDetermined

    public let voteStream: AsyncStream<TriggerVote>
    private let continuation: AsyncStream<TriggerVote>.Continuation

    private let settings: SettingsStore
    private let logger = LatteLog.focus

    public init(settings: SettingsStore) {
        self.settings = settings
        let (stream, continuation) = AsyncStream<TriggerVote>.makeStream()
        self.voteStream = stream
        self.continuation = continuation
    }

    public func start() async {
        // Real AppIntents Focus filter integration lands in session 4.
        logger.info("FocusTrigger.start (stub)")
    }

    public func stop() {
        logger.info("FocusTrigger.stop (stub)")
        continuation.finish()
    }

    public func requestPermissionIfNeeded() async -> Bool { false }
}

public extension SettingsStore {
    var focusTriggerFocusIDs: [String] {
        get {
            let raw = decodeStringArray(.focusTriggerFocusIDs)
            return raw.isEmpty ? ["work"] : raw
        }
        set { encodeStringArray(newValue, for: .focusTriggerFocusIDs) }
    }
}
