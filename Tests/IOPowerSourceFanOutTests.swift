import XCTest
@testable import Latte

#if canImport(IOKit)
/// Parity coverage for the *real* `IOPowerSource` fan-out path (B2).
///
/// Before the S52-style seam, `fanOut()` was reachable only from the IOKit
/// run-loop callback, so the production observer registry — multi-observer
/// delivery, copy-before-iterate cancel safety, and the single-shared-notifier
/// lifecycle — had zero coverage; only `MockPowerSource`'s parallel
/// reimplementation was tested. These tests drive the production class with an
/// injected snapshot reader + notifier, so no live `CFRunLoopSource` is created.
@MainActor
final class IOPowerSourceFanOutTests: XCTestCase {

    /// Main-actor reference box — lets the injected (sendable) snapshot/observer
    /// closures share mutable state without tripping Swift 6 "mutated after
    /// capture by sendable closure".
    private final class Ref<T> {
        var value: T
        init(_ value: T) { self.value = value }
    }

    /// Captures the injected `onSignal` so a test can simulate an OS power
    /// change, and counts install/teardown to assert the shared-notifier
    /// lifecycle.
    @MainActor
    private final class FakeNotifier {
        var signal: (@MainActor () -> Void)?
        var installs = 0
        var teardowns = 0

        func make() -> PowerChangeNotifier {
            { [weak self] onSignal in
                guard let self else { return nil }
                self.installs += 1
                self.signal = onSignal
                return { [weak self] in
                    self?.teardowns += 1
                    self?.signal = nil
                }
            }
        }
    }

    func testFanOutDeliversSnapshotToAllObservers() {
        let fake = FakeNotifier()
        let ac = Ref(true)
        let src = IOPowerSource(snapshot: { ac.value }, notifier: fake.make())

        let a = Ref<Bool?>(nil)
        let b = Ref<Bool?>(nil)
        let o1 = src.observe { a.value = $0 }
        let o2 = src.observe { b.value = $0 }

        ac.value = false
        fake.signal?()   // simulate an OS power-source change → fanOut

        XCTAssertEqual(a.value, false)
        XCTAssertEqual(b.value, false, "every observer receives the current snapshot")
        o1.cancel()
        o2.cancel()
    }

    func testObserverCancellingDuringFanOutIsSafe() {
        let fake = FakeNotifier()
        let src = IOPowerSource(snapshot: { false }, notifier: fake.make())

        let received = Ref<[String]>([])
        let o2 = Ref<PowerSourceObservation?>(nil)
        let o1 = src.observe { _ in
            received.value.append("o1")
            o2.value?.cancel()   // cancel a sibling mid-fan-out
        }
        o2.value = src.observe { _ in received.value.append("o2") }

        // Must not crash (copy-before-iterate); both callbacks were in the
        // pre-iteration snapshot, so both fire regardless of dictionary order.
        fake.signal?()

        XCTAssertEqual(received.value.sorted(), ["o1", "o2"])
        o1.cancel()
        o2.value?.cancel()
    }

    func testSingleSharedNotifierTornDownWhenLastObserverLeaves() {
        let fake = FakeNotifier()
        let src = IOPowerSource(snapshot: { true }, notifier: fake.make())

        let o1 = src.observe { _ in }
        let o2 = src.observe { _ in }
        XCTAssertEqual(fake.installs, 1, "one shared notifier serves all observers")

        o1.cancel()
        XCTAssertEqual(fake.teardowns, 0, "notifier stays while any observer remains")

        o2.cancel()
        XCTAssertEqual(fake.teardowns, 1, "notifier torn down once observers empty")
    }

    func testReobservingAfterTeardownReinstallsNotifier() {
        let fake = FakeNotifier()
        let src = IOPowerSource(snapshot: { true }, notifier: fake.make())

        src.observe { _ in }.cancel()   // install then immediately tear down
        XCTAssertEqual(fake.installs, 1)
        XCTAssertEqual(fake.teardowns, 1)

        let o = src.observe { _ in }     // a fresh observer reinstalls
        XCTAssertEqual(fake.installs, 2, "notifier reinstalls after a full teardown")
        o.cancel()
    }
}
#endif
