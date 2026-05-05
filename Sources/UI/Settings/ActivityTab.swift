import SwiftUI
import Charts

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
    @State private var hasLoaded = false
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
            if entries.isEmpty {
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
                    HourlyAwakeChart(
                        entries: filtered,
                        overrides: environment.activityChartColors
                    )
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
                RetentionPicker(days: $environment.activityRetentionDays)
            }
            Section("Chart colours") {
                ChartColorPickers(overrides: $environment.activityChartColors)
            }
        }
        .formStyle(.grouped)
        .task {
            // S24 follow-up: `.task` re-fires every tab re-entry (SwiftUI
            // cancels on disappear, restarts on appear). Re-running
            // `reload()` re-assigned `entries` even when snapshot was
            // identical, causing Swift Charts to re-render the bar /
            // heatmap / daily-totals views and the NSScrollView under
            // `.formStyle(.grouped)` to briefly resettle, manifesting as
            // a "scroll position from a previous visit flashes" flicker
            // on every tab return. Gate first-time load with `hasLoaded`;
            // incremental updates flow via `.onReceive` notifications
            // and the retention `.onChange`.
            guard !hasLoaded else { return }
            hasLoaded = true
            await reload()
        }
        .onChange(of: environment.activityRetentionDays) { _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activityLogDidAppend)) { _ in
            scheduleLiveReload()
        }
        .onDisappear { liveReloadTask?.cancel() }
    }

    /// Cancels any pending reload and schedules a new one 300 ms in the
    /// future — bursty trigger fires (e.g. all triggers boot together)
    /// collapse to a single snapshot fetch. Letting `Task.sleep` throw
    /// `CancellationError` is the single mechanism that aborts reload —
    /// no separate `Task.isCancelled` guard needed.
    private func scheduleLiveReload() {
        liveReloadTask?.cancel()
        liveReloadTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                await reload()
            } catch { /* cancelled — newer notification superseded this one */ }
        }
    }

    private func reload() async {
        // S24 follow-up: no spinner state. The original spinner branch (S15)
        // produced a 1-2 frame "spinner only" render on tab entry that
        // looked like a different screen popping in before the chart
        // sections appeared. Always render the entries-driven layout —
        // empty placeholder while `entries` is empty, charts once the
        // snapshot resolves — so the layout stays stable across loads.
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
    /// User-supplied per-trigger colour overrides. `[:]` = palette defaults
    /// for every trigger. Drives the legend swatches via
    /// `chartForegroundStyleScale(domain:range:)`.
    let overrides: [String: String]

    var body: some View {
        let buckets = HourlyBucket.compute(from: entries, window: 24 * 60 * 60, now: .now)
        let domain = ActivityChartPalette.triggerOrder
        let range = domain.map { ActivityChartPalette.color(for: $0, overrides: overrides) }
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Hour", bucket.hour),
                y: .value("Minutes", bucket.awakeMinutes)
            )
            .foregroundStyle(by: .value("Trigger", bucket.triggerId))
        }
        .chartForegroundStyleScale(domain: domain, range: range)
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
//
// Buttons are now inlined directly into the Section in ActivityTab.body
// (see S23 / P-issue-5 comment there). The previous `ExportButtons`
// wrapper View was removed because Section's row tap-handling could
// swallow events when the buttons sat inside an HStack child.

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

// MARK: - Retention picker (F)

/// Owner-facing knob for `SettingsKey.activityRetentionDays`. The binding
/// flows through `AppEnvironment` whose `didSet` writes to `SettingsStore`
/// AND propagates the new window into the live `ActivityLogStore` actor —
/// shrinking the window GCs stale entries on the spot.
///
/// **S23 / P-issue-4**: replaces the previous Stepper. Owner reported the
/// Stepper UX was disorienting — each +/- click triggered a re-fetch +
/// chart re-layout, and chart-collapse during reload made the form bounce.
/// Picker presents 6 preset windows (1 / 7 / 14 / 30 / 60 / 90 days)
/// so each change is a single deliberate selection. Binding writes to
/// `activityRetentionDays`; reader maps any non-preset stored value
/// (e.g. legacy `22`) to its nearest preset for display.
struct RetentionPicker: View {

    @Binding var days: Int

    /// Preset windows offered to the user. All within
    /// `ActivityLogStore.retentionDayRange` (1...90). Sorted ascending so
    /// the menu reads "1 day → 90 days".
    static let presets: [Int] = [1, 7, 14, 30, 60, 90]

    var body: some View {
        Picker(selection: Binding(
            get: { Self.nearestPreset(to: days) },
            set: { days = $0 }
        )) {
            ForEach(Self.presets, id: \.self) { preset in
                Text(Self.label(for: preset)).tag(preset)
            }
        } label: {
            Text("Keep history for")
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("activity.retention.picker")
    }

    /// Maps an arbitrary stored value to the closest available preset.
    /// Pre-S23 users with `22` see "30 days" selected. Distance ties prefer
    /// the smaller preset (less surprise toward more retention).
    static func nearestPreset(to value: Int) -> Int {
        presets.min(by: { abs($0 - value) < abs($1 - value) }) ?? presets[0]
    }

    static func label(for preset: Int) -> String {
        switch preset {
        case 1: return "1 day"
        case 7: return "1 week"
        case 14: return "2 weeks"
        case 30: return "1 month"
        case 60: return "2 months"
        case 90: return "3 months"
        default: return "\(preset) days"
        }
    }
}

// MARK: - Chart colours (C-3 — user-customisable Charts colours)

/// One ColorPicker per trigger plus a "Reset to defaults" button. Writes
/// flow through `AppEnvironment.activityChartColors` whose `didSet` mirrors
/// to `SettingsStore.activityChartColors`. Dropping an override (resetting
/// to default) removes the key from the map so the palette default takes
/// over again — preserves the "absent = never customised" invariant.
private struct ChartColorPickers: View {

    @Binding var overrides: [String: String]

    var body: some View {
        ForEach(ActivityChartPalette.triggerOrder, id: \.self) { triggerId in
            HStack {
                Text(ActivityFilter.label(for: triggerId))
                Spacer()
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { ActivityChartPalette.color(for: triggerId, overrides: overrides) },
                        set: { newValue in
                            if let hex = newValue.hexString {
                                overrides[triggerId] = hex
                            }
                        }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
            }
            .accessibilityIdentifier("activity.chartColor.\(triggerId)")
        }
        if !overrides.isEmpty {
            HStack {
                Spacer()
                Button("Reset to defaults") { overrides = [:] }
                    .accessibilityIdentifier("activity.chartColor.reset")
            }
        }
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
