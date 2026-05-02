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

    /// React to a Settings-driven change in the trigger's watched-set
    /// (e.g. user edited the AppTrigger bundle-id list, or rotated their
    /// Wi-Fi watched SSIDs). **Idempotent — no-op when the watched-set is
    /// unchanged.** Implemented by Calendar / WiFi / Schedule / App /
    /// ExternalDisplay triggers since S9c. The default empty impl covers
    /// `MockTrigger` and any future trigger without a settings-watched
    /// surface.
    func reevaluateWatched()

    /// **S22 / P-issue-5b**: emit the current vote based on present
    /// conditions, **bypassing the dedup that `reevaluateWatched()`
    /// applies on watched-set diff**. Called by
    /// `TriggerCoordinator.reevaluateAll()` after a constraint that
    /// suppressed votes (pause-all, AC-required) is lifted —
    /// `AwakeManager` has cleared its `pendingVotes`, so the trigger
    /// must re-yield its ON vote even when its own internal state hasn't
    /// changed. No emission when the trigger's condition isn't met
    /// (avoids spurious OFF votes against an already-asleep manager).
    /// Default empty impl is correct for triggers without a steady-state
    /// condition (e.g. `MockTrigger`).
    func reemitCurrentVote()
}

public extension Trigger {
    var graceSecondsAfterOff: TimeInterval { 0 }
    func reevaluateWatched() {}
    func reemitCurrentVote() {}
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
