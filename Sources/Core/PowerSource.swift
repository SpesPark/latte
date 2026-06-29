import Foundation
#if canImport(IOKit)
import IOKit
import IOKit.ps
#endif
import os

// MARK: - PowerSourceType

/// Abstracts the macOS battery / AC-power query so `AwakeManager` can be
/// tested without IOKit. Mirrors the `*Source` DI pattern used by other
/// triggers (see 02-architecture.md §4.4.1).
@MainActor
public protocol PowerSourceType: AnyObject {
    /// Whether the Mac is currently drawing from AC power (charger plugged in).
    /// On a desktop without a battery, this returns `true` (no battery present
    /// is treated as "always on AC" so battery-aware gating doesn't break
    /// non-laptop installs).
    var isOnAC: Bool { get }

    /// Subscribe to AC-state changes. Callback fires on the main actor with
    /// the new `isOnAC` value whenever a power-source change is detected.
    /// Returns a cancellation handle. Production uses
    /// `IOPSNotificationCreateRunLoopSource`; mocks emit synthetic events.
    func observe(
        onChange: @escaping @MainActor (Bool) -> Void
    ) -> PowerSourceObservation
}

public final class PowerSourceObservation {
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

// MARK: - Real IOKit-backed source

#if canImport(IOKit)
/// Installs a system hook that calls `onSignal` (on the main actor) whenever the
/// OS reports a power-source change, returning a teardown closure (or `nil` if
/// the hook could not be created). Injected into `IOPowerSource` so tests drive
/// the real fan-out path without a live IOKit `CFRunLoopSource` in the test
/// process — same DI seam the S52 sleeper uses for `AwakeManager`'s timer.
public typealias PowerChangeNotifier =
    @MainActor (_ onSignal: @escaping @MainActor () -> Void) -> (@MainActor () -> Void)?

@MainActor
public final class IOPowerSource: PowerSourceType {

    private let logger = LatteLog.powerSource
    private let readSnapshot: @MainActor () -> Bool
    private let installNotifier: PowerChangeNotifier
    private var teardownNotifier: (@MainActor () -> Void)?
    private var observers: [UUID: @MainActor (Bool) -> Void] = [:]

    /// Production defaults read real IOKit; tests inject `snapshot`/`notifier`
    /// to exercise the observer registry + fan-out + lifecycle deterministically.
    public init(
        snapshot: @escaping @MainActor () -> Bool = IOPowerSource.systemIsOnAC,
        notifier: @escaping PowerChangeNotifier = IOPowerSource.systemNotifier
    ) {
        self.readSnapshot = snapshot
        self.installNotifier = notifier
    }

    public var isOnAC: Bool { readSnapshot() }

    public func observe(
        onChange: @escaping @MainActor (Bool) -> Void
    ) -> PowerSourceObservation {
        let token = UUID()
        observers[token] = onChange

        if teardownNotifier == nil {
            // Single shared notifier; we fan out to all observers.
            teardownNotifier = installNotifier { [weak self] in
                self?.fanOut()
            }
            if teardownNotifier == nil {
                logger.error("power-change notifier unavailable; AC observation disabled")
            }
        }

        return PowerSourceObservation { [weak self] in
            guard let self else { return }
            self.observers.removeValue(forKey: token)
            if self.observers.isEmpty {
                self.teardownNotifier?()
                self.teardownNotifier = nil
            }
        }
    }

    private func fanOut() {
        let snapshot = isOnAC
        // Copy before iterating: a callback may cancel its observation,
        // which removes a key from `observers` mid-enumeration.
        for callback in Array(observers.values) {
            callback(snapshot)
        }
    }

    // MARK: Production IOKit defaults

    /// Reads AC state from IOKit. On a desktop without a battery (no info /
    /// empty source list) returns `true` — "always on AC" — so battery-aware
    /// gating doesn't break non-laptop installs.
    public static func systemIsOnAC() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return true // No info → assume desktop / always-on. Don't gate.
        }
        guard
            let sourcesArray = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return true
        }
        if sourcesArray.isEmpty { return true } // No battery present.

        for source in sourcesArray {
            guard
                let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                    as? [String: Any],
                let stateValue = info[kIOPSPowerSourceStateKey as String] as? String
            else { continue }
            if stateValue == kIOPSACPowerValue { return true }
        }
        return false
    }

    /// Wraps `IOPSNotificationCreateRunLoopSource`. The C callback is not
    /// actor-isolated, so it boxes `onSignal` as the run-loop context and hops
    /// to the main actor before firing. The teardown closure removes the source
    /// and retains the box until then (keeping the context pointer valid).
    public static func systemNotifier(
        _ onSignal: @escaping @MainActor () -> Void
    ) -> (@MainActor () -> Void)? {
        final class CallbackBox {
            let fire: @MainActor () -> Void
            init(_ fire: @escaping @MainActor () -> Void) { self.fire = fire }
        }
        let box = CallbackBox(onSignal)
        let context = Unmanaged.passUnretained(box).toOpaque()
        guard
            let source = IOPSNotificationCreateRunLoopSource(
                { ctx in
                    guard let ctx else { return }
                    let box = Unmanaged<CallbackBox>.fromOpaque(ctx).takeUnretainedValue()
                    Task { @MainActor in box.fire() }
                },
                context
            )?.takeRetainedValue()
        else {
            return nil
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        return {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            _ = box // keep the context box alive until teardown
        }
    }
}
#endif

// MARK: - Mock for tests

@MainActor
public final class MockPowerSource: PowerSourceType {
    public var isOnAC: Bool {
        didSet {
            if isOnAC != oldValue {
                // Copy before iterating: a callback may cancel its
                // observation, mutating `observers` mid-enumeration.
                for cb in Array(observers.values) { cb(isOnAC) }
            }
        }
    }
    private var observers: [UUID: @MainActor (Bool) -> Void] = [:]
    public var observerCount: Int { observers.count }

    public init(isOnAC: Bool = true) {
        self.isOnAC = isOnAC
    }

    public func observe(
        onChange: @escaping @MainActor (Bool) -> Void
    ) -> PowerSourceObservation {
        let token = UUID()
        observers[token] = onChange
        return PowerSourceObservation { [weak self] in
            self?.observers.removeValue(forKey: token)
        }
    }
}
