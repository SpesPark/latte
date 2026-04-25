import XCTest
import CoreGraphics
@testable import Latte

final class CoffeeCupGeometryTests: XCTestCase {

    private let size = CGSize(width: 64, height: 64)

    // MARK: - Body / handle layout

    func testBodyRectIsContainedWithinSize() {
        let g = CoffeeCupGeometry(size: size)
        XCTAssertGreaterThanOrEqual(g.bodyRect.minX, 0)
        XCTAssertGreaterThanOrEqual(g.bodyRect.minY, 0)
        XCTAssertLessThanOrEqual(g.bodyRect.maxX, size.width)
        XCTAssertLessThanOrEqual(g.bodyRect.maxY, size.height)
    }

    func testBodyRectLeavesRoomAboveForSteam() {
        let g = CoffeeCupGeometry(size: size)
        XCTAssertGreaterThan(g.bodyRect.minY, size.height * 0.20,
                             "Cup top should sit below the upper third so steam has space")
    }

    func testHandleStartsAndEndsOnRightEdge() {
        let g = CoffeeCupGeometry(size: size)
        XCTAssertEqual(g.handleStart.x, g.bodyRect.maxX, accuracy: 0.001)
        XCTAssertEqual(g.handleEnd.x, g.bodyRect.maxX, accuracy: 0.001)
    }

    func testHandleControlsBulgeOutward() {
        let g = CoffeeCupGeometry(size: size)
        XCTAssertGreaterThan(g.handleControl1.x, g.bodyRect.maxX)
        XCTAssertGreaterThan(g.handleControl2.x, g.bodyRect.maxX)
    }

    func testStrokeWidthScalesWithSize() {
        let small = CoffeeCupGeometry(size: CGSize(width: 24, height: 24))
        let large = CoffeeCupGeometry(size: CGSize(width: 200, height: 200))
        XCTAssertLessThan(small.strokeWidth, large.strokeWidth)
        XCTAssertGreaterThanOrEqual(small.strokeWidth, 1.0,
                                     "Should not collapse below 1pt at small sizes")
    }

    // MARK: - Liquid

    func testLiquidRectFullFillsBodyMinusInset() {
        let g = CoffeeCupGeometry(size: size)
        let liquid = g.liquidRect(fillRatio: 1.0)
        XCTAssertGreaterThan(liquid.height, 0)
        XCTAssertLessThanOrEqual(liquid.maxY, g.bodyRect.maxY)
        XCTAssertGreaterThanOrEqual(liquid.minX, g.bodyRect.minX)
    }

    func testLiquidRectZeroForZeroFillRatio() {
        let g = CoffeeCupGeometry(size: size)
        XCTAssertEqual(g.liquidRect(fillRatio: 0).height, 0, accuracy: 0.001)
    }

    func testLiquidRectClampsAboveOne() {
        let g = CoffeeCupGeometry(size: size)
        let full = g.liquidRect(fillRatio: 1.0)
        let over = g.liquidRect(fillRatio: 5.0)
        XCTAssertEqual(over.height, full.height, accuracy: 0.001)
    }

    func testLiquidRectClampsBelowZero() {
        let g = CoffeeCupGeometry(size: size)
        XCTAssertEqual(g.liquidRect(fillRatio: -1).height, 0, accuracy: 0.001)
    }

    func testLiquidGrowsFromTheBottom() {
        let g = CoffeeCupGeometry(size: size)
        let half = g.liquidRect(fillRatio: 0.5)
        let full = g.liquidRect(fillRatio: 1.0)
        XCTAssertEqual(half.maxY, full.maxY, accuracy: 0.001,
                       "Both should anchor to the bottom of the cup body")
        XCTAssertGreaterThan(half.minY, full.minY,
                             "Half-fill should start lower than full fill")
    }

    // MARK: - Steam particles

    func testSteamFramesProduceOnePerParticle() {
        let g = CoffeeCupGeometry(size: size)
        let frames = CoffeeCupGeometry.steamFrames(time: 0, geometry: g)
        XCTAssertEqual(frames.count, CoffeeCupGeometry.particles.count)
    }

    func testSteamFramesAreDeterministicForSameTime() {
        let g = CoffeeCupGeometry(size: size)
        let a = CoffeeCupGeometry.steamFrames(time: 1.234, geometry: g)
        let b = CoffeeCupGeometry.steamFrames(time: 1.234, geometry: g)
        XCTAssertEqual(a, b)
    }

    func testSteamPeriodicityRepeats() {
        let g = CoffeeCupGeometry(size: size)
        let t: TimeInterval = 1.0
        let a = CoffeeCupGeometry.steamFrames(time: t, geometry: g)
        let b = CoffeeCupGeometry.steamFrames(
            time: t + CoffeeCupGeometry.steamPeriod,
            geometry: g
        )
        for (lhs, rhs) in zip(a, b) {
            XCTAssertEqual(lhs.center.x, rhs.center.x, accuracy: 0.001)
            XCTAssertEqual(lhs.center.y, rhs.center.y, accuracy: 0.001)
            XCTAssertEqual(lhs.radius, rhs.radius, accuracy: 0.001)
            XCTAssertEqual(lhs.opacity, rhs.opacity, accuracy: 0.001)
        }
    }

    func testSteamRisesUpwardOverTime() {
        let g = CoffeeCupGeometry(size: size)
        let particle = CoffeeCupGeometry.particles[0]
        // Find two times where this particle is still in its rising phase
        // (phase 0 → 0.5).
        let t0: TimeInterval = -particle.phaseOffset * CoffeeCupGeometry.steamPeriod + 0.05
        let t1: TimeInterval = t0 + 0.5
        let f0 = CoffeeCupGeometry.steamFrames(time: t0, geometry: g)[0]
        let f1 = CoffeeCupGeometry.steamFrames(time: t1, geometry: g)[0]
        XCTAssertLessThan(f1.center.y, f0.center.y,
                          "Rising particles should have a smaller Y over time (Canvas Y goes downward)")
    }

    func testSteamFadesAsItRises() {
        let g = CoffeeCupGeometry(size: size)
        let particle = CoffeeCupGeometry.particles[0]
        let t0: TimeInterval = -particle.phaseOffset * CoffeeCupGeometry.steamPeriod + 0.05
        let t1: TimeInterval = t0 + 0.8
        let f0 = CoffeeCupGeometry.steamFrames(time: t0, geometry: g)[0]
        let f1 = CoffeeCupGeometry.steamFrames(time: t1, geometry: g)[0]
        XCTAssertGreaterThan(f0.opacity, f1.opacity)
    }

    func testSteamOpacityNeverNegative() {
        let g = CoffeeCupGeometry(size: size)
        for t in stride(from: 0.0, to: 5.0, by: 0.05) {
            let frames = CoffeeCupGeometry.steamFrames(time: t, geometry: g)
            for f in frames {
                XCTAssertGreaterThanOrEqual(f.opacity, 0.0)
                XCTAssertLessThanOrEqual(f.opacity, 1.0)
            }
        }
    }

    func testSteamCentersStayWithinHorizontalDriftBudget() {
        let g = CoffeeCupGeometry(size: size)
        let cupCenter = g.bodyRect.midX
        let maxOffset: CGFloat = 7 + 5  // largest horizontal offset + largest drift amplitude
        for t in stride(from: 0.0, to: 5.0, by: 0.1) {
            let frames = CoffeeCupGeometry.steamFrames(time: t, geometry: g)
            for f in frames {
                XCTAssertLessThanOrEqual(abs(f.center.x - cupCenter), maxOffset + 0.01)
            }
        }
    }
}
