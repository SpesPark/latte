import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - AppDisplayInfo

/// Friendly display data for a watched bundle ID. `iconImageData` is PNG bytes
/// (typically a downsampled 64×64 raster) so the type stays `Sendable` and the
/// protocol stays platform-agnostic; the UI renders via `NSImage(data:)`.
public struct AppDisplayInfo: Equatable, Sendable {
    public let bundleID: String
    public let displayName: String
    public let iconImageData: Data?

    public init(bundleID: String, displayName: String, iconImageData: Data? = nil) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.iconImageData = iconImageData
    }
}

// MARK: - WorkspaceSource protocol

/// Subset of `NSWorkspace` we depend on. Mockable.
@MainActor
public protocol WorkspaceSource: AnyObject {
    /// Snapshot of currently running apps' bundle IDs (filtered to non-nil).
    /// Used by `AppTrigger.start()` for the initial intersection with the
    /// watched list — must not be filtered by activation policy, since
    /// trigger lifecycle should track every kind of running app.
    var runningBundleIDs: [String] { get }

    /// Subset of `runningBundleIDs` suitable for offering in user-facing
    /// pickers like "Add from running apps". Real implementations filter to
    /// `.regular` activation policy (apps the user actively works in,
    /// approximately the Dock-visible set) and exclude the current process.
    var pickableRunningBundleIDs: [String] { get }

    /// Resolve a friendly display name + optional icon for a bundle ID.
    ///
    /// Real implementations resolve in priority order: running app metadata →
    /// installed-app metadata via `urlForApplication(withBundleIdentifier:)` →
    /// `AppTriggerDefaults.displayName(for:)` curated table → `nil`.
    func displayInfo(for bundleID: String) -> AppDisplayInfo?

    /// Whether this bundle ID resolves to an installed app on the system.
    /// Used by `AppTriggerDefaults.installedDefaults(in:)` to filter the
    /// curated default seed list to apps that actually exist on the user's
    /// machine, so first-launch doesn't pre-populate apps the user doesn't
    /// have. Real implementations check
    /// `NSWorkspace.urlForApplication(withBundleIdentifier:)`.
    func isInstalled(_ bundleID: String) -> Bool

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

