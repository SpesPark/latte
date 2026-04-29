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
    @State private var showAdvanced: Bool = false

    init(trigger: AppTrigger, settings: SettingsStore) {
        self.trigger = trigger
        self.settings = settings
        self._watched = State(initialValue: settings.appTriggerBundleIDs)
    }

    var body: some View {
        Group {
            Text("Latte stays awake while any of these apps are running. Add the apps that must keep your Mac active — video meetings, presentations, long-running tools.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(watched, id: \.self) { bundleID in
                AppRow(
                    bundleID: bundleID,
                    info: trigger.displayInfo(for: bundleID),
                    onRemove: { remove(bundleID) }
                )
            }

            if watched.isEmpty {
                Text("No apps configured yet. Use \u{201C}Add from running apps\u{201D} below to add the apps you want Latte to keep awake — or use \u{201C}Advanced\u{201D} for an app that isn\u{2019}t running right now.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            runningAppsMenu

            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Type a bundle identifier (e.g. us.zoom.xos) to watch an app that isn't currently running.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Theme.Spacing.xs) {
                        TextField("us.zoom.xos", text: $draftBundleID)
                            .textFieldStyle(.roundedBorder)
                            .font(Theme.Fonts.caption)
                        Button("Add") { addCustom() }
                            .disabled(!isDraftValid)
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            } label: {
                Label("Advanced — add by bundle ID", systemImage: "wrench.adjustable")
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

    private var runningAppsMenu: some View {
        let candidates = trigger.pickableRunningBundleIDs
            .filter { !watched.contains($0) }
            .map { id -> (id: String, info: AppDisplayInfo?) in
                (id, trigger.displayInfo(for: id))
            }
            .sorted { lhs, rhs in
                let ln = lhs.info?.displayName ?? lhs.id
                let rn = rhs.info?.displayName ?? rhs.id
                return ln.localizedCaseInsensitiveCompare(rn) == .orderedAscending
            }
        return Menu {
            if candidates.isEmpty {
                Text("No new running apps to add.")
            } else {
                ForEach(candidates, id: \.id) { candidate in
                    Button {
                        addExisting(candidate.id)
                    } label: {
                        menuItemLabel(for: candidate.id, info: candidate.info)
                    }
                }
            }
        } label: {
            Label("Add from running apps", systemImage: "plus.circle")
                .font(Theme.Fonts.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private func menuItemLabel(for bundleID: String, info: AppDisplayInfo?) -> some View {
        let title = info?.displayName ?? bundleID
        if let data = info?.iconImageData, let nsImage = NSImage(data: data) {
            Label {
                Text(title)
            } icon: {
                Image(nsImage: nsImage)
            }
        } else if let symbol = AppTriggerDefaults.symbolHint(for: bundleID) {
            Label(title, systemImage: symbol)
        } else {
            Text(title)
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
        // Push the new watched set into the live trigger so the awake-state
        // vote reflects the change immediately (S7.9 — without this, removing
        // an app from the list left the trigger emitting a stale ON vote).
        trigger.reevaluateWatched()
    }
}

// MARK: - AppRow (icon + friendly name + bundle ID secondary)

private struct AppRow: View {
    let bundleID: String
    let info: AppDisplayInfo?
    let onRemove: () -> Void

    private var resolvedName: String {
        info?.displayName ?? bundleID
    }

    private var showsBundleIDSecondary: Bool {
        guard let info else { return false }
        return info.displayName != bundleID
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            iconView
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(resolvedName)
                    .font(Theme.Fonts.body)
                    .lineLimit(1)
                if showsBundleIDSecondary {
                    Text(bundleID)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(resolvedName)")
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let data = info?.iconImageData, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let symbol = AppTriggerDefaults.symbolHint(for: bundleID) {
            Image(systemName: symbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
                .padding(2)
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
        }
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
                // S8b smoke owner-feedback + V2-02 (S9.6): re-evaluate
                // immediately so mode changes reflect within one render
                // pass instead of waiting for the 30s poll cycle.
                trigger.reevaluateWatched()
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
        // S8b smoke owner-feedback + V2-02 (S9.6): re-evaluate immediately
        // on add/remove so the cup reflects within one render pass instead
        // of waiting up to 30 s for the next poll cycle. Mirrors the
        // AppTrigger.reevaluateWatched contract (S7.9).
        trigger.reevaluateWatched()
    }
}

// MARK: - Calendar config form (V2-04 — multi-calendar picker)

private struct CalendarTriggerConfigForm: View {

    let trigger: CalendarTrigger
    let settings: SettingsStore

    @State private var leadMinutes: Int
    @State private var trailingMinutes: Int
    @State private var excludeAllDay: Bool
    @State private var selectedCalendarIDs: Set<String>
    @State private var availableCalendars: [CalendarSummary] = []

    init(trigger: CalendarTrigger, settings: SettingsStore) {
        self.trigger = trigger
        self.settings = settings
        self._leadMinutes = State(initialValue: settings.calendarTriggerLeadTimeMinutes)
        self._trailingMinutes = State(initialValue: settings.calendarTriggerTrailingMinutes)
        self._excludeAllDay = State(initialValue: settings.calendarTriggerExcludeAllDay)
        // Empty persisted set means "all granted calendars" — we render
        // that as no checkboxes ticked, with explicit copy. When the
        // user picks any calendar, the set becomes non-empty and the
        // trigger filters to that subset.
        self._selectedCalendarIDs = State(
            initialValue: Set(settings.calendarTriggerCalendarIDs)
        )
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
                trigger.reevaluateWatched()
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
                trigger.reevaluateWatched()
            }

            Toggle("Exclude all-day events", isOn: $excludeAllDay)
                .onChange(of: excludeAllDay) { newValue in
                    settings.calendarTriggerExcludeAllDay = newValue
                    trigger.reevaluateWatched()
                }

            calendarPickerSection
        }
        .task {
            availableCalendars = trigger.availableCalendars()
        }
    }

    @ViewBuilder
    private var calendarPickerSection: some View {
        if availableCalendars.isEmpty {
            Text("Latte watches every calendar you've granted access to. Re-open this tab once Calendar permission is granted to pick specific calendars.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    pickerHeaderControls
                    ForEach(availableCalendars) { calendar in
                        CalendarPickerRow(
                            calendar: calendar,
                            isSelected: selectedCalendarIDs.contains(calendar.id),
                            onToggle: { toggle(calendar.id) }
                        )
                    }
                    Text(filterDescription)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, Theme.Spacing.xs)
                }
                .padding(.top, Theme.Spacing.xs)
            } label: {
                HStack {
                    Label("Watched calendars", systemImage: "calendar")
                        .font(Theme.Fonts.caption)
                    Spacer()
                    Text(selectedCalendarIDs.isEmpty
                         ? "All calendars"
                         : "\(selectedCalendarIDs.count) selected")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var pickerHeaderControls: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button("Select all") {
                selectedCalendarIDs = Set(availableCalendars.map(\.id))
                commit()
            }
            .buttonStyle(.borderless)
            .font(Theme.Fonts.caption)

            Button("Use all calendars") {
                selectedCalendarIDs.removeAll()
                commit()
            }
            .buttonStyle(.borderless)
            .font(Theme.Fonts.caption)
            .help("Empty selection means Latte watches every calendar you've granted access to.")

            Spacer()
        }
    }

    private var filterDescription: String {
        if selectedCalendarIDs.isEmpty {
            return "Empty selection = watch every granted calendar."
        }
        return "Latte only fires for events in the calendars checked above."
    }

    private func toggle(_ id: String) {
        if selectedCalendarIDs.contains(id) {
            selectedCalendarIDs.remove(id)
        } else {
            selectedCalendarIDs.insert(id)
        }
        commit()
    }

    private func commit() {
        // Sort for stable persisted order (avoids spurious diffs in
        // UserDefaults snapshots and helps the next read yield a
        // predictable ordering).
        settings.calendarTriggerCalendarIDs = selectedCalendarIDs.sorted()
        // V2-02 (S9.6): same immediate-reflect contract as WiFi/App.
        trigger.reevaluateWatched()
    }
}

private struct CalendarPickerRow: View {

    let calendar: CalendarSummary
    let isSelected: Bool
    let onToggle: () -> Void

    private var swatchColor: Color {
        Color(red: calendar.red, green: calendar.green, blue: calendar.blue)
            .opacity(calendar.alpha)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 16)
                Circle()
                    .fill(swatchColor)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 0) {
                    Text(calendar.title)
                        .font(Theme.Fonts.body)
                        .lineLimit(1)
                    if !calendar.sourceTitle.isEmpty {
                        Text(calendar.sourceTitle)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(calendar.title), \(calendar.sourceTitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

// MARK: - Schedule config form (V2-05 — recurring time-of-day windows)

private struct ScheduleTriggerConfigForm: View {

    let trigger: ScheduleTrigger
    let settings: SettingsStore

    @State private var entries: [ScheduleEntry]

    init(trigger: ScheduleTrigger, settings: SettingsStore) {
        self.trigger = trigger
        self.settings = settings
        self._entries = State(initialValue: settings.scheduleTriggerEntries)
    }

    var body: some View {
        Group {
            Text("Latte stays awake during these recurring time windows. Useful for working hours, scheduled batch jobs, or "
                 + "any \u{201C}keep awake from X to Y\u{201D} routine.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(entries) { entry in
                ScheduleEntryRow(
                    entry: entry,
                    onUpdate: { updated in update(entry.id, with: updated) },
                    onRemove: { remove(entry.id) }
                )
            }

            if entries.isEmpty {
                Text("No schedules configured. Add one below — e.g. \u{201C}Mon–Fri, 09:00–18:00\u{201D} for working hours.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                addNew()
            } label: {
                Label("Add schedule", systemImage: "plus.circle")
                    .font(Theme.Fonts.caption)
            }
            .buttonStyle(.borderless)
        }
    }

    private func addNew() {
        let new = ScheduleEntry(
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0),
            label: ""
        )
        commit(entries + [new])
    }

    private func update(_ id: UUID, with updated: ScheduleEntry) {
        commit(entries.map { $0.id == id ? updated : $0 })
    }

    private func remove(_ id: UUID) {
        commit(entries.filter { $0.id != id })
    }

    private func commit(_ next: [ScheduleEntry]) {
        entries = next
        settings.scheduleTriggerEntries = next
        // V2-02 (S9.6): edits reflect within one render pass instead of
        // waiting up to 30 s for the next poll. Surface mirrors AppTrigger.
        trigger.reevaluateWatched()
    }
}

private struct ScheduleEntryRow: View {

    let entry: ScheduleEntry
    let onUpdate: (ScheduleEntry) -> Void
    let onRemove: () -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var label: String
    @State private var weekdays: Set<Weekday>
    @State private var isEnabled: Bool

    init(
        entry: ScheduleEntry,
        onUpdate: @escaping (ScheduleEntry) -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.entry = entry
        self.onUpdate = onUpdate
        self.onRemove = onRemove
        self._startDate = State(initialValue: Self.dateFromTime(entry.start))
        self._endDate = State(initialValue: Self.dateFromTime(entry.end))
        self._label = State(initialValue: entry.label)
        self._weekdays = State(initialValue: entry.weekdays)
        self._isEnabled = State(initialValue: entry.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .onChange(of: isEnabled) { _ in commitEdit() }
                TextField("Label (optional)", text: $label)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.Fonts.body)
                    .onChange(of: label) { _ in commitEdit() }
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove schedule")
            }

            HStack(spacing: Theme.Spacing.sm) {
                DatePicker("From", selection: $startDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .onChange(of: startDate) { _ in commitEdit() }
                Text("→").foregroundStyle(.secondary)
                DatePicker("To", selection: $endDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .onChange(of: endDate) { _ in commitEdit() }
                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(Weekday.displayOrder) { day in
                    WeekdayChip(
                        day: day,
                        isSelected: weekdays.contains(day),
                        onToggle: {
                            if weekdays.contains(day) {
                                weekdays.remove(day)
                            } else {
                                weekdays.insert(day)
                            }
                            commitEdit()
                        }
                    )
                }
            }

            if endDate <= startDate {
                Text("Crosses midnight — runs from start time on the selected day(s) until the end time the next morning.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func commitEdit() {
        let updated = ScheduleEntry(
            id: entry.id,
            weekdays: weekdays,
            start: Self.timeFromDate(startDate),
            end: Self.timeFromDate(endDate),
            label: label,
            isEnabled: isEnabled
        )
        onUpdate(updated)
    }

    /// DatePicker binds to Date, but ScheduleEntry persists wall-clock time.
    /// Use the system calendar to extract / inject hour+minute on a fixed
    /// reference date so DatePicker doesn't drift across launches.
    private static let referenceDay: Date = {
        var comps = DateComponents()
        comps.year = 2000; comps.month = 1; comps.day = 1
        return Calendar.current.date(from: comps) ?? Date()
    }()

    private static func dateFromTime(_ time: TimeOfDay) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: referenceDay)
        comps.hour = time.hour
        comps.minute = time.minute
        return Calendar.current.date(from: comps) ?? referenceDay
    }

    private static func timeFromDate(_ date: Date) -> TimeOfDay {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
    }
}

private struct WeekdayChip: View {
    let day: Weekday
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(day.shortName)
                .font(Theme.Fonts.caption)
                .frame(width: 36, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.15),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.shortName), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
