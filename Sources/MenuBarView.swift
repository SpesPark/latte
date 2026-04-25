import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var awake: AwakeManager
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.vertical, 8)
            durationList
            Divider().padding(.vertical, 8)
            footer
        }
        .padding(12)
        .frame(width: 280)
    }

    private var header: some View {
        HStack(spacing: 12) {
            CoffeeCupView(isActive: awake.isAwake)
            VStack(alignment: .leading, spacing: 2) {
                Text(awake.isAwake ? "Caffeinated" : "Sleeping allowed")
                    .font(.headline)
                if let endsAt = awake.endsAt {
                    Text("Until \(endsAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if awake.isAwake {
                    Text("Indefinitely")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap a duration to keep awake")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle(
                "",
                isOn: Binding(
                    get: { awake.isAwake },
                    set: { _ in awake.toggle() }
                )
            )
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var durationList: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Keep awake for")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            ForEach(AwakeDuration.presets) { duration in
                durationRow(duration)
            }
        }
    }

    private func durationRow(_ duration: AwakeDuration) -> some View {
        Button {
            awake.activate(for: duration)
        } label: {
            HStack {
                Image(systemName: duration.symbol)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text(duration.label)
                Spacer()
                if awake.activeDuration == duration {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(awake.activeDuration == duration ? Color.accentColor.opacity(0.12) : .clear)
        )
    }

    private var footer: some View {
        HStack {
            Button {
                openSettings()
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
        }
        .font(.callout)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AwakeManager.shared)
}
