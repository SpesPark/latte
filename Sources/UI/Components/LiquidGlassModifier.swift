import SwiftUI

public struct LiquidGlassBackground: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.background(.regularMaterial)
        } else {
            content.background(.ultraThinMaterial)
        }
    }
}

public extension View {
    func liquidGlassBackground() -> some View {
        modifier(LiquidGlassBackground())
    }
}