    public var pickableRunningBundleIDs: [String] {
        let myBundleID = Bundle.main.bundleIdentifier
        return workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> String? in
                guard let id = app.bundleIdentifier else { return nil }
                if let myBundleID, id == myBundleID { return nil }
                return id
            }
    }

    public func isInstalled(_ bundleID: String) -> Bool {
        workspace.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    public func displayInfo(for bundleID: String) -> AppDisplayInfo? {
        // Priority 1: currently running — use NSRunningApplication metadata.
        if let app = workspace.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID })
        {
            let name = app.localizedName
                ?? AppTriggerDefaults.displayName(for: bundleID)
                ?? bundleID
            let iconData = app.icon.flatMap { Self.pngData(from: $0) }
            return AppDisplayInfo(
                bundleID: bundleID,
                displayName: name,
                iconImageData: iconData
            )
        }

        // Priority 2: installed but not running — resolve via bundle URL.
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            let bundle = Bundle(url: url)
            let name = (bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle?.infoDictionary?["CFBundleName"] as? String)
                ?? AppTriggerDefaults.displayName(for: bundleID)
                ?? bundleID
            let iconImage = workspace.icon(forFile: url.path)
            let iconData = Self.pngData(from: iconImage)
            return AppDisplayInfo(
                bundleID: bundleID,
                displayName: name,
                iconImageData: iconData
            )
        }

        // Priority 3: curated default name only (no icon).
        if let curated = AppTriggerDefaults.displayName(for: bundleID) {
            return AppDisplayInfo(bundleID: bundleID, displayName: curated)
        }

        // Priority 4: unknown.
        return nil
    }

    /// Downsample to ~64pt so the encoded PNG stays small (a few KB).
    /// Settings rows render at 20pt — 64pt covers @2x retina with margin.
    private static func pngData(from image: NSImage) -> Data? {
        let maxDimension: CGFloat = 64
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }
        let scale = min(maxDimension / max(originalSize.width, originalSize.height), 1.0)
        let targetSize = NSSize(
            width: max(1, originalSize.width * scale),
            height: max(1, originalSize.height * scale)
        )
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        resized.unlockFocus()
        guard let cgImage = resized.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
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
    /// Snapshot of `settings.appTriggerBundleIDs` taken at `start()`. Held as
    /// an instance var (rather than captured into the lifecycle closures) so
    /// `reevaluateWatched()` can update it from the UI without restarting the
    /// observer — see the S7.9 fix for "removed app from watched list keeps
    /// voting awake."
    private var watchedSet: Set<String> = []

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
        seedInstalledDefaultsIfNeeded()
    }

    /// First-launch seed: if the user has never had a watched list (raw
    /// storage empty AND seeding flag never set), populate with the
    /// curated defaults that resolve to an installed app on this machine.
    /// Idempotent — once `hasSeededAppDefaults` is true, this is a no-op.
    /// Skips entirely if the user has already configured a non-empty list,
    /// so explicitly-cleared lists stay cleared.
    private func seedInstalledDefaultsIfNeeded() {
        guard !settings.bool(.hasSeededAppDefaults, default: false) else { return }
        let raw = settings.decodeStringArray(.appTriggerBundleIDs)
        guard raw.isEmpty else {
            settings.setBool(true, for: .hasSeededAppDefaults)
            return
        }
        let installed = AppTriggerDefaults.installedDefaults(in: source)
        settings.appTriggerBundleIDs = installed
        settings.setBool(true, for: .hasSeededAppDefaults)
    }

    public func start() async {
        guard observation == nil else { return }
        logger.info("AppTrigger.start")
        watchedSet = Set(settings.appTriggerBundleIDs)

        // Initial snapshot
        matchingRunning = Set(source.runningBundleIDs).intersection(watchedSet)
        if !matchingRunning.isEmpty {
            emitOn()
        }

        observation = source.observeLifecycle(
            onLaunch: { [weak self] bundleID in
                self?.handleLaunch(bundleID: bundleID)
            },
            onTerminate: { [weak self] bundleID in
                self?.handleTerminate(bundleID: bundleID)
            }
        )
    }

    public func stop() {
        logger.info("AppTrigger.stop")
        observation?.cancel()
        observation = nil
        matchingRunning.removeAll()
        watchedSet.removeAll()
        // Note: `continuation.finish()` is intentionally NOT called here —
        // doing so would close the AsyncStream permanently and prevent any
        // future `start()` from delivering votes. The coordinator cancels its
        // consumer task on stop; subsequent `start()` recreates a consumer
        // that picks up votes again on the same long-lived stream.
    }

    public func requestPermissionIfNeeded() async -> Bool { true }

    /// Snapshot of bundle IDs currently running on the system. Used by the
    /// Settings UI's "Add from running apps" picker so users can configure
    /// the trigger from real, in-context candidates.
    public var runningBundleIDs: [String] {
        source.runningBundleIDs
    }

    /// Filtered, user-facing subset of `runningBundleIDs` for pickers.
    public var pickableRunningBundleIDs: [String] {
        source.pickableRunningBundleIDs
    }

    /// Resolve friendly display info for a watched bundle ID. The Settings UI
    /// uses this to show app names + icons in place of raw bundle IDs.
    public func displayInfo(for bundleID: String) -> AppDisplayInfo? {
        source.displayInfo(for: bundleID)
    }

    /// React to changes in `settings.appTriggerBundleIDs` while the trigger
    /// is observing. Adding a watched app that's already running emits ON;
    /// removing the last watched app that was matching emits OFF; changing
    /// the set while staying non-empty re-emits ON so the vote reason
    /// reflects the new contents. Idempotent — no-op if the watched set
    /// hasn't actually changed, and a no-op when the trigger is stopped
    /// (the next `start()` will read fresh data from settings anyway).
    public func reevaluateWatched() {
        guard observation != nil else { return }
        let newWatched = Set(settings.appTriggerBundleIDs)
        if newWatched == watchedSet { return }
        watchedSet = newWatched

        let prevMatching = matchingRunning
        matchingRunning = Set(source.runningBundleIDs).intersection(watchedSet)

        if prevMatching.isEmpty && !matchingRunning.isEmpty {
            emitOn()
        } else if !prevMatching.isEmpty && matchingRunning.isEmpty {
            continuation.yield(TriggerVote(wantsAwake: false, reason: "App: no watched apps running"))
        } else if prevMatching != matchingRunning && !matchingRunning.isEmpty {
            emitOn()
        }
    }

    private func handleLaunch(bundleID: String) {
        guard watchedSet.contains(bundleID) else { return }
        let wasEmpty = matchingRunning.isEmpty
        matchingRunning.insert(bundleID)
        if wasEmpty { emitOn() }
    }

    private func handleTerminate(bundleID: String) {
        guard watchedSet.contains(bundleID) else { return }
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
    var pickableRunningBundleIDs: [String] { [] }
    func isInstalled(_ bundleID: String) -> Bool { false }
    func displayInfo(for bundleID: String) -> AppDisplayInfo? {
        AppTriggerDefaults.displayName(for: bundleID).map {
            AppDisplayInfo(bundleID: bundleID, displayName: $0)
        }
    }
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

    /// Explicit display-info overrides keyed by bundle ID. When set, takes
    /// priority over `AppTriggerDefaults.displayName(for:)` fallback.
    public var displayInfoLookup: [String: AppDisplayInfo] = [:]

    /// Explicit pickable-list override. When `nil`, defaults to
    /// `runningBundleIDs` (test-friendly default — every running app is
    /// pickable unless explicitly filtered).
    public var pickableOverride: [String]?

    /// Explicit installed-set override. When `nil`, defaults to treating the
    /// union of `runningBundleIDs` and `displayInfoLookup` keys as installed.
    public var installedOverride: Set<String>?

    public init(runningBundleIDs: [String] = []) {
        self.runningBundleIDs = runningBundleIDs
    }

    public var pickableRunningBundleIDs: [String] {
        pickableOverride ?? runningBundleIDs
    }

    public func isInstalled(_ bundleID: String) -> Bool {
        if let installed = installedOverride { return installed.contains(bundleID) }
        if runningBundleIDs.contains(bundleID) { return true }
        if displayInfoLookup[bundleID] != nil { return true }
        return false
    }

    public func displayInfo(for bundleID: String) -> AppDisplayInfo? {
        if let override = displayInfoLookup[bundleID] { return override }
        if let curated = AppTriggerDefaults.displayName(for: bundleID) {
            return AppDisplayInfo(bundleID: bundleID, displayName: curated)
        }
        return nil
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

    /// Friendly fallback names for the curated default IDs. Used when the
    /// system has no live or installed-bundle metadata to draw from (e.g. a
    /// curated default app the user hasn't installed yet).
    private static let displayNames: [String: String] = [
        "us.zoom.xos": "Zoom",
        "com.microsoft.teams2": "Microsoft Teams",
        "com.cisco.webex.meetings": "Webex",
        "com.hnc.Discord": "Discord",
        "com.tinyspeck.slackmacgap": "Slack",
        "com.google.Chrome.helper.meet": "Google Meet"
    ]

    public static func displayName(for bundleID: String) -> String? {
        displayNames[bundleID]
    }

    /// SF Symbol fallback when neither a running-app icon nor a bundle icon
    /// can be resolved. Categorized by app function so the row at least
    /// communicates *what kind of app* it is when the icon is missing.
    private static let symbolHints: [String: String] = [
        "us.zoom.xos":                    "video.fill",
        "com.microsoft.teams2":           "video.fill",
        "com.cisco.webex.meetings":       "video.fill",
        "com.google.Chrome.helper.meet":  "video.fill",
        "com.hnc.Discord":                "bubble.left.and.bubble.right.fill",
        "com.tinyspeck.slackmacgap":      "bubble.left.and.bubble.right.fill"
    ]

    public static func symbolHint(for bundleID: String) -> String? {
        symbolHints[bundleID]
    }

    /// Subset of `bundleIDs` that resolve to installed apps on this system.
    /// Used by `AppTrigger.init` to seed the watched list at first launch,
    /// so a user with none of the curated defaults installed gets an empty
    /// list (with friendly empty-state copy) rather than a list of apps
    /// they don't have.
    @MainActor
    public static func installedDefaults(in source: WorkspaceSource) -> [String] {
        bundleIDs.filter { source.isInstalled($0) }
    }

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
    /// User's watched bundle ID list. The seeding mechanism (see
    /// `AppTrigger.init` / `AppTriggerDefaults.installedDefaults(in:)`)
    /// populates this on first launch with the curated defaults that are
    /// actually installed on the user's machine; subsequently it stores
    /// exactly whatever the user (or migration code) writes. There is no
    /// implicit fallback — an empty list means "watch nothing."
    var appTriggerBundleIDs: [String] {
        get {
            AppTriggerDefaults.sanitize(decodeStringArray(.appTriggerBundleIDs))
        }
        set {
            encodeStringArray(AppTriggerDefaults.sanitize(newValue), for: .appTriggerBundleIDs)
        }
    }
}
