import AppKit
import SwiftUI

public struct MenuBarRoot: View {

    @ObservedObject public var manager: AwakeManager
    @EnvironmentObject private var environment: AppEnvironment

    @State private var customExpanded: Bool = false
    @State private var customMinutes: Int = 60

    public init(manager: AwakeManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 0) {
            HeaderView(manager: manager)

            Divider().opacity(0.5)

            pauseTriggersRow

            Divider().opacity(0.5)

            VStack(spacing: 0) {
                ForEach(AwakeDuration.presets, id: \.label) { duration in
                    DurationPickerRow(
                        duration: duration,
                        isActive: manager.activeDuration == duration && manager.isAwake,
                        action: { manager.activate(for: duration) }
                    )
                }
                CustomDurationRow(
                    isExpanded: $customExpanded,
                    minutes: $customMinutes,
                    isActive: manager.isAwake && isUnlistedCustomDuration(manager.activeDuration),
                    onStart: {
                        manager.activate(for: .minutes(customMinutes))
                    }
                )
            }
            .padding(.vertical, 2)

            Divider().opacity(0.5)

            // C-7 wall-clock target presets — seed-then-mutable model
            // (S19 #2). The three legacy rows (until 5 PM / 11 PM /
            // midnight) seed once into `recurringQuickPresets` at first
            // launch and become editable like any user preset. Filtered
            // by today's weekday — Mon-Fri preset never shows Saturday.
            // Click → minutes-from-now → activate(.minutes(N)).
            // Owner-cleared → empty section, popover stays clean.
            let activePresets = environment.recurringQuickPresets
                .filter { $0.isActiveOn(date: .now) }
            if !activePresets.isEmpty {
                VStack(spacing: 0) {
                    ForEach(activePresets) { preset in
                        RecurringQuickPresetRow(
                            preset: preset,
                            action: {
                                let mins = preset.minutes(from: .now)
                                manager.activate(for: .minutes(mins))
                            }
                        )
                    }
                }
                .padding(.vertical, 2)

                Divider().opacity(0.5)
            }

            Button(role: .destructive, action: { manager.deactivate() }) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 13))
                        .frame(width: 16)
                    Text("Turn off")
                        .font(Theme.Fonts.body)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!manager.isAwake)
            .opacity(manager.isAwake ? 1.0 : 0.45)

            Divider().opacity(0.5)

            // S22 / P-issue-4: `.keyboardShortcut(",", modifiers: .command)` /
            // `.keyboardShortcut("q", modifiers: .command)` were attempted
            // here so ⌘, / ⌘Q would dismiss-and-act from the popover, but
            // owner-confirmed they don't fire in the LSUIElement /
            // .accessory NSStatusItem popover context — the popover's
            // window doesn't appear to enter the SwiftUI responder chain
            // for keyEquivalent dispatch even when key. Owner deferred as
            // non-critical; mouse click still works. Revisit if Apple
            // changes popover focus handling in a future macOS, or
            // migrate to a NSEvent local monitor on popover-show if
            // explicitly requested.
            HStack {
                Button(action: openSettings) {
                    Text("Settings…")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: { NSApp.terminate(nil) }) {
                    Text("Quit")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .font(Theme.Fonts.caption)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .frame(width: Theme.Sizes.menuBarWidth)
        .liquidGlassBackground()
    }

    @ViewBuilder
    private var pauseTriggersRow: some View {
        Toggle(isOn: $manager.triggersPaused) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: manager.triggersPaused ? "pause.circle.fill" : "pause.circle")
                    .font(.system(size: 13))
                    .frame(width: 16)
                    .foregroundStyle(manager.triggersPaused ? environment.coffeeAccent.color : .secondary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(manager.triggersPaused ? "Triggers paused" : "Pause triggers")
                        .font(Theme.Fonts.body)
                    Text(manager.triggersPaused
                         ? "Manual activation still works."
                         : "Ignore Calendar / App / Wi\u{2011}Fi / Schedule votes.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityIdentifier("menubar.pauseTriggers")
    }

    private func isUnlistedCustomDuration(_ d: AwakeDuration?) -> Bool {
        guard let d else { return false }
        return !AwakeDuration.presets.contains(d)
    }

    private func openSettings() {
        SettingsWindowController.shared.show(
            manager: environment.manager,
            coordinator: environment.coordinator,
            environment: environment
        )
    }
}
