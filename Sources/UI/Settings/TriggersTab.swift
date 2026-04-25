import SwiftUI

public struct TriggersTab: View {

    @ObservedObject public var coordinator: TriggerCoordinator

    public init(coordinator: TriggerCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Form {
            Section("Automatic triggers") {
                ForEach(Array(coordinator.triggers.enumerated()), id: \.offset) { _, trigger in
                    TriggerRow(trigger: trigger)
                }
            }
            Section {
                Text("Trigger integrations land in Phase 1.A. Real Calendar/App/Wi-Fi/Focus wiring arrives in session 4.")
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
    @State private var isOn: Bool

    init(trigger: any Trigger) {
        self.trigger = trigger
        self._isOn = State(initialValue: trigger.isEnabled)
    }

    var body: some View {
        HStack {
            Image(systemName: trigger.symbol)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            Text(trigger.displayName)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { newValue in
                    trigger.isEnabled = newValue
                }
        }
    }
}
