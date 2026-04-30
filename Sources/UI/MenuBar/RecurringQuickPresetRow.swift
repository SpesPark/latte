import SwiftUI

/// Popover row for a user-defined recurring preset (C-7 v1.7). Visually
/// matches `QuickPresetRow` so users perceive built-in and custom presets
/// as one cohesive section. No checkmark logic — FSM holds `.minutes(N)`
/// after click, same trade-off as the built-in QuickPreset rows.
public struct RecurringQuickPresetRow: View {

    public let preset: RecurringQuickPreset
    public let action: () -> Void

    @State private var isHovered: Bool = false

    public init(preset: RecurringQuickPreset, action: @escaping () -> Void) {
        self.preset = preset
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 3)
                    .padding(.vertical, 4)

                Text(preset.label)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg - 3)
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    .padding(.horizontal, Theme.Spacing.sm)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityIdentifier("popover.recurringPreset.\(preset.id.uuidString)")
    }
}
