import SwiftUI

public struct TriggersTab: View {

    @ObservedObject public var coordinator: TriggerCoordinator

    public init(coordinator: TriggerCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Form {
            Section {
                ForEach(Array(coordinator.triggers.enumerated()), id: \.offset) { _, trigger in
                    TriggerRow(
                        trigger: trigger,
                        activeVote: coordinator.activeVotes[trigger.id]
                    )
                }
            } header: {
                Text("Automatic triggers").font(Theme.Fonts.subheadline)
            } footer: {
                Text("Enable a trigger to let Latte wake your Mac automatically. Per-trigger configuration (calendar pickers, app pickers, SSID lists) lands in a future update.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct TriggerRow: View {

    let trigger: any Trigger
    let activeVote: TriggerVote?
    @State private var isOn: Bool
    @EnvironmentObject private var environment: AppEnvironment

    init(trigger: any Trigger, activeVote: TriggerVote?) {
        self.trigger = trigger
        self.activeVote = activeVote
        self._isOn = State(initialValue: trigger.isEnabled)
    }

    var body: some View {
        let accent = environment.coffeeAccent.color
        return HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: trigger.symbol)
                .frame(width: 22)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(trigger.displayName)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.primary)
                if let reason = subtitle {
                    Text(reason)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(isVoting ? accent : .secondary)
                        .accessibilityIdentifier("trigger.row.subtitle.\(trigger.id)")
                }
            }

            Spacer()

            if isVoting {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("\(trigger.displayName) is currently voting awake")
            }

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { newValue in
                    trigger.isEnabled = newValue
                }
        }
    }

    private var isVoting: Bool {
        activeVote?.wantsAwake == true
    }

    private var subtitle: String? {
        if let reason = activeVote?.reason, !reason.isEmpty {
            return "Voting awake — \(reason)"
        }
        if !trigger.isEnabled {
            return "Disabled"
        }
        switch trigger.permissionStatus {
        case .denied:       return "Permission denied — open System Settings"
        case .notDetermined: return "Permission not yet requested"
        case .granted:      return "Idle"
        case .notRequired:  return "Idle"
        }
    }

}
