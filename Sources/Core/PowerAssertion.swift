import Foundation
import IOKit.pwr_mgt
import os

public enum PowerAssertionMode: Equatable, Sendable {
    case displayAndSystem
    case systemOnly

    var iokitTypeKey: CFString {
        switch self {
        case .displayAndSystem: return kIOPMAssertionTypeNoDisplaySleep as CFString
        case .systemOnly: return kIOPMAssertionTypeNoIdleSleep as CFString
        }
    }
}

public protocol PowerAssertionType: AnyObject {
    var isActive: Bool { get }
    var currentMode: PowerAssertionMode? { get }

    @discardableResult
    func activate(mode: PowerAssertionMode, reason: String) -> Bool
    func deactivate()
}

public final class PowerAssertion: PowerAssertionType {

    private let logger = Logger(subsystem: "com.parkbyeongjun.latte", category: "power")
    private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
    private var active = false
    private var mode: PowerAssertionMode?

    public init() {}

    public var isActive: Bool { active }
    public var currentMode: PowerAssertionMode? { mode }

    @discardableResult
    public func activate(mode: PowerAssertionMode, reason: String) -> Bool {
        if active {
            if mode == self.mode { return true }
            deactivate()
        }
        var newID = IOPMAssertionID(0)
        let status = IOPMAssertionCreateWithName(
            mode.iokitTypeKey,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newID
        )
        guard status == kIOReturnSuccess else {
            logger.error("Failed to create power assertion: \(status, privacy: .public)")
            return false
        }
        assertionID = newID
        active = true
        self.mode = mode
        logger.info("Power assertion activated (mode=\(String(describing: mode), privacy: .public))")
        return true
    }

    public func deactivate() {
        guard active else { return }
        let status = IOPMAssertionRelease(assertionID)
        if status != kIOReturnSuccess {
            logger.error("Failed to release power assertion: \(status, privacy: .public)")
        }
        assertionID = IOPMAssertionID(0)
        active = false
        mode = nil
        logger.info("Power assertion released")
    }

    deinit {
        if active {
            IOPMAssertionRelease(assertionID)
        }
    }
}

public final class MockPowerAssertion: PowerAssertionType {
    public private(set) var activations: [(mode: PowerAssertionMode, reason: String)] = []
    public private(set) var deactivationCount = 0
    public private(set) var active = false
    public private(set) var mode: PowerAssertionMode?

    /// When true, the next `activate` reports failure and leaves the
    /// assertion inactive — mirrors `IOPMAssertionCreateWithName` returning
    /// non-success, so tests can exercise the acquisition-failure path.
    public var failNextActivate = false

    public init() {}

    public var isActive: Bool { active }
    public var currentMode: PowerAssertionMode? { mode }

    @discardableResult
    public func activate(mode: PowerAssertionMode, reason: String) -> Bool {
        activations.append((mode, reason))
        if failNextActivate {
            failNextActivate = false
            return false
        }
        active = true
        self.mode = mode
        return true
    }

    public func deactivate() {
        guard active else { return }
        deactivationCount += 1
        active = false
        mode = nil
    }
}
