import Foundation

public enum TriggerPermissionStatus: Equatable, Sendable {
    case notRequired
    case notDetermined
    case granted
    case denied
}

@MainActor
public protocol Trigger: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var symbol: String { get }
    var requiresPermission: Bool { get }

    var isEnabled: Bool { get set }
    var permissionStatus: TriggerPermissionStatus { get }

    func start() async
    func stop()
    func requestPermissionIfNeeded() async -> Bool

    var voteStream: AsyncStream<TriggerVote> { get }

    /// How long (seconds) to keep the awake assertion held after this
    /// trigger's last organic OFF vote, before releasing it. 0 = release
    /// immediately. Used to absorb brief trigger-condition flapping (e.g.,
    /// a transient WiFi blip) without flickering the cup off-on. **User-
    /// explicit OFF actions** (Toggle OFF in Settings, removing the last
    /// matching watched app) always bypass this and release immediately.
    /// Default impl returns 0.
    var graceSecondsAfterOff: TimeInterval { get }

    /// **S22 / P-issue-5**: re-emit the current vote based on present
    /// conditions. Called by `TriggerCoordinator.reevaluateAll()` after
    /// pause-all is lifted (or any other moment a stale shadow set may
    /// have been cleared). Concrete triggers that already implement this
    /// for their own UI flows (`AppTrigger` since S7.9, plus Calendar /
    /// WiFi / Schedule / ExternalDisplay added in S9c+) override this;
    /// the default empty impl handles `MockTrigger` and any future
    /// trigger that has no steady-state condition to re-evaluate.
    func reevaluateWatched()
}

public extension Trigger {
    var graceSecondsAfterOff: TimeInterval { 0 }
    func reevaluateWatched() {}
}

@MainActor
public final class MockTrigger: Trigger {
    public let id: String
    public let displayName: String
    public let symbol: String
    public let requiresPermission: Bool
    public var isEnabled: Bool
    public var permissionStatus: TriggerPermissionStatus

    private let continuation: AsyncStream<TriggerVote>.Continuation
    public let voteStream: AsyncStream<TriggerVote>

    public private(set) var startCalls = 0
    public private(set) var stopCalls = 0
    public private(set) var permissionCalls = 0

    public init(
        id: String,
        displayName: String = "Mock Trigger",
        symbol: String = "circle",
        requiresPermission: Bool = false,
        isEnabled: Bool = true,
        permissionStatus: TriggerPermissionStatus = .notRequired
    ) {
        self.id = id
        self.displayName = displayName
        self.symbol = symbol
        self.requiresPermission = requiresPermission
        self.isEnabled = isEnabled
        self.permissionStatus = permissionStatus
        let (stream, continuation) = AsyncStream<TriggerVote>.makeStream()
        self.voteStream = stream
        self.continuation = continuation
    }

    public func start() async {
        startCalls += 1
    }

    public func stop() {
        stopCalls += 1
        // Mirror the real triggers (Calendar/WiFi/Focus/App) post-S7.9:
        // do NOT finish the continuation. Stop only halts production;
        // the AsyncStream stays alive across the trigger's registered
        // lifetime so a future start() can re-yield to the same
        // long-lived consumer.
    }

    public func requestPermissionIfNeeded() async -> Bool {
        permissionCalls += 1
        return permissionStatus == .granted || permissionStatus == .notRequired
    }

    public func emit(_ vote: TriggerVote) {
        continuation.yield(vote)
    }
}
