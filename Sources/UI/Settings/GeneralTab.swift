import SwiftUI

public struct GeneralTab: View {

    @ObservedObject public var manager: AwakeManager

    public init(manager: AwakeManager) {
        self.manager = manager
    }

    public var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Allow display to sleep", isOn: $manager.allowDisplaySleep)
                    .help("When enabled, the system stays awake but the display may sleep.")
            }

            Section("Status") {
                LabeledContent("State") {
                    Text(manager.isAwake ? "Awake" : "Asleep")
                        .foregroundStyle(manager.isAwake ? Theme.Colors.accentAwake : .secondary)
                }
                if let endsAt = manager.endsAt {
                    LabeledContent("Until") {
                        Text(endsAt, style: .time)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
