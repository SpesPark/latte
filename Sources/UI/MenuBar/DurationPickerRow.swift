import SwiftUI

public struct DurationPickerRow: View {

    public let duration: AwakeDuration
    public let isActive: Bool
    public let action: () -> Void

    @EnvironmentObject private var environment: AppEnvironment
    @State private var isHovered: Bool = false

    public init(duration: AwakeDuration, isActive: Bool, action: @escaping () -> Void) {
        self.duration = duration
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        let accent = environment.coffeeAccent.color
        return Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                // S23 / P-issue-3: layout-only spacer reserving 3pt for the
                // active stripe drawn via `.overlay` below. The previous
                // `Rectangle().fill(isActive ? accent : Color.clear)` child
                // never rendered visibly on this row even when isActive=true
                // (only the right-side checkmark appeared). Decoupling stripe
                // drawing from HStack layout via an overlay sidesteps the
                // SwiftUI quirk and matches the reliable pattern across all
                // three popover row types.
                Color.clear.frame(width: 3)

                Text(duration.label)
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
    }
}
