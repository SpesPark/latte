import SwiftUI

public struct GeneralTab: View {

    @ObservedObject public var manager: AwakeManager
    @EnvironmentObject public var environment: AppEnvironment

    public init(manager: AwakeManager) {
        self.manager = manager
    }

    @ViewBuilder
    private var launchAtLoginToggle: some View {
        // Bridge the environment-owned coordinator into a local binding so
        // SwiftUI dispatches updates without traversing through the
        // environment's let-bound stored property.
        Toggle(
            "Launch at login",
            isOn: Binding(
                get: { environment.launchAtLogin.isEnabled },
                set: { environment.launchAtLogin.isEnabled = $0 }
            )
        )
        .help("Latte starts automatically when you sign in to your Mac. Recommended for set-and-forget use.")
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Allow display to sleep", isOn: $manager.allowDisplaySleep)
                    .help("When enabled, the system stays awake but the display may sleep.")
                launchAtLoginToggle
            } header: {
                Text("Behavior").font(Theme.Fonts.subheadline)
            }

            Section {
                LabeledContent {
                    CoffeeCupView(
                        isAwake: true,
                        fillRatio: 0.85,
                        liquidColor: environment.coffeeAccent.color
                    )
                    .frame(width: 36, height: 36)
                } label: {
                    Text("Preview").font(Theme.Fonts.body)
                }

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

                Picker(selection: $environment.coffeeAccent) {
                    ForEach(CoffeeAccent.allCases) { accent in
                        HStack(spacing: Theme.Spacing.sm) {
                            Circle()
                                .fill(accent.color)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                            Text(accent.displayName).font(Theme.Fonts.body)
                            Spacer(minLength: 0)
                            Text(accent.shortDescription)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(accent)
                    }
                } label: {
                    Text("Coffee tone").font(Theme.Fonts.body)
                }
                .pickerStyle(.menu)
            } header: {
                Text("Appearance").font(Theme.Fonts.subheadline)
            } footer: {
                Text("The icon and accent color update immediately. SF Symbols adapt to the system tint and dark mode automatically.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(manager.isAwake ? environment.coffeeAccent.color : Color.secondary)
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
