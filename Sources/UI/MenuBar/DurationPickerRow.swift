import SwiftUI

public struct DurationPickerRow: View {

    public let duration: AwakeDuration
    public let isActive: Bool
    public let action: () -> Void

    public init(duration: AwakeDuration, isActive: Bool, action: @escaping () -> Void) {
        self.duration = duration
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Text(duration.label)
                    .font(Theme.Fonts.body)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.Colors.accentAwake)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
