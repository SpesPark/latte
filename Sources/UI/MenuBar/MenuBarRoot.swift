import SwiftUI

public struct MenuBarRoot: View {

    @ObservedObject public var manager: AwakeManager
    @Environment(\.openSettings) private var openSettings

    public init(manager: AwakeManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 0) {
            HeaderView(manager: manager)
            Divider()

            ForEach(AwakeDuration.presets, id: \.label) { duration in
                DurationPickerRow(
                    duration: duration,
                    isActive: manager.activeDuration == duration && manager.isAwake,
                    action: { manager.activate(for: duration) }
                )
            }

            Divider()

            Button(role: .destructive, action: { manager.deactivate() }) {
                HStack {
                    Image(systemName: "stop.circle")
                    Text("Turn off")
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!manager.isAwake)

            Divider()

            HStack {
                Button("Settings…") { openSettings() }
                    .buttonStyle(.plain)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
            }
            .font(Theme.Fonts.caption)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .frame(width: Theme.Sizes.menuBarWidth)
        .liquidGlassBackground()
    }
}
