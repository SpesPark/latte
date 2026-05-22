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
@MainActor
public final class IOPowerSource: PowerSourceType {

    private let logger = LatteLog.powerSource
    private var runLoopSource: CFRunLoopSource?
    private var observers: [UUID: @MainActor (Bool) -> Void] = [:]

    public init() {}

    public var isOnAC: Bool {
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

    public func observe(
        onChange: @escaping @MainActor (Bool) -> Void
    ) -> PowerSourceObservation {
        let token = UUID()
        observers[token] = onChange

        if runLoopSource == nil {
            // Single shared run-loop source; we fan out to all observers.
            let context = Unmanaged.passUnretained(self).toOpaque()
            let source = IOPSNotificationCreateRunLoopSource(
                { ctx in
                    guard let ctx else { return }
                    let me = Unmanaged<IOPowerSource>.fromOpaque(ctx).takeUnretainedValue()
                    Task { @MainActor in me.fanOut() }
                },
                context
            )?.takeRetainedValue()
            if let source {
                runLoopSource = source
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            } else {
                logger.error("IOPSNotificationCreateRunLoopSource returned nil; AC observation disabled")
            }
        }

        return PowerSourceObservation { [weak self] in
            guard let self else { return }
            self.observers.removeValue(forKey: token)
            if self.observers.isEmpty, let src = self.runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .defaultMode)
                self.runLoopSource = nil
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
