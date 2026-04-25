import SwiftUI

public struct HeaderView: View {

    @ObservedObject public var manager: AwakeManager
    @EnvironmentObject public var environment: AppEnvironment

    public init(manager: AwakeManager) {
        self.manager = manager
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            CoffeeCupView(
                isAwake: manager.isAwake,
                fillRatio: 0.8,
                liquidColor: environment.coffeeAccent.color
            )
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(Theme.Fonts.header)
                Text(statusSubtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    private var statusTitle: String {
        if manager.isAwake { return "Latte is awake" }
        return "Latte is off"
    }

    private var statusSubtitle: String {
        switch manager.activeReason {
        case .user:
            if let endsAt = manager.endsAt {
                return "Until \(Self.timeFormatter.string(from: endsAt))"
            }
            return manager.isAwake ? "Until you turn off" : "Tap to wake"
        case .trigger(let id):
            return "Awake — \(id)"
        case .launch:
            return "Activated on launch"
        case .none:
            return "Tap the cup to wake your Mac"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}
