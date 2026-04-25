import SwiftUI

public struct TriggersTab: View {

    @ObservedObject public var coordinator: TriggerCoordinator
    @EnvironmentObject private var environment: AppEnvironment

    public init(coordinator: TriggerCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Form {
            Section {
                ForEach(Array(coordinator.triggers.enumerated()), id: \.offset) { _, trigger in
                    TriggerRow(
                        trigger: trigger,
                        activeVote: coordinator.activeVotes[trigger.id]
                    )
                }
            } header: {
                Text("Automatic triggers").font(Theme.Fonts.subheadline)
            } footer: {
                Text("Enable a trigger to let Latte wake your Mac automatically. Tap a row to configure which calendars, apps, or networks count as “awake-worthy.”")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - TriggerRow + DisclosureGroup body

private struct TriggerRow: View {

    let trigger: any Trigger
    let activeVote: TriggerVote?
    @State private var isOn: Bool
    @State private var isExpanded: Bool = false
    @EnvironmentObject private var environment: AppEnvironment

    init(trigger: any Trigger, activeVote: TriggerVote?) {
        self.trigger = trigger
        self.activeVote = activeVote
        self._isOn = State(initialValue: trigger.isEnabled)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            configBody
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.xs)
        } label: {
            header
        }
    }

    private var header: some View {
        let accent = environment.coffeeAccent.color
        return HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: trigger.symbol)
                .frame(width: 22)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(trigger.displayName)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.primary)
                if let reason = subtitle {
                    Text(reason)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(isVoting ? accent : .secondary)
                        .accessibilityIdentifier("trigger.row.subtitle.\(trigger.id)")
                }
            }

            Spacer()

            if isVoting {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("\(trigger.displayName) is currently voting awake")
            }

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { newValue in
                    trigger.isEnabled = newValue
                    if newValue { isExpanded = true }
                }
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

    private var isVoting: Bool {
        activeVote?.wantsAwake == true
    }

    private var subtitle: String? {
        if let reason = activeVote?.reason, !reason.isEmpty {
            return "Voting awake — \(reason)"
        }
        if !trigger.isEnabled {
            return "Disabled"
        }
        switch trigger.permissionStatus {
        case .denied:       return "Permission denied — open System Settings"
        case .notDetermined: return "Permission not yet requested"
        case .granted:      return "Idle"
        case .notRequired:  return "Idle"
        }
    }
}

// MARK: - App config form

private struct AppTriggerConfigForm: View {

    let trigger: AppTrigger
    let settings: SettingsStore

    @State private var watched: [String]
    @State private var draftBundleID: String = ""
    @State private var pickerVisible: Bool = false

    init(trigger: AppTrigger, settings: SettingsStore) {
        self.trigger = trigger
        self.settings = settings
        self._watched = State(initialValue: settings.appTriggerBundleIDs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(watched, id: \.self) { bundleID in
                HStack {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(bundleID)
                        .font(Theme.Fonts.caption.monospacedDigit())
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

            Divider().padding(.vertical, 2)

            HStack(spacing: Theme.Spacing.xs) {
                TextField("e.g. us.zoom.xos", text: $draftBundleID)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.Fonts.caption.monospacedDigit())
                Button("Add") { addCustom() }
                    .disabled(!isDraftValid)
            }

            DisclosureGroup(isExpanded: $pickerVisible) {
                runningAppsPicker
                    .padding(.top, 4)
            } label: {
                Label("Add from running apps", systemImage: "appclip")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isDraftValid: Bool {
        let trimmed = draftBundleID.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return !AppTriggerDefaults.sanitize([trimmed]).isEmpty
            && !watched.contains(trimmed)
    }

    @ViewBuilder
    private var runningAppsPicker: some View {
        let candidates = trigger.runningBundleIDs
            .filter { !watched.contains($0) }
            .sorted()
        if candidates.isEmpty {
            Text("No new candidates running.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(candidates, id: \.self) { id in
                HStack {
                    Text(id)
                        .font(Theme.Fonts.caption.monospacedDigit())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        addExisting(id)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Picker("Mode", selection: $inverse) {
                Text("Stay awake on these networks").tag(false)
                Text("Stay awake when not on these").tag(true)
            }
            .pickerStyle(.radioGroup)
            .onChange(of: inverse) { settings.wifiTriggerInverseLogic = $0 }

            Divider().padding(.vertical, 2)

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
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Stepper(value: $leadMinutes, in: 0...15) {
                LabeledContent("Wake before event") {
                    Text("\(leadMinutes) min")
                        .font(Theme.Fonts.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: leadMinutes) { settings.calendarTriggerLeadTimeMinutes = $0 }

            Stepper(value: $trailingMinutes, in: 0...15) {
                LabeledContent("Stay awake after event") {
                    Text("\(trailingMinutes) min")
                        .font(Theme.Fonts.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: trailingMinutes) { settings.calendarTriggerTrailingMinutes = $0 }

            Toggle("Exclude all-day events", isOn: $excludeAllDay)
                .onChange(of: excludeAllDay) { settings.calendarTriggerExcludeAllDay = $0 }

            Text("Calendar selection (which calendars to watch) ships in a follow-up update. Today, Latte watches every calendar you've granted access to.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Focus config (informational only — INFocusStatusCenter v1 limitation)

private struct FocusTriggerConfigInfo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Latte stays awake whenever any Focus filter is active. macOS does not expose individual Focus identifiers to third-party apps in a stable way, so per-Focus selection is deferred until Apple opens that API.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }
}
