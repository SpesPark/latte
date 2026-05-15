import SwiftUI

public struct HeaderView: View {

    @ObservedObject public var manager: AwakeManager
    @EnvironmentObject public var environment: AppEnvironment

    public init(manager: AwakeManager) {
        self.manager = manager
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            CoffeeCupView(
                isAwake: manager.isAwake,
                fillRatio: 0.8,
                liquidColor: environment.coffeeAccent.color
            )
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(Theme.Fonts.header)
                Text(statusSubtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    private var statusTitle: String {
        if manager.isAwake { return String(localized: "Latte is awake") }
        return String(localized: "Latte is off")
    }

    private var statusSubtitle: String {
        // **S22 / P-issue-5b**: every "Until X" / "Until you turn off"
        // branch is gated on `isAwake == true` first. The `.snoozed` state
        // (entered on `.userDeactivate` from `.awakeTriggered`, e.g. user
        // clicks Turn off while AppTrigger is voting ON) carries
        // `activeReason = .user` + `endsAt = now+5min` even though
        // `isAwake == false` — without this gate, the header lied that
        // "Until 12:27 AM" is an awake deadline when it's actually a
        // snooze deadline against an empty cup. Same lie surfaced when
        // pause-all routed through `.userDeactivate` before P-issue-5
        // landed; this gate keeps us correct even if a future caller
        // re-introduces a similar path.
        switch manager.activeReason {
        case .user:
            if manager.isAwake {
                if let endsAt = manager.endsAt {
                    let time = Self.timeFormatter.string(from: endsAt)
                    return String(localized: "Until \(time)")
                }
                return String(localized: "Until you turn off")
            }
            return String(localized: "Tap the cup to wake your Mac")
        case .trigger(let id):
            return String(localized: "Awake — \(id)")
        case .launch:
            return String(localized: "Activated at launch")
        case .none:
            return String(localized: "Tap the cup to wake your Mac")
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}
