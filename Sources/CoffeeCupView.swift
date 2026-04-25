import SwiftUI

/// Animated coffee cup icon for the menu bar window header.
///
/// Package C: emits steam particles when active, settles into a calm cup when idle.
/// Designed to scale gracefully on macOS 13+; Liquid Glass treatment is layered
/// in `LiquidGlassModifier` (macOS 26+) without breaking the fallback.
struct CoffeeCupView: View {
    let isActive: Bool

    @State private var steamPhase: Double = 0
    @State private var pulse: Double = 0

    var body: some View {
        ZStack {
            backgroundCircle
            steamParticles
            cupGlyph
        }
        .frame(width: 44, height: 44)
        .onAppear {
            if isActive { startAnimations() }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue { startAnimations() }
        }
    }

    private var backgroundCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: isActive
                        ? [Color.brown.opacity(0.25), Color.orange.opacity(0.15)]
                        : [Color.gray.opacity(0.15), Color.gray.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(isActive ? 1.0 + pulse * 0.05 : 1.0)
    }

    private var cupGlyph: some View {
        Image(systemName: isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(isActive ? Color.brown : Color.secondary)
            .symbolRenderingMode(.hierarchical)
    }

    @ViewBuilder
    private var steamParticles: some View {
        if isActive {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(Color.brown.opacity(0.25))
                        .frame(width: 3, height: 8)
                        .offset(
                            x: CGFloat(i - 1) * 5,
                            y: -16 - CGFloat(steamPhase) * 8
                        )
                        .opacity(1.0 - steamPhase)
                        .blur(radius: 1)
                        .animation(
                            .easeOut(duration: 1.6)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.4),
                            value: steamPhase
                        )
                }
            }
        }
    }

    private func startAnimations() {
        steamPhase = 1
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulse = 1
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        CoffeeCupView(isActive: true)
        CoffeeCupView(isActive: false)
    }
    .padding()
}
