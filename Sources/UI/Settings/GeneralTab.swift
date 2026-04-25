import SwiftUI

public struct GeneralTab: View {

    @ObservedObject public var manager: AwakeManager
    @EnvironmentObject public var environment: AppEnvironment

    public init(manager: AwakeManager) {
        self.manager = manager
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Allow display to sleep", isOn: $manager.allowDisplaySleep)
                    .help("When enabled, the system stays awake but the display may sleep.")
            } header: {
                Text("Behavior").font(Theme.Fonts.subheadline)
            }

            Section {
                Picker(selection: $environment.menuBarIconStyle) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Label {
                            Text(style.displayName).font(Theme.Fonts.body)
                        } icon: {
                            Image(systemName: style.symbolName)
                        }
                        .tag(style)
                    }
                } label: {
                    Text("Menu bar icon").font(Theme.Fonts.body)
                }
                .pickerStyle(.menu)
            } header: {
                Text("Appearance").font(Theme.Fonts.subheadline)
            } footer: {
                Text("The icon updates immediately. SF Symbols adapt to the system tint and dark mode automatically.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(manager.isAwake ? Theme.Colors.accentAwake : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(manager.isAwake ? "Awake" : "Asleep")
                            .font(Theme.Fonts.body)
                            .foregroundStyle(manager.isAwake ? Color.primary : .secondary)
                    }
                } label: {
                    Text("State").font(Theme.Fonts.body)
                }
                if let endsAt = manager.endsAt {
                    LabeledContent {
                        Text(endsAt, style: .time).font(Theme.Fonts.caption)
                    } label: {
                        Text("Until").font(Theme.Fonts.body)
                    }
                }
            } header: {
                Text("Status").font(Theme.Fonts.subheadline)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
