import XCTest
import CoreLocation
@testable import Latte

/// Pins `CoreWLANSource`'s CLAuthorizationStatus → TriggerPermissionStatus
/// mapping, including the forward-compatibility path for
/// `.authorizedWhenInUse` (raw value 4). That case is API_UNAVAILABLE(macos)
/// in the current SDK so it cannot be named in a switch — but the source
/// requests When-In-Use authorization, so if a future macOS starts returning
/// it, a user who granted access must be classified as granted, not
/// not-determined (S51 T5 follow-up).
@MainActor
final class CoreWLANSourceAuthorizationTests: XCTestCase {

    private final class StubLocationManager: CLLocationManager {
        var stubbedStatus: CLAuthorizationStatus = .notDetermined
        var requestWhenInUseCallCount = 0
        override var authorizationStatus: CLAuthorizationStatus { stubbedStatus }
        override func requestWhenInUseAuthorization() { requestWhenInUseCallCount += 1 }
    }

    /// `kCLAuthorizationStatusAuthorizedWhenInUse` from the shared
    /// CoreLocation header — unavailable as a Swift case on macOS today.
    private let authorizedWhenInUse = CLAuthorizationStatus(rawValue: 4)!

    private func makeSource() -> (CoreWLANSource, StubLocationManager) {
        let stub = StubLocationManager()
        let source = CoreWLANSource(locationManager: stub)
        return (source, stub)
    }

    // MARK: - permissionStatus mapping

    func testAuthorizedAlwaysMapsToGranted() {
        let (source, stub) = makeSource()
        stub.stubbedStatus = .authorizedAlways
        XCTAssertEqual(source.permissionStatus, .granted)
    }

    func testDeniedMapsToDenied() {
        let (source, stub) = makeSource()
        stub.stubbedStatus = .denied
        XCTAssertEqual(source.permissionStatus, .denied)
    }

    func testNotDeterminedMapsToNotDetermined() {
        let (source, stub) = makeSource()
        stub.stubbedStatus = .notDetermined
        XCTAssertEqual(source.permissionStatus, .notDetermined)
    }

    func testFutureAuthorizedWhenInUseMapsToGranted() {
        let (source, stub) = makeSource()
        stub.stubbedStatus = authorizedWhenInUse
        XCTAssertEqual(source.permissionStatus, .granted)
    }

    // MARK: - requestAccess via delegate callback

    func testDelegateAuthorizedAlwaysResolvesRequestTrue() async {
        let (source, stub) = makeSource()
        let task = Task { await source.requestAccess() }
        for _ in 0..<1_000 where stub.requestWhenInUseCallCount == 0 {
            await Task.yield()
        }
        XCTAssertEqual(stub.requestWhenInUseCallCount, 1)

        source.locationManager(stub, didChangeAuthorization: .authorizedAlways)
        let granted = await task.value
        XCTAssertTrue(granted)
    }

    func testDelegateFutureAuthorizedWhenInUseResolvesRequestTrue() async {
        let (source, stub) = makeSource()
        let task = Task { await source.requestAccess() }
        for _ in 0..<1_000 where stub.requestWhenInUseCallCount == 0 {
            await Task.yield()
        }
        XCTAssertEqual(stub.requestWhenInUseCallCount, 1)

        source.locationManager(stub, didChangeAuthorization: authorizedWhenInUse)
        let granted = await task.value
        XCTAssertTrue(granted)
    }

    func testDelegateDeniedResolvesRequestFalse() async {
        let (source, stub) = makeSource()
        let task = Task { await source.requestAccess() }
        for _ in 0..<1_000 where stub.requestWhenInUseCallCount == 0 {
            await Task.yield()
        }

        source.locationManager(stub, didChangeAuthorization: .denied)
        let granted = await task.value
        XCTAssertFalse(granted)
    }
}
