import SwiftUI
import Charts

/// Activity history tab (C-3). Renders the trigger fire log as a 24h
/// stacked bar + 14d heatmap + the in-memory "currently active" list.
/// See `docs/design/09-c3-activity-history.md` §5.
public struct ActivityTab: View {

    @ObservedObject public var coordinator: TriggerCoordinator
    public let store: ActivityLogStore?

    @State private var entries: [ActivityLogEntry] = []
    @State private var isLoading = true

    public init(coordinator: TriggerCoordinator, store: ActivityLogStore?) {
        self.coordinator = coordinator
        self.store = store
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
                Section("Last 24 hours") {
                    HourlyAwakeChart(entries: entries)
                        .frame(height: 160)
                }
                Section("Last 14 days") {
                    DailyHeatmapChart(entries: entries)
                        .frame(height: 200)
                }
            }
            Section("Currently active") {
                CurrentlyActiveList(activeVotes: coordinator.activeVotes)
            }
        }
        .formStyle(.grouped)
        .task { await reload() }
    }

    private func reload() async {
        defer { isLoading = false }
        guard let store else {
            entries = []
            return
        }
        let cutoff = Date().addingTimeInterval(-14 * 24 * 60 * 60)
        entries = await store.snapshot(since: cutoff)
    }
}

// MARK: - 24h stacked bar

private struct HourlyAwakeChart: View {
    let entries: [ActivityLogEntry]

    private static let triggerDomain: [String] = ["wifi", "calendar", "focus", "app", "schedule", "externalDisplay"]
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

    var body: some View {
        let cells = HeatmapCell.compute(from: entries, days: 14, now: .now)
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

// MARK: - Currently active

private struct CurrentlyActiveList: View {
    let activeVotes: [String: TriggerVote]

    var body: some View {
        if activeVotes.isEmpty {
            Text("Nothing active right now.").foregroundStyle(.secondary)
        } else {
            ForEach(activeVotes.keys.sorted(), id: \.self) { triggerId in
                if let vote = activeVotes[triggerId] {
                    LabeledContent(triggerId.capitalized) {
                        Text(vote.reason).foregroundStyle(.secondary)
                    }
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
        let scoped = entries.filter { $0.timestamp >= windowStart }.sorted { $0.timestamp < $1.timestamp }
        let segments = AwakeSegment.pair(scoped, windowStart: windowStart, windowEnd: windowEnd)

        var grid: [Int: [Int: Double]] = [:]   // [dayOffset: [hour: minutes]]
        for segment in segments {
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

    /// Splits into per-hour [hour: minutes] (24h chart helper).
    func splitByHour() -> [(Int, Double)] {
        splitByHourWithDate().map { (Calendar.current.component(.hour, from: $0.0), $0.1) }
    }

    /// Splits into per-hour-of-calendar-day [(date-truncated-to-hour, minutes)] (heatmap helper).
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
