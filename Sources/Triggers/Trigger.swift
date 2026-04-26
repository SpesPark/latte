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
}

public extension Trigger {
    var graceSecondsAfterOff: TimeInterval { 0 }
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
        continuation.finish()
    }

    public func requestPermissionIfNeeded() async -> Bool {
        permissionCalls += 1
        return permissionStatus == .granted || permissionStatus == .notRequired
    }

    public func emit(_ vote: TriggerVote) {
        continuation.yield(vote)
    }
}
