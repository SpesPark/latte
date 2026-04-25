import SwiftUI

public struct AboutTab: View {

    public init() {}

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer(minLength: Theme.Spacing.lg)

            VStack(spacing: Theme.Spacing.md) {
                CoffeeCupView(isAwake: true, fillRatio: 0.9)
                    .frame(width: 80, height: 80)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("Latte")
                        .font(Theme.Fonts.title)
                        .foregroundStyle(.primary)
                    Text(version)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Keep your Mac awake when it matters.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .liquidGlassCard()

            Spacer()

            Text("© 2026 Latte. All rights reserved.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }
}
