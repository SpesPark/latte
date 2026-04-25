import XCTest
@testable import Latte

/// Direct tests for the IOKit-backed `PowerAssertion`.
///
/// `IOPMAssertionCreateWithName` is a public IOKit API that requires no
/// entitlement and works in any macOS process, so the live adapter can be
/// exercised directly from a unit test. Per `02-architecture.md` §13, this
/// keeps coverage above the 80% gate without faking IOKit.
final class PowerAssertionTests: XCTestCase {

    func testInitialStateIsInactive() {
        let assertion = PowerAssertion()
        XCTAssertFalse(assertion.isActive)
        XCTAssertNil(assertion.currentMode)
    }

    func testIOKitTypeKeyDistinguishesModes() {
        let displayKey = PowerAssertionMode.displayAndSystem.iokitTypeKey
        let systemKey = PowerAssertionMode.systemOnly.iokitTypeKey
        XCTAssertNotEqual(displayKey as String, systemKey as String)
    }

    func testActivateThenDeactivateReleasesAssertion() {
        let assertion = PowerAssertion()
        let ok = assertion.activate(mode: .displayAndSystem, reason: "unit test")
        XCTAssertTrue(ok)
        XCTAssertTrue(assertion.isActive)
        XCTAssertEqual(assertion.currentMode, .displayAndSystem)

        assertion.deactivate()
        XCTAssertFalse(assertion.isActive)
        XCTAssertNil(assertion.currentMode)
    }

    func testActivateWithSameModeIsIdempotent() {
        let assertion = PowerAssertion()
        XCTAssertTrue(assertion.activate(mode: .systemOnly, reason: "first"))
        XCTAssertTrue(assertion.activate(mode: .systemOnly, reason: "second"))
        XCTAssertTrue(assertion.isActive)
        XCTAssertEqual(assertion.currentMode, .systemOnly)
        assertion.deactivate()
    }

    func testActivateChangingModeReplacesAssertion() {
        let assertion = PowerAssertion()
        XCTAssertTrue(assertion.activate(mode: .displayAndSystem, reason: "display"))
        XCTAssertEqual(assertion.currentMode, .displayAndSystem)
        XCTAssertTrue(assertion.activate(mode: .systemOnly, reason: "system"))
        XCTAssertEqual(assertion.currentMode, .systemOnly)
        XCTAssertTrue(assertion.isActive)
        assertion.deactivate()
    }

    func testDeactivateWhenInactiveIsNoOp() {
        let assertion = PowerAssertion()
        assertion.deactivate()
        XCTAssertFalse(assertion.isActive)
    }
}
