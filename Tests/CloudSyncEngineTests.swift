import XCTest
@testable import Latte

@MainActor
final class CloudSyncEngineTests: XCTestCase {

    // MARK: - Mock engine

    /// Scriptable `CloudSyncEngine` spy. Records lifecycle calls and models
    /// the §8 "iCloud account unavailable → sync stays off" degradation via
    /// `accountAvailable`. No CloudKit — the seam is pure (RFC §10).
    @MainActor
    final class MockCloudSyncEngine: CloudSyncEngine {
        private(set) var isRunning = false
        private(set) var startCallCount = 0
        private(set) var stopCallCount = 0
        /// When false, `start()` records the call but leaves `isRunning` false,
        /// simulating a signed-out account / unavailable container.
        var accountAvailable = true

        func start() async {
            startCallCount += 1
            if accountAvailable { isRunning = true }
        }

        func stop() async {
            stopCallCount += 1
            isRunning = false
        }
    }

    // MARK: - Lifecycle contract

    func testInitialStateIsNotRunning() {
        let engine = MockCloudSyncEngine()
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.startCallCount, 0)
        XCTAssertEqual(engine.stopCallCount, 0)
    }

    func testStartBringsEngineUpWhenAccountAvailable() async {
        let engine = MockCloudSyncEngine()
        await engine.start()
        XCTAssertTrue(engine.isRunning)
        XCTAssertEqual(engine.startCallCount, 1)
    }

    func testStartIsNoOpWhenAccountUnavailable() async {
        let engine = MockCloudSyncEngine()
        engine.accountAvailable = false
        await engine.start()
        XCTAssertFalse(engine.isRunning,
                       "Unavailable account must leave sync off, not block")
        XCTAssertEqual(engine.startCallCount, 1,
                       "The call is still observed even when it no-ops")
    }

    func testStopTearsDownAndIsIdempotent() async {
        let engine = MockCloudSyncEngine()
        await engine.start()
        XCTAssertTrue(engine.isRunning)
        await engine.stop()
        XCTAssertFalse(engine.isRunning)
        await engine.stop()
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.stopCallCount, 2)
    }
}
