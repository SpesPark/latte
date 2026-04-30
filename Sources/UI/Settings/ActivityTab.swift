import SwiftUI
import Charts
import AppKit
import UniformTypeIdentifiers

/// Activity history tab (C-3). Renders the trigger fire log as a 24h
/// stacked bar + 14d heatmap + the in-memory "currently active" list.
/// See `docs/design/09-c3-activity-history.md` §5.
public struct ActivityTab: View {

    @ObservedObject public var coordinator: TriggerCoordinator
    public let store: ActivityLogStore?
    /// Invoked when the user clicks a row in "Currently active" — flips the
    /// SettingsRoot selection to `.triggers` and scrolls to that trigger
    /// (C-3 deferred D). Default no-op so previews / unit-test hosts work.
    public let onJumpToTrigger: (String) -> Void
    @EnvironmentObject private var environment: AppEnvironment

    @State private var entries: [ActivityLogEntry] = []
    @State private var isLoading = true
    @State private var filter: ActivityFilter = .all
    /// Coalesces bursty `.activityLogDidAppend` notifications. Multiple
    /// trigger fires inside a 300 ms window collapse into a single reload —
    /// avoids re-fetching the snapshot N times when several triggers emit
    /// in quick succession (boot path, "all triggers fired at once").
    @State private var liveReloadTask: Task<Void, Never>? = nil

    public init(
        coordinator: TriggerCoordinator,
        store: ActivityLogStore?,
        onJumpToTrigger: @escaping (String) -> Void = { _ in }
    ) {
        self.coordinator = coordinator
        self.store = store
        self.onJumpToTrigger = onJumpToTrigger
    }

    public var body: some View {
        Form {
            if isLoading {
                ProgressView().controlSize(.small)
            } else if entries.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("Trigger fires will appear here.")
                            .font(.headline)
                        Text("Once any trigger turns Latte on or off, the event is recorded for 14 days.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section {
                    TriggerFilterPicker(filter: $filter, observed: ActivityFilter.triggerIdsObserved(in: entries))
                }
                let filtered = filter.apply(to: entries)
                Section("Last 24 hours") {
                    HourlyAwakeChart(entries: filtered)
                        .frame(height: 160)
                }
                Section("Last \(environment.activityRetentionDays) days") {
                    DailyHeatmapChart(entries: filtered, days: environment.activityRetentionDays)
                        .frame(height: 200)
                }
                Section("Daily totals") {
                    DailyTotalsChart(entries: filtered, days: environment.activityRetentionDays)
                        .frame(height: 160)
                }
            }
            Section("Currently active") {
                CurrentlyActiveList(
                    activeVotes: coordinator.activeVotes,
                    onJump: onJumpToTrigger
                )
            }
            Section("Retention") {
                RetentionStepper(days: $environment.activityRetentionDays)
            }
            if !entries.isEmpty {
                Section("Export") {
                    ExportButtons { format in
                        export(filter.apply(to: entries), as: format)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { await reload() }
        .onChange(of: environment.activityRetentionDays) { _ in
            // Grow path: actor stays in sync via setRetention(), but the
            // UI's `entries` snapshot was scoped to the old cutoff. Re-fetch
            // so the recovered older history shows up without a tab bounce.
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activityLogDidAppend)) { _ in
            scheduleLiveReload()
        }
        .onDisappear { liveReloadTask?.cancel() }
    }

    /// Cancels any pending reload and schedules a new one 300 ms in the
    /// future — bursty trigger fires (e.g. all triggers boot together)
    /// collapse to a single snapshot fetch.
    private func scheduleLiveReload() {
        liveReloadTask?.cancel()
        liveReloadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    /// Routes the filtered snapshot through `ActivityLogExporter` and a
    /// `NSSavePanel`. Failures are logged + swallowed (panel handles the
    /// "user cancelled" path; write errors are owner-side, not crashable).
    private func export(_ entries: [ActivityLogEntry], as format: ActivityLogExporter.Format) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = ActivityLogExporter.suggestedFilename(for: format)
        switch format {
        case .csv:  panel.allowedContentTypes = [.commaSeparatedText]
        case .json: panel.allowedContentTypes = [.json]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            switch format {
            case .csv:
                try Data(ActivityLogExporter.csv(from: entries).utf8).write(to: url, options: .atomic)
            case .json:
                let data = try ActivityLogExporter.jsonData(from: entries)
                try data.write(to: url, options: .atomic)
            }
        } catch {
            LatteLog.activity.error("activity-log export failed — \(error.localizedDescription, privacy: .public)")
        }
    }

    private func reload() async {
        // Flip back to loading so a retention-change re-fetch shows the
        // spinner instead of stale data. `defer` clears it after the actor
        // hop completes.
        isLoading = true
        defer { isLoading = false }
        guard let store else {
            entries = []
            return
        }
        let cutoff = Date().addingTimeInterval(-Double(environment.activityRetentionDays) * ActivityLogStore.secondsPerDay)
        entries = await store.snapshot(since: cutoff)
    }
}

// MARK: - 24h stacked bar

private struct HourlyAwakeChart: View {
    let entries: [ActivityLogEntry]

    private static let triggerDomain: [String] = ["wifi", "calendar", "focus", "app", "schedule", "external-display"]
    private static let triggerRange: [Color] = [.blue, .red, .purple, .green, .orange, .teal]

    var body: some View {
        let buckets = HourlyBucket.compute(from: entries, window: 24 * 60 * 60, now: .now)
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Hour", bucket.hour),
                y: .value("Minutes", bucket.awakeMinutes)
            )
            .foregroundStyle(by: .value("Trigger", bucket.triggerId))
        }
        .chartForegroundStyleScale(domain: Self.triggerDomain, range: Self.triggerRange)
        .chartXAxis { AxisMarks(values: .stride(by: 3)) }
    }
}

