import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - WorkspaceSource protocol

/// Subset of `NSWorkspace` we depend on. Mockable.
@MainActor
public protocol WorkspaceSource: AnyObject {
    /// Snapshot of currently running apps' bundle IDs (filtered to non-nil).
    var runningBundleIDs: [String] { get }

    /// Subscribe to launch / terminate events. Each callback is invoked on the main actor with
    /// the affected bundle identifier (nil-safe; callers may ignore unrecognized launches).
    /// Returns a cancellation handle; calling `cancel()` removes both observers.
    func observeLifecycle(
        onLaunch: @escaping @MainActor (String) -> Void,
        onTerminate: @escaping @MainActor (String) -> Void
    ) -> WorkspaceObservation
}

public final class WorkspaceObservation {
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

// MARK: - Real NSWorkspace-backed source

#if canImport(AppKit)
@MainActor
public final class NSWorkspaceSource: WorkspaceSource {

    private let workspace: NSWorkspace

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public var runningBundleIDs: [String] {
        workspace.runningApplications.compactMap { $0.bundleIdentifier }
    }

    public func observeLifecycle(
        onLaunch: @escaping @MainActor (String) -> Void,
        onTerminate: @escaping @MainActor (String) -> Void
    ) -> WorkspaceObservation {
        let center = workspace.notificationCenter
        let launch = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            guard
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let bundleID = app.bundleIdentifier
            else { return }
            Task { @MainActor in onLaunch(bundleID) }
        }
        let terminate = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            guard
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let bundleID = app.bundleIdentifier
            else { return }
            Task { @MainActor in onTerminate(bundleID) }
        }
        return WorkspaceObservation { [weak center] in
            center?.removeObserver(launch)
            center?.removeObserver(terminate)
        }
    }
}
#endif

// MARK: - AppTrigger

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
    private let source: WorkspaceSource
    private let logger = LatteLog.app

    private var matchingRunning: Set<String> = []
    private var observation: WorkspaceObservation?

    public init(settings: SettingsStore, source: WorkspaceSource? = nil) {
        self.settings = settings
        let (stream, continuation) = AsyncStream<TriggerVote>.makeStream()
        self.voteStream = stream
        self.continuation = continuation
        if let source {
            self.source = source
        } else {
            #if canImport(AppKit)
            self.source = NSWorkspaceSource()
            #else
            self.source = NoopWorkspaceSource()
            #endif
        }
    }

    public func start() async {
        guard observation == nil else { return }
        logger.info("AppTrigger.start")
        let watched = Set(settings.appTriggerBundleIDs)

        // Initial snapshot
        matchingRunning = Set(source.runningBundleIDs).intersection(watched)
        if !matchingRunning.isEmpty {
            emitOn()
        }

        observation = source.observeLifecycle(
            onLaunch: { [weak self] bundleID in
                self?.handleLaunch(bundleID: bundleID, watched: watched)
            },
            onTerminate: { [weak self] bundleID in
                self?.handleTerminate(bundleID: bundleID, watched: watched)
            }
        )
    }

    public func stop() {
        logger.info("AppTrigger.stop")
        observation?.cancel()
        observation = nil
        matchingRunning.removeAll()
        continuation.finish()
    }

    public func requestPermissionIfNeeded() async -> Bool { true }

    private func handleLaunch(bundleID: String, watched: Set<String>) {
        guard watched.contains(bundleID) else { return }
        let wasEmpty = matchingRunning.isEmpty
        matchingRunning.insert(bundleID)
        if wasEmpty { emitOn() }
    }

    private func handleTerminate(bundleID: String, watched: Set<String>) {
        guard watched.contains(bundleID) else { return }
        matchingRunning.remove(bundleID)
        if matchingRunning.isEmpty {
            continuation.yield(TriggerVote(wantsAwake: false, reason: "App: no watched apps running"))
        }
    }

    private func emitOn() {
        let names = matchingRunning.sorted().joined(separator: ", ")
        continuation.yield(TriggerVote(wantsAwake: true, reason: "App: \(names)"))
    }
}

#if !canImport(AppKit)
@MainActor
final class NoopWorkspaceSource: WorkspaceSource {
    var runningBundleIDs: [String] { [] }
    func observeLifecycle(
        onLaunch: @escaping @MainActor (String) -> Void,
        onTerminate: @escaping @MainActor (String) -> Void
    ) -> WorkspaceObservation {
        WorkspaceObservation(cancel: {})
    }
}
#endif

// MARK: - Mock source

@MainActor
public final class MockWorkspaceSource: WorkspaceSource {
    public var runningBundleIDs: [String]
    public private(set) var observationCount = 0
    private var onLaunch: (@MainActor (String) -> Void)?
    private var onTerminate: (@MainActor (String) -> Void)?

    public init(runningBundleIDs: [String] = []) {
        self.runningBundleIDs = runningBundleIDs
    }

    public func observeLifecycle(
        onLaunch: @escaping @MainActor (String) -> Void,
        onTerminate: @escaping @MainActor (String) -> Void
    ) -> WorkspaceObservation {
        observationCount += 1
        self.onLaunch = onLaunch
        self.onTerminate = onTerminate
        return WorkspaceObservation { [weak self] in
            self?.onLaunch = nil
            self?.onTerminate = nil
        }
    }

    /// Test helper: simulate a launch. Updates `runningBundleIDs` and fires the observer.
    public func simulateLaunch(_ bundleID: String) {
        if !runningBundleIDs.contains(bundleID) { runningBundleIDs.append(bundleID) }
        onLaunch?(bundleID)
    }

    /// Test helper: simulate a terminate.
    public func simulateTerminate(_ bundleID: String) {
        runningBundleIDs.removeAll { $0 == bundleID }
        onTerminate?(bundleID)
    }
}

// MARK: - Existing curated defaults + sanitizer (unchanged from S3)

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
                return AppTriggerDefaults.bundleIDs
            }
            return AppTriggerDefaults.sanitize(raw)
        }
        set {
            encodeStringArray(AppTriggerDefaults.sanitize(newValue), for: .appTriggerBundleIDs)
        }
    }
}
