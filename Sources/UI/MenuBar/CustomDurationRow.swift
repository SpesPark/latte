import SwiftUI

/// Inline custom-duration row. Collapsed: shows "Custom…" with a chevron.
/// Expanded: shows a minute Stepper (1–1440) and a "Start" button.
///
/// Distinct component (rather than a flag on `DurationPickerRow`) because
/// the expand/collapse state and Start action are local to this row.
public struct CustomDurationRow: View {

    @Binding var isExpanded: Bool
    @Binding var minutes: Int
    let isActive: Bool
    let onStart: () -> Void

    @EnvironmentObject private var environment: AppEnvironment
    @State private var isHovered: Bool = false

    public init(
        isExpanded: Binding<Bool>,
        minutes: Binding<Int>,
        isActive: Bool,
        onStart: @escaping () -> Void
    ) {
        self._isExpanded = isExpanded
        self._minutes = minutes
        self.isActive = isActive
        self.onStart = onStart
    }

    public var body: some View {
        let accent = environment.coffeeAccent.color
        return VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: Theme.Spacing.sm) {
                    // S23 / P-issue-3: stripe drawn via `.overlay` below.
                    // See `DurationPickerRow` for rationale.
                    Color.clear.frame(width: 3)

                    Text("Custom…")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(isActive ? .primary : .secondary)

                    Spacer()

                    if isActive {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                            .padding(.trailing, 6)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
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

            if isExpanded {
                HStack(spacing: Theme.Spacing.sm) {
                    Stepper(value: $minutes, in: 1...1440, step: 5) {
                        HStack(spacing: 4) {
                            Text("\(minutes)")
                                .font(Theme.Fonts.body.monospacedDigit())
                                .frame(minWidth: 36, alignment: .trailing)
                            Text(minutes == 1 ? "min" : "min")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Button(action: {
                        onStart()
                        isExpanded = false
                    }) {
                        Text("Start")
                            .font(Theme.Fonts.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }
}
