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

    @ViewBuilder
    private var activateOnLaunchToggle: some View {
        // Persisted via environment.activateOnLaunch (didSet writes through
        // to SettingsStore). Takes effect on the *next* app start — flipping
        // the toggle while already running does not auto-awake the current
        // session. See `AppEnvironment.applyActivateOnLaunchIfEnabled()`.
        Toggle(
            "Activate at launch",
            isOn: $environment.activateOnLaunch
        )
        .help("When Latte starts, immediately hold an indefinite awake assertion. Useful for desktops or always-on workstations. Onboarding always takes precedence on first launch.")
    }

    @ViewBuilder
    private var keyboardShortcutToggle: some View {
        // Bridge through environment.keyboardShortcut.isEnabled so toggling
        // also (un)registers the system-wide hotkey via the coordinator's
        // didSet — pure UserDefaults mirroring would not flip the OS-level
        // registration state. The label binds to the live `coordinator.chord`
        // so the glyph updates instantly when the user customises it.
        Toggle(
            "Toggle Latte with \(environment.keyboardShortcut.chord.glyph)",
            isOn: Binding(
                get: { environment.keyboardShortcut.isEnabled },
                set: { environment.keyboardShortcut.isEnabled = $0 }
            )
        )
        .help("Globally toggle Latte awake/asleep with \(environment.keyboardShortcut.chord.glyph). Click the recorder below to assign a different chord.")
    }

    @ViewBuilder
    private var shortcutRecorderRow: some View {
        // Recorder field — only meaningful while the toggle above is enabled,
        // but we keep it visible regardless so users can stage a chord before
        // flipping the toggle on.
        LabeledContent {
            ShortcutRecorderField(coordinator: environment.keyboardShortcut)
        } label: {
            Text("Shortcut").font(Theme.Fonts.body)
        }
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Allow display to sleep", isOn: $manager.allowDisplaySleep)
                    .help("When enabled, the system stays awake but the display may sleep.")
                Toggle("Sleep when on battery", isOn: $manager.requireACForAwake)
                    .help("When enabled, Latte never holds an awake assertion while the Mac is on battery — saves battery on laptops without disabling the app.")
                if manager.requireACForAwake && !manager.isOnAC {
                    Text("Currently on battery — Latte is not holding awake.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                launchAtLoginToggle
                activateOnLaunchToggle
                keyboardShortcutToggle
                shortcutRecorderRow
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
