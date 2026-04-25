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
    let activeVote: TriggerVote?
    @State private var isOn: Bool
    @EnvironmentObject private var environment: AppEnvironment

    init(trigger: any Trigger, activeVote: TriggerVote?) {
        self.trigger = trigger
        self.activeVote = activeVote
        self._isOn = State(initialValue: trigger.isEnabled)
    }

    var body: some View {
        Section {
            Toggle("Enable", isOn: $isOn)
                .onChange(of: isOn) { newValue in
                    trigger.isEnabled = newValue
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
            CalendarTriggerConfigForm(settings: environment.settings)
        case "focus":
            FocusTriggerConfigInfo()
        default:
            EmptyView()
        }
    }

    private var isVoting: Bool { activeVote?.wantsAwake == true }
}

// MARK: - App config form

private struct AppTriggerConfigForm: View {

    let trigger: AppTrigger
    let settings: SettingsStore

    @State private var watched: [String]
    @State private var draftBundleID: String = ""

    init(trigger: AppTrigger, settings: SettingsStore) {
        self.trigger = trigger
        self.settings = settings
        self._watched = State(initialValue: settings.appTriggerBundleIDs)
    }

    var body: some View {
        Group {
            ForEach(watched, id: \.self) { bundleID in
                HStack {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(bundleID)
                        .font(Theme.Fonts.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        remove(bundleID)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(bundleID)")
                }
            }

            if watched.isEmpty {
                Text("No apps configured. The trigger will never fire.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Theme.Spacing.xs) {
                TextField("e.g. us.zoom.xos", text: $draftBundleID)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.Fonts.caption)
                Button("Add") { addCustom() }
                    .disabled(!isDraftValid)
            }

            runningAppsMenu
        }
    }

    private var isDraftValid: Bool {
        let trimmed = draftBundleID.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return !AppTriggerDefaults.sanitize([trimmed]).isEmpty
            && !watched.contains(trimmed)
    }

    private var runningAppsMenu: some View {
        let candidates = trigger.runningBundleIDs
            .filter { !watched.contains($0) }
            .sorted()
        return Menu {
            if candidates.isEmpty {
                Text("No new candidates running.")
            } else {
                ForEach(candidates, id: \.self) { id in
                    Button(id) { addExisting(id) }
                }
            }
        } label: {
            Label("Add from running apps", systemImage: "plus.circle")
                .font(Theme.Fonts.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func addCustom() {
        let trimmed = draftBundleID.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        addExisting(trimmed)
        draftBundleID = ""
    }

    private func addExisting(_ id: String) {
        guard !watched.contains(id) else { return }
        var next = watched
        next.append(id)
        commit(next)
    }

    private func remove(_ id: String) {
        commit(watched.filter { $0 != id })
    }

    private func commit(_ next: [String]) {
        watched = next
        settings.appTriggerBundleIDs = next
    }
}

// MARK: - WiFi config form

private struct WiFiTriggerConfigForm: View {

    let trigger: WiFiTrigger
    let settings: SettingsStore

    @State private var ssids: [String]
    @State private var inverse: Bool
    @State private var draftSSID: String = ""

    init(trigger: WiFiTrigger, settings: SettingsStore) {
        self.trigger = trigger
        self.settings = settings
        self._ssids = State(initialValue: settings.wifiTriggerSSIDs)
        self._inverse = State(initialValue: settings.wifiTriggerInverseLogic)
    }

    var body: some View {
        Group {
            Picker("Mode", selection: $inverse) {
                Text("On these networks").tag(false)
                Text("Off these networks").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: inverse) { newValue in
                settings.wifiTriggerInverseLogic = newValue
            }

            ForEach(ssids, id: \.self) { ssid in
                HStack {
                    Image(systemName: "wifi")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(ssid).font(Theme.Fonts.caption)
                    Spacer()
                    Button {
                        remove(ssid)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(ssid)")
                }
            }

            if ssids.isEmpty {
                Text(inverse
                     ? "Empty list under inverse mode is treated as a no-op (the trigger never fires)."
                     : "No networks configured. The trigger will never fire.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Theme.Spacing.xs) {
                TextField("Network name", text: $draftSSID)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.Fonts.caption)
                Button("Add") { addManual() }
                    .disabled(!isDraftValid)
            }

            if let current = trigger.currentSSID, !ssids.contains(current) {
                Button {
                    addExisting(current)
                } label: {
                    Label("Add current network: \(current)", systemImage: "antenna.radiowaves.left.and.right")
                        .font(Theme.Fonts.caption)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var isDraftValid: Bool {
        let trimmed = draftSSID.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty
            && trimmed.utf8.count <= 32
            && !ssids.contains(trimmed)
    }

    private func addManual() {
        let trimmed = draftSSID.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        addExisting(trimmed)
        draftSSID = ""
    }

    private func addExisting(_ ssid: String) {
        guard !ssids.contains(ssid) else { return }
        var next = ssids
        next.append(ssid)
        commit(next)
    }

    private func remove(_ ssid: String) {
        commit(ssids.filter { $0 != ssid })
    }

    private func commit(_ next: [String]) {
        ssids = next
        settings.wifiTriggerSSIDs = next
    }
}

// MARK: - Calendar config form (no EKCalendar picker yet — Phase 1.5.B)

private struct CalendarTriggerConfigForm: View {

    let settings: SettingsStore

    @State private var leadMinutes: Int
    @State private var trailingMinutes: Int
    @State private var excludeAllDay: Bool

    init(settings: SettingsStore) {
        self.settings = settings
        self._leadMinutes = State(initialValue: settings.calendarTriggerLeadTimeMinutes)
        self._trailingMinutes = State(initialValue: settings.calendarTriggerTrailingMinutes)
        self._excludeAllDay = State(initialValue: settings.calendarTriggerExcludeAllDay)
    }

    var body: some View {
        Group {
            Stepper(value: $leadMinutes, in: 0...15) {
                LabeledContent("Wake before event") {
                    Text("\(leadMinutes) min")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: leadMinutes) { newValue in
                settings.calendarTriggerLeadTimeMinutes = newValue
            }

            Stepper(value: $trailingMinutes, in: 0...15) {
                LabeledContent("Stay awake after event") {
                    Text("\(trailingMinutes) min")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: trailingMinutes) { newValue in
                settings.calendarTriggerTrailingMinutes = newValue
            }

            Toggle("Exclude all-day events", isOn: $excludeAllDay)
                .onChange(of: excludeAllDay) { newValue in
                    settings.calendarTriggerExcludeAllDay = newValue
                }

            Text("Calendar selection ships in a follow-up update. Today, Latte watches every calendar you've granted access to.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Focus config (informational only — INFocusStatusCenter v1 limitation)

private struct FocusTriggerConfigInfo: View {
    var body: some View {
        Text("Latte stays awake whenever any Focus filter is active. macOS does not expose individual Focus identifiers to third-party apps in a stable way, so per-Focus selection is deferred until Apple opens that API.")
            .font(Theme.Fonts.caption)
            .foregroundStyle(.secondary)
    }
}