// MARK: - 14d heatmap

private struct DailyHeatmapChart: View {
    let entries: [ActivityLogEntry]
    let days: Int

    var body: some View {
        let cells = HeatmapCell.compute(from: entries, days: days, now: .now)
        Chart(cells) { cell in
            RectangleMark(
                xStart: .value("DayStart", Double(cell.dayOffset) - 0.5),
                xEnd:   .value("DayEnd",   Double(cell.dayOffset) + 0.5),
                yStart: .value("HourStart", Double(cell.hour) - 0.5),
                yEnd:   .value("HourEnd",   Double(cell.hour) + 0.5)
            )
            .foregroundStyle(by: .value("Awake", cell.awakeMinutes))
        }
        .chartForegroundStyleScale(range: Gradient(colors: [Color.clear, Color.accentColor]))
        .chartYAxis { AxisMarks(values: [0, 6, 12, 18]) }
    }
}

// MARK: - Export buttons (C)

/// Two-button row that calls back into the host with the chosen format.
/// The host owns the NSSavePanel call so the buttons stay testable as a
/// pure View (no AppKit side effect baked in).
private struct ExportButtons: View {

    let onExport: (ActivityLogExporter.Format) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button("Export CSV…") { onExport(.csv) }
                .accessibilityIdentifier("activity.export.csv")
            Button("Export JSON…") { onExport(.json) }
                .accessibilityIdentifier("activity.export.json")
        }
    }
}

// MARK: - Per-trigger filter picker (B)

/// Picker selection for narrowing the Activity charts to a single trigger.
/// Domain is dynamic — only triggers actually present in the entry set
/// appear as choices, so a fresh user without a Schedule trigger doesn't
/// see "Schedule" in the picker.
private struct TriggerFilterPicker: View {

    @Binding var filter: ActivityFilter
    let observed: [String]

    var body: some View {
        Picker(selection: $filter) {
            Text("All triggers").tag(ActivityFilter.all)
            ForEach(observed, id: \.self) { id in
                Text(ActivityFilter.label(for: id))
                    .tag(ActivityFilter.only(id))
            }
        } label: {
            Text("Show")
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("activity.filter.picker")
    }
}

// MARK: - Retention stepper (F)

/// Owner-facing knob for `SettingsKey.activityRetentionDays`. The binding
/// flows through `AppEnvironment` whose `didSet` writes to `SettingsStore`
/// AND propagates the new window into the live `ActivityLogStore` actor —
/// shrinking the window GCs stale entries on the spot.
private struct RetentionStepper: View {

    @Binding var days: Int

