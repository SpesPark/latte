import SwiftUI

/// A `Canvas`-rendered coffee cup with steam particles, used in the menu bar
/// header and the About tab. The view is driven by a `TimelineView` so it
/// runs at the requested 60 fps when `isAwake == true` and is paused otherwise.
///
/// Visual states:
/// - awake: full opacity, liquid fills the cup body, steam particles drift up.
/// - asleep: dimmed (opacity 0.55), no liquid, no steam.
///
/// The geometry, particle layout, and per-frame opacity are computed by the
/// pure `CoffeeCupGeometry` helpers so they can be unit-tested without a
/// running `Canvas`.
public struct CoffeeCupView: View {

    public let isAwake: Bool
    public let fillRatio: Double
    public let liquidColor: Color

    public init(isAwake: Bool, fillRatio: Double = 1.0, liquidColor: Color = CoffeeAccent.default.color) {
        self.isAwake = isAwake
        self.fillRatio = max(0, min(1, fillRatio))
        self.liquidColor = liquidColor
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isAwake)) { context in
            Canvas { ctx, size in
                var ctx = ctx
                let geometry = CoffeeCupGeometry(size: size)

                drawCup(in: &ctx, geometry: geometry)
                if isAwake {
                    drawLiquid(in: &ctx, geometry: geometry, fillRatio: fillRatio)
                    let time = context.date.timeIntervalSinceReferenceDate
                    let frames = CoffeeCupGeometry.steamFrames(time: time, geometry: geometry)
                    for frame in frames {
                        let rect = CGRect(
                            x: frame.center.x - frame.radius,
                            y: frame.center.y - frame.radius,
                            width: frame.radius * 2,
                            height: frame.radius * 2
                        )
                        ctx.fill(
                            Path(ellipseIn: rect),
                            with: .color(Theme.Colors.foam.opacity(frame.opacity))
                        )
                    }
                }
            }
            .opacity(isAwake ? 1.0 : 0.55)
        }
        .frame(width: Theme.Sizes.cupView, height: Theme.Sizes.cupView)
        .accessibilityLabel(isAwake ? "Latte awake" : "Latte asleep")
    }

    private func drawCup(in ctx: inout GraphicsContext, geometry: CoffeeCupGeometry) {
        let strokeColor = Theme.Colors.cupStroke
        let body = Path(roundedRect: geometry.bodyRect, cornerSize: geometry.bodyCornerSize)
        ctx.fill(body, with: .color(Theme.Colors.cup))
        ctx.stroke(body, with: .color(strokeColor), lineWidth: geometry.strokeWidth)

        var handle = Path()
        handle.move(to: geometry.handleStart)
        handle.addCurve(
            to: geometry.handleEnd,
            control1: geometry.handleControl1,
            control2: geometry.handleControl2
        )
        ctx.stroke(handle, with: .color(strokeColor), lineWidth: geometry.strokeWidth)
    }

    private func drawLiquid(
        in ctx: inout GraphicsContext,
        geometry: CoffeeCupGeometry,
        fillRatio: Double
    ) {
        let liquidRect = geometry.liquidRect(fillRatio: fillRatio)
        guard liquidRect.height > 0.5 else { return }

        let liquid = Path(roundedRect: liquidRect, cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(liquid, with: .color(liquidColor))

        if fillRatio > 0.05 {
            var foam = Path()
            foam.move(to: CGPoint(x: liquidRect.minX, y: liquidRect.minY + 1))
            foam.addLine(to: CGPoint(x: liquidRect.maxX, y: liquidRect.minY + 1))
            ctx.stroke(foam, with: .color(Theme.Colors.foam.opacity(0.7)), lineWidth: 1)
        }
    }
}

// MARK: - Geometry (pure, testable)

/// Pure geometric layout for `CoffeeCupView`. Computed once per frame; no
/// dependency on `Canvas` or `TimelineView`. All helpers are unit-tested.
public struct CoffeeCupGeometry: Equatable, Sendable {

