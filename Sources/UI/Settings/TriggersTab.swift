import SwiftUI

public struct TriggersTab: View {

    @ObservedObject public var coordinator: TriggerCoordinator
    @EnvironmentObject private var environment: AppEnvironment

    public init(coordinator: TriggerCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Form {
            ForEach(coordinator.triggers, id: \.id) { trigger in
                TriggerSection(
                    trigger: trigger,
                    coordinator: coordinator,
                    activeVote: coordinator.activeVotes[trigger.id]
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - TriggerSection (one Section per trigger)

private struct TriggerSection: View {

    let trigger: any Trigger
    let coordinator: TriggerCoordinator
    let activeVote: TriggerVote?
    @State private var isOn: Bool
    @EnvironmentObject private var environment: AppEnvironment

    init(trigger: any Trigger, coordinator: TriggerCoordinator, activeVote: TriggerVote?) {
        self.trigger = trigger
        self.coordinator = coordinator
        self.activeVote = activeVote
        self._isOn = State(initialValue: trigger.isEnabled)
    }

    var body: some View {
        Section {
            Toggle("Enable", isOn: $isOn)
                .onChange(of: isOn) { newValue in
                    trigger.isEnabled = newValue
                    Task { @MainActor in
                        if newValue {
                            // S8b smoke owner-feedback fix: Toggle ON
                            // must request permission the same way
                            // bootTriggers() does on launch. Without
                            // this, enabling Calendar/WiFi/Focus from
                            // Settings would silently fail — pollOnce()
                            // returns early when permission isn't
                            // granted, no prompt fires, cup never
                            // activates, user blames the app.
                            if trigger.requiresPermission {
                                _ = await trigger.requestPermissionIfNeeded()
                            }
                            await coordinator.start(trigger)
                        } else {
                            coordinator.stop(trigger.id)
                        }
                    }
                }

            if isOn {
                configBody
            }
        } header: {
            sectionHeader
        } footer: {
            sectionFooter
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: trigger.symbol)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(trigger.displayName)
                .font(Theme.Fonts.subheadline)
            Spacer()
            if isVoting {
                Circle()
                    .fill(environment.coffeeAccent.color)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("\(trigger.displayName) is currently voting awake")
            }
        }
    }

    @ViewBuilder
    private var sectionFooter: some View {
        if let reason = activeVote?.reason, isVoting, !reason.isEmpty {
            Text("Voting awake — \(reason)")
                .font(Theme.Fonts.caption)
                .foregroundStyle(environment.coffeeAccent.color)
                .accessibilityIdentifier("trigger.row.subtitle.\(trigger.id)")
        } else if isOn {
            switch trigger.permissionStatus {
            case .denied:
                Text("Permission denied. Grant access in System Settings → Privacy & Security.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("trigger.row.subtitle.\(trigger.id)")
            case .notDetermined:
                Text("Permission will be requested the first time the trigger fires.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("trigger.row.subtitle.\(trigger.id)")
            case .granted, .notRequired:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var configBody: some View {
        switch trigger.id {
        case "app":
            if let app = trigger as? AppTrigger {
                AppTriggerConfigForm(trigger: app, settings: environment.settings)
            }
        case "wifi":
            if let wifi = trigger as? WiFiTrigger {
                WiFiTriggerConfigForm(trigger: wifi, settings: environment.settings)
            }
        case "calendar":
            if let calendar = trigger as? CalendarTrigger {
                CalendarTriggerConfigForm(
                    trigger: calendar,
                    settings: environment.settings
                )
            }
        case "focus":
            FocusTriggerConfigInfo()
        case "schedule":
            if let schedule = trigger as? ScheduleTrigger {
                ScheduleTriggerConfigForm(
                    trigger: schedule,
                    settings: environment.settings
                )
            }
        case "external-display":
            if let display = trigger as? ExternalDisplayTrigger {
                ExternalDisplayTriggerConfigForm(trigger: display)
            }
        default:
            EmptyView()
        }
    }

    private var isVoting: Bool { activeVote?.wantsAwake == true }
}