    var body: some View {
        Stepper(value: $days,
                in: ActivityLogStore.retentionDayRange,
                step: 1) {
            HStack {
                Text("Keep history for")
                Spacer()
                Text("\(days) day\(days == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityIdentifier("activity.retention.stepper")
    }
}

// MARK: - Daily totals (E)

/// Bar chart of total awake minutes per day across the retention window.
/// Today is highlighted via a darker accent so the eye picks "today vs N
/// days ago" without a separate overlay. Parallel triggers don't double-
/// count (see `DailyTotal.compute` → `AwakeSegment.merge`).
private struct DailyTotalsChart: View {
    let entries: [ActivityLogEntry]
    let days: Int

    private static let dayLabel: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "M/d"
        return f
    }()

    var body: some View {
        let totals = DailyTotal.compute(from: entries, days: days, now: .now)
        Chart(totals) { total in
            BarMark(
                x: .value("Day", Self.dayLabel.string(from: total.date)),
                y: .value("Minutes", total.awakeMinutes)
            )
            .foregroundStyle(total.dayOffset == 0 ? Color.accentColor : Color.accentColor.opacity(0.4))
        }
        .chartXAxis {
            // Cap visible labels — for a 90-day window, every 7 days
            // keeps the axis readable; for ≤14 days the natural stride
            // shows them all.
            AxisMarks(values: .automatic(desiredCount: min(days, 14)))
        }
    }
}

// MARK: - Currently active

private struct CurrentlyActiveList: View {
    let activeVotes: [String: TriggerVote]
    let onJump: (String) -> Void

    var body: some View {
        if activeVotes.isEmpty {
            Text("Nothing active right now.").foregroundStyle(.secondary)
        } else {
            ForEach(activeVotes.keys.sorted(), id: \.self) { triggerId in
                if let vote = activeVotes[triggerId] {
                    Button {
                        onJump(triggerId)
                    } label: {
                        LabeledContent(triggerId.capitalized) {
                            HStack(spacing: 4) {
                                Text(vote.reason).foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("activity.active.row.\(triggerId)")
                    .accessibilityHint("Opens this trigger's configuration")
                }
            }
        }
    }
}

// MARK: - Bucketing

/// One (hour, triggerId) → minutes-awake aggregate row for the 24h chart.
struct HourlyBucket: Identifiable {
    let id = UUID()
    let hour: Int
    let triggerId: String
    let awakeMinutes: Double

    /// Computes hourly awake duration per trigger from raw entries.
    /// ON without matching OFF (or vice-versa) within the window is closed
    /// at the window boundary so the bar reflects the visible state only.
    static func compute(from entries: [ActivityLogEntry], window: TimeInterval, now: Date) -> [HourlyBucket] {
        let cutoff = now.addingTimeInterval(-window)
        let scoped = entries.filter { $0.timestamp >= cutoff }
        let byTrigger = Dictionary(grouping: scoped, by: \.triggerId)

        var out: [HourlyBucket] = []
        for (triggerId, rows) in byTrigger {
            let segments = AwakeSegment.pair(rows.sorted { $0.timestamp < $1.timestamp }, windowStart: cutoff, windowEnd: now)
            for segment in segments {
                let hourBuckets = segment.splitByHour()
                for (hour, minutes) in hourBuckets {
                    if let idx = out.firstIndex(where: { $0.hour == hour && $0.triggerId == triggerId }) {
                        out[idx] = HourlyBucket(hour: hour, triggerId: triggerId, awakeMinutes: out[idx].awakeMinutes + minutes)
                    } else {
                        out.append(HourlyBucket(hour: hour, triggerId: triggerId, awakeMinutes: minutes))
                    }
                }
            }
        }
        return out
    }
}

/// One day's total awake minutes — used by the multi-day comparison chart
/// (C-3 deferred E). `dayOffset = 0` is the most recent day in the retention
/// window; older days have higher offsets.
struct DailyTotal: Identifiable {
    let id = UUID()
    let dayOffset: Int
    let date: Date
    let awakeMinutes: Double

    /// Sums per-day awake minutes across the retention window. Per-trigger
    /// pair → merge → split by day. Parallel triggers don't double-count
    /// (the merge unions overlapping segments — see `AwakeSegment.merge`).
    static func compute(from entries: [ActivityLogEntry], days: Int, now: Date) -> [DailyTotal] {
        let cal = Calendar.current
        // `Calendar.date(byAdding: .day, ...)` respects DST — raw `-86400`
        // arithmetic shifts the window by ±1h on a DST-transition day.
        let windowStart = cal.startOfDay(
            for: cal.date(byAdding: .day, value: -(days - 1), to: now) ?? now
        )
        let scoped = entries.filter { $0.timestamp >= windowStart }
        let byTrigger = Dictionary(grouping: scoped, by: \.triggerId)
        var allSegments: [AwakeSegment] = []
        for (_, rows) in byTrigger {
            allSegments += AwakeSegment.pair(
                rows.sorted { $0.timestamp < $1.timestamp },
                windowStart: windowStart,
                windowEnd: now
            )
        }
        let merged = AwakeSegment.merge(allSegments.sorted { $0.start < $1.start })

        var totals: [Int: Double] = [:]
        for segment in merged {
            for (date, minutes) in segment.splitByHourWithDate() {
                let dayStart = cal.startOfDay(for: date)
                let offset = cal.dateComponents([.day], from: windowStart, to: dayStart).day ?? 0
                totals[offset, default: 0] += minutes
            }
        }
        var out: [DailyTotal] = []
        for d in 0..<days {
            let date = cal.date(byAdding: .day, value: d, to: windowStart) ?? windowStart
            out.append(DailyTotal(dayOffset: days - 1 - d, date: date, awakeMinutes: totals[d] ?? 0))
        }
        return out
    }
}

/// One heatmap cell — (dayOffset 0..13, hour 0..23) → minutes-awake.
struct HeatmapCell: Identifiable {
    let id = UUID()
    let dayOffset: Int
    let hour: Int
    let awakeMinutes: Double

    static func compute(from entries: [ActivityLogEntry], days: Int, now: Date) -> [HeatmapCell] {
        let cal = Calendar.current
        let windowStart = cal.startOfDay(for: now.addingTimeInterval(-Double(days - 1) * 86400))
        let windowEnd = now
        let scoped = entries.filter { $0.timestamp >= windowStart }
        // Per-trigger pair → merge across triggers — single-stream pairing
        // would interleave a second trigger's ON between another's ON/OFF
        // and miscount when triggers fire in parallel.
        let byTrigger = Dictionary(grouping: scoped, by: \.triggerId)
        var allSegments: [AwakeSegment] = []
        for (_, rows) in byTrigger {
            let sorted = rows.sorted { $0.timestamp < $1.timestamp }
            allSegments += AwakeSegment.pair(sorted, windowStart: windowStart, windowEnd: windowEnd)
        }
        let merged = AwakeSegment.merge(allSegments.sorted { $0.start < $1.start })

        var grid: [Int: [Int: Double]] = [:]   // [dayOffset: [hour: minutes]]
        for segment in merged {
            for (date, minutes) in segment.splitByHourWithDate() {
                let day = cal.startOfDay(for: date)
                let dayOffset = cal.dateComponents([.day], from: windowStart, to: day).day ?? 0
                let hour = cal.component(.hour, from: date)
                grid[dayOffset, default: [:]][hour, default: 0] += minutes
            }
        }
        var out: [HeatmapCell] = []
        for d in 0..<days {
            for h in 0..<24 {
                out.append(HeatmapCell(
                    dayOffset: d, hour: h,
                    awakeMinutes: grid[d]?[h] ?? 0
                ))
            }
        }
        return out
    }
}

/// One ON/OFF segment for a single trigger, clamped to a window.
struct AwakeSegment {
    let start: Date
    let end: Date

    /// Pairs ON/OFF entries into segments. An unmatched trailing ON is closed
    /// at `windowEnd`. An unmatched leading OFF (someone was already awake)
    /// is treated as starting at `windowStart`.
    static func pair(_ entries: [ActivityLogEntry], windowStart: Date, windowEnd: Date) -> [AwakeSegment] {
        var segments: [AwakeSegment] = []
        var openStart: Date? = nil
        for entry in entries {
            switch entry.kind {
            case .on:
                if openStart == nil {
                    openStart = max(entry.timestamp, windowStart)
                }
            case .off:
                let s = openStart ?? windowStart
                segments.append(AwakeSegment(start: s, end: min(entry.timestamp, windowEnd)))
                openStart = nil
            }
        }
        if let s = openStart {
            segments.append(AwakeSegment(start: s, end: windowEnd))
        }
        return segments
    }

    /// Unions overlapping or touching segments. Caller must pass them sorted
    /// by `start`. Used by the heatmap to fold parallel-trigger awake periods
    /// into a single "Latte was awake" timeline so total minutes don't double-count.
    static func merge(_ sorted: [AwakeSegment]) -> [AwakeSegment] {
        guard let first = sorted.first else { return [] }
        var out: [AwakeSegment] = [first]
        for s in sorted.dropFirst() {
            let last = out[out.count - 1]
            if s.start <= last.end {
                out[out.count - 1] = AwakeSegment(start: last.start, end: max(last.end, s.end))
            } else {
                out.append(s)
            }
        }
        return out
    }

    /// Splits into per-hour [hour: minutes] (24h chart helper).
    func splitByHour() -> [(Int, Double)] {
        splitByHourWithDate().map { (Calendar.current.component(.hour, from: $0.0), $0.1) }
    }

    /// Splits into per-hour-of-calendar-day [(date-truncated-to-hour, minutes)] (heatmap helper).
    /// DST caveat: a fall-back night double-counts the repeated 1AM hour and a
    /// spring-forward night shows a zero-minute gap at 2AM. Both are chart
    /// cosmetics — total awake-minutes are still correct. Owner-facing impact
    /// is one misleading hour bucket twice a year.
    func splitByHourWithDate() -> [(Date, Double)] {
        var out: [(Date, Double)] = []
        let cal = Calendar.current
        var cursor = start
        while cursor < end {
            let nextHour = cal.date(bySetting: .minute, value: 0, of: cursor.addingTimeInterval(3600))
                ?? cursor.addingTimeInterval(3600)
            let segmentEnd = min(nextHour, end)
            let minutes = segmentEnd.timeIntervalSince(cursor) / 60.0
            let hourTruncated = cal.date(bySettingHour: cal.component(.hour, from: cursor), minute: 0, second: 0, of: cursor) ?? cursor
            out.append((hourTruncated, minutes))
            cursor = segmentEnd
        }
        return out
    }
}
