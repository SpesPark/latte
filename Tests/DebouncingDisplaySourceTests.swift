import XCTest
@testable import Latte

@MainActor
final class DebouncingDisplaySourceTests: XCTestCase {

    func testBurstOfYieldsCollapsesIntoSingleDownstreamYield() async throws {
        let upstream = MockDisplaySource(externalDisplayCount: 1, firstExternalDisplayName: "DELL")
        let debouncer = DebouncingDisplaySource(wrapping: upstream, debounceInterval: 0.1)

        // Iterate downstream from a task and count emissions over a window
        // long enough to cover the debounce + a small slack margin.
        let collected = Task { @MainActor () -> Int in
            var n = 0
            var it = debouncer.changeStream.makeAsyncIterator()
            for _ in 0..<10 {
                if Task.isCancelled { break }
                // Only count real yields. A cancelled iterator returns nil
                // — that's the loop's exit signal, not a forwarded event.
                guard await it.next() != nil else { break }
                n += 1
            }
            return n
        }

        // Fire a 5-event burst within the debounce window.
        for _ in 0..<5 { upstream.emitChange() }

        try await Task.sleep(nanoseconds: 250_000_000)   // 250ms — past debounce
        collected.cancel()
        let count = await collected.value
        XCTAssertEqual(count, 1, "5 rapid upstream yields must collapse into 1 downstream yield")
    }

    func testTwoBurstsSeparatedByMoreThanDebounceForwardTwoYields() async throws {
        let upstream = MockDisplaySource()
        let debouncer = DebouncingDisplaySource(wrapping: upstream, debounceInterval: 0.05)

        let collected = Task { @MainActor () -> Int in
            var n = 0
            var it = debouncer.changeStream.makeAsyncIterator()
            for _ in 0..<10 {
                if Task.isCancelled { break }
                // Only count real yields. A cancelled iterator returns nil
                // — that's the loop's exit signal, not a forwarded event.
                guard await it.next() != nil else { break }
                n += 1
            }
            return n
        }

        upstream.emitChange()
        try await Task.sleep(nanoseconds: 100_000_000)   // > 50ms → 1st yield arrives
        upstream.emitChange()
        try await Task.sleep(nanoseconds: 100_000_000)   // > 50ms → 2nd yield arrives

        collected.cancel()
        let count = await collected.value
        XCTAssertEqual(count, 2, "non-overlapping bursts must each produce a yield")
    }

    func testProxiesUpstreamCountAndName() {
        let upstream = MockDisplaySource(externalDisplayCount: 2, firstExternalDisplayName: "DELL U2723QE")
        let debouncer = DebouncingDisplaySource(wrapping: upstream, debounceInterval: 0.3)
        XCTAssertEqual(debouncer.externalDisplayCount, 2)
        XCTAssertEqual(debouncer.firstExternalDisplayName, "DELL U2723QE")
    }
}
