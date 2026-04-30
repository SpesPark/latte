import SwiftUI

/// Wall-clock target row for the popover ("Until 5 PM" etc — C-7 Path A).
/// Distinct from `DurationPickerRow` so the checkmark logic stays simple
/// (no preset row ever shows active — the FSM holds `.minutes(N)` after
/// click, which `CustomDurationRow.isUnlistedCustomDuration` will catch).
public struct QuickPresetRow: View {

    public let preset: QuickPreset
    public let action: () -> Void

    @State private var isHovered: Bool = false

    public init(preset: QuickPreset, action: @escaping () -> Void) {
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
        .accessibilityIdentifier("popover.quickPreset.\(preset.rawValue)")
    }
}
