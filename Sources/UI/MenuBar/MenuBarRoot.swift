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
