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
                Rectangle()
                    .fill(isActive ? accent : Color.clear)
                    .frame(width: 3)
                    .padding(.vertical, 4)

                Text(duration.label)
                    .font(Theme.Fonts.body)

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
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
