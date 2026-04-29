import SwiftUI

public struct AboutTab: View {

    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject private var manager: AwakeManager
    @ObservedObject private var coordinator: TriggerCoordinator

    public init(
        manager: AwakeManager,
        coordinator: TriggerCoordinator
    ) {
        self.manager = manager
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer(minLength: Theme.Spacing.lg)

            VStack(spacing: Theme.Spacing.md) {
                CoffeeCupView(
                    isAwake: manager.isAwake,
                    fillRatio: 0.9,
                    liquidColor: environment.coffeeAccent.color
                )
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

            statusCard

            Spacer()

            Text("© 2026 Latte. All rights reserved.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status card (A-1: surfaces active assertion + reason + power)

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            statusRow(
                label: "State",
                value: AssertionStatusFormatter.stateLabel(isAwake: manager.isAwake),
                emphasised: manager.isAwake
            )
            if let mode = AssertionStatusFormatter.modeLabel(
                isAwake: manager.isAwake,
                allowDisplaySleep: manager.allowDisplaySleep
            ) {
                statusRow(label: "Mode", value: mode)
            }
            statusRow(
                label: "Reason",
                value: AssertionStatusFormatter.reasonLabel(
                    manager.activeReason,
                    triggerReason: latestTriggerVoteReason
                )
            )
            if let power = AssertionStatusFormatter.powerLabel(
                isOnAC: manager.isOnAC,
                requireACForAwake: manager.requireACForAwake
            ) {
                statusRow(label: "Power", value: power)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard()
    }

    private func statusRow(label: String, value: String, emphasised: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(Theme.Fonts.body)
                .foregroundStyle(emphasised ? environment.coffeeAccent.color : .primary)
            Spacer(minLength: 0)
        }
    }

    /// Most recent `wantsAwake = true` vote reason from the coordinator's
    /// active votes, used to enrich the "Reason" line when an explicit
    /// trigger is driving awake. `nil` when no trigger vote is active.
    private var latestTriggerVoteReason: String? {
        coordinator.activeVotes.values
            .first(where: { $0.wantsAwake && !$0.reason.isEmpty })?.reason
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }
}
