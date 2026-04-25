import SwiftUI

public struct CoffeeCupView: View {

    public let isAwake: Bool
    public let fillRatio: Double

    public init(isAwake: Bool, fillRatio: Double = 1.0) {
        self.isAwake = isAwake
        self.fillRatio = max(0, min(1, fillRatio))
    }

    public var body: some View {
        ZStack {
            cup
            liquid
        }
        .frame(width: Theme.Sizes.cupView, height: Theme.Sizes.cupView)
        .accessibilityLabel(isAwake ? "Latte awake" : "Latte asleep")
    }

    private var cup: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.large)
            .stroke(Theme.Colors.coffee, lineWidth: 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large)
                    .fill(Theme.Colors.cup)
            )
    }

    @ViewBuilder
    private var liquid: some View {
        if isAwake {
            GeometryReader { geo in
                let height = geo.size.height * fillRatio
                Rectangle()
                    .fill(Theme.Colors.coffee)
                    .frame(height: height)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
                    .padding(2)
            }
        } else {
            EmptyView()
        }
    }
}