    public let size: CGSize
    public let bodyRect: CGRect
    public let bodyCornerSize: CGSize
    public let strokeWidth: CGFloat
    public let handleStart: CGPoint
    public let handleEnd: CGPoint
    public let handleControl1: CGPoint
    public let handleControl2: CGPoint

    public init(size: CGSize) {
        self.size = size
        let bodyOriginX = size.width * 0.18
        let bodyOriginY = size.height * 0.35
        let bodyWidth = size.width * 0.55
        let bodyHeight = size.height * 0.55
        let body = CGRect(x: bodyOriginX, y: bodyOriginY, width: bodyWidth, height: bodyHeight)
        self.bodyRect = body
        self.bodyCornerSize = CGSize(width: 6, height: 6)
        self.strokeWidth = max(1.0, size.width * 0.025)

        let hx = body.maxX
        let h1 = CGPoint(x: hx, y: body.minY + body.height * 0.20)
        let h2 = CGPoint(x: hx, y: body.minY + body.height * 0.60)
        let bulge = size.width * 0.18
        self.handleStart = h1
        self.handleEnd = h2
        self.handleControl1 = CGPoint(x: hx + bulge, y: h1.y)
        self.handleControl2 = CGPoint(x: hx + bulge, y: h2.y)
    }

    /// Inner liquid rect, given a fill ratio in `0...1`.
    public func liquidRect(fillRatio: Double) -> CGRect {
        let clamped = max(0, min(1, fillRatio))
        let inset: CGFloat = 2.5
        let inner = bodyRect.insetBy(dx: inset, dy: inset)
        let liquidHeight = inner.height * CGFloat(clamped)
        return CGRect(
            x: inner.minX,
            y: inner.maxY - liquidHeight,
            width: inner.width,
            height: liquidHeight
        )
    }

    // MARK: Steam particles

    /// Per-particle constant layout. The actual rendered position and opacity
    /// are derived per-frame in `steamFrames(time:geometry:)`.
    public struct SteamParticle: Equatable, Sendable {
        public let horizontalOffset: CGFloat
        public let phaseOffset: Double
        public let driftAmplitude: CGFloat
    }

    /// Three particles staggered evenly across one period so the steam never
    /// looks empty. Phase offsets are deterministic — the animation is a
    /// pure function of wall-clock time.
    public static let particles: [SteamParticle] = [
        SteamParticle(horizontalOffset: -7, phaseOffset: 0.00, driftAmplitude: 3.5),
        SteamParticle(horizontalOffset:  0, phaseOffset: 0.40, driftAmplitude: -4.5),
        SteamParticle(horizontalOffset:  7, phaseOffset: 0.75, driftAmplitude: 4.0)
    ]

    /// Period of one full rise-and-fade cycle.
    public static let steamPeriod: TimeInterval = 2.4

    /// One particle's frame-state at a given time and layout.
    public struct SteamParticleFrame: Equatable, Sendable {
        public let center: CGPoint
        public let radius: CGFloat
        public let opacity: Double
    }

    public static func steamFrames(time: TimeInterval, geometry: CoffeeCupGeometry) -> [SteamParticleFrame] {
        let cupTopY = geometry.bodyRect.minY
        let cupCenterX = geometry.bodyRect.midX
        let baseRadius = max(CGFloat(2.5), geometry.size.width * 0.045)

        return particles.map { particle in
            var phase = (time / steamPeriod + particle.phaseOffset)
                .truncatingRemainder(dividingBy: 1.0)
            if phase < 0 { phase += 1.0 }
            let progress = CGFloat(phase)
            let y = cupTopY - progress * cupTopY
            let drift = particle.driftAmplitude * CGFloat(sin(phase * 2.0 * .pi))
            let x = cupCenterX + particle.horizontalOffset + drift
            let radius = baseRadius * (0.7 + progress * 0.6)
            let opacity = max(0.0, (1.0 - Double(progress)) * 0.55)
            return SteamParticleFrame(
                center: CGPoint(x: x, y: y),
                radius: radius,
                opacity: opacity
            )
        }
    }
}
