import Foundation
import IOKit.pwr_mgt
import os.log

/// Wraps macOS `IOPMAssertion` to keep the Mac awake.
///
/// Two modes are supported:
/// - `.displayAndSystem` (default) — prevents both display and system sleep
/// - `.systemOnly` — allows display to sleep but keeps the system running
///
/// Caller owns the lifecycle: call `activate(...)` once, then `deactivate()` to release.
final class PowerAssertion {
    enum Mode {
        case displayAndSystem
        case systemOnly

        var assertionType: CFString {
            switch self {
            case .displayAndSystem: return kIOPMAssertionTypeNoDisplaySleep as CFString
            case .systemOnly: return kIOPMAssertionTypeNoIdleSleep as CFString
            }
        }
    }

    private static let logger = Logger(subsystem: "com.example.caffeinated", category: "PowerAssertion")

    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false
    private(set) var currentMode: Mode?

    @discardableResult
    func activate(mode: Mode = .displayAndSystem,
                  reason: String = "Caffeinated keeping Mac awake") -> Bool {
        if isActive {
            if currentMode == mode { return true }
            deactivate()
        }
        let result = IOPMAssertionCreateWithName(
            mode.assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        let success = result == kIOReturnSuccess
        if success {
            isActive = true
            currentMode = mode
            Self.logger.info("PowerAssertion activated (mode: \(String(describing: mode)))")
        } else {
            Self.logger.error("PowerAssertion activation failed: IOReturn=\(result)")
        }
        return success
    }

    func deactivate() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
        currentMode = nil
        Self.logger.info("PowerAssertion deactivated")
    }

    deinit {
        deactivate()
    }
}
