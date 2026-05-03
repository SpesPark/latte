import SwiftUI

/// Popover row for a user-defined recurring preset (C-7 v1.7). Visually
/// matches `QuickPresetRow` so users perceive built-in and custom presets
/// as one cohesive section.
///
/// **S23 / P-issue-2**: now mirrors `DurationPickerRow`'s active-marker UI
/// (left accent stripe + right checkmark) so a preset-driven awake session
/// shows the marker on the matching row instead of leaking onto the
/// Custom row. Driven by `AwakeManager.activeRecurringPresetID`.
public struct RecurringQuickPresetRow: View {

    public let preset: RecurringQuickPreset
    public let isActive: Bool
    public let action: () -> Void

    @EnvironmentObject private var environment: AppEnvironment
    @State private var isHovered: Bool = false

    public init(preset: RecurringQuickPreset, isActive: Bool = false, action: @escaping () -> Void) {
        self.preset = preset
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        let accent = environment.coffeeAccent.color
        return Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                // S23 / P-issue-3: stripe drawn via `.overlay` below.
                // See `DurationPickerRow` for rationale (HStack-child
                // `Rectangle` was unreliable across the three popover row
                // types).
                Color.clear.frame(width: 3)

                Text(preset.label)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(isActive ? .primary : .secondary)

                Spacer()

                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg - 3)
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    .padding(.horizontal, Theme.Spacing.sm)
            )
            .overlay(alignment: .leading) {
                if isActive {
                    Capsule(style: .continuous)
                        .fill(accent)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                        .padding(.leading, Theme.Spacing.lg - 3)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityIdentifier("popover.recurringPreset.\(preset.id.uuidString)")
    }
}
