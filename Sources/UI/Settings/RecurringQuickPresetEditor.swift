import SwiftUI

/// CRUD UI for `RecurringQuickPreset` (C-7 v1.7). Lives in the General
/// Settings tab. Renders the current list, lets the user add/edit/delete
/// via a sheet, and writes back through the supplied binding (whose
/// `didSet` mirror lives in `AppEnvironment.recurringQuickPresets`).
public struct RecurringQuickPresetEditor: View {

    @Binding var presets: [RecurringQuickPreset]

    @State private var editingPreset: RecurringQuickPreset? = nil
    @State private var showingNewSheet: Bool = false

    public init(presets: Binding<[RecurringQuickPreset]>) {
        self._presets = presets
    }

    public var body: some View {
        if presets.isEmpty {
            Text("No custom presets yet. Add one to make it appear in the popover on the days you choose.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(presets) { preset in
                RecurringQuickPresetSummaryRow(preset: preset)
                    .contentShape(Rectangle())
                    .onTapGesture { editingPreset = preset }
                    .contextMenu {
                        Button("Edit…") { editingPreset = preset }
                        Button("Delete", role: .destructive) { delete(preset) }
                    }
            }
        }
        Button("Add preset…") { showingNewSheet = true }
            .accessibilityIdentifier("settings.recurringPreset.add")

        // Add sheet
        .sheet(isPresented: $showingNewSheet) {
            RecurringQuickPresetSheet(initial: nil) { newPreset in
                if let newPreset { presets.append(newPreset) }
                showingNewSheet = false
            }
        }
        // Edit sheet (item-binding so a different preset replaces the previous)
        .sheet(item: $editingPreset) { editing in
            RecurringQuickPresetSheet(initial: editing) { updated in
                if let updated, let idx = presets.firstIndex(where: { $0.id == editing.id }) {
                    presets[idx] = updated
                }
                editingPreset = nil
            }
        }
    }

    private func delete(_ preset: RecurringQuickPreset) {
        presets.removeAll { $0.id == preset.id }
    }
}

// MARK: - Summary row

private struct RecurringQuickPresetSummaryRow: View {
    let preset: RecurringQuickPreset

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.label)
                    .font(Theme.Fonts.body)
                Text(timeAndDaysSummary(for: preset))
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func timeAndDaysSummary(for preset: RecurringQuickPreset) -> String {
        let time = String(format: "%02d:%02d", preset.targetHour, preset.targetMinute)
        let days = RecurringPresetWeekday.summary(for: preset.weekdays)
        return "\(time) · \(days)"
    }
}

// MARK: - Edit / new sheet

private struct RecurringQuickPresetSheet: View {

    let initial: RecurringQuickPreset?
    let onDone: (RecurringQuickPreset?) -> Void

    @State private var label: String = ""
    @State private var hour: Int = 17
    @State private var minute: Int = 0
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]   // Mon-Fri default

    init(
        initial: RecurringQuickPreset?,
        onDone: @escaping (RecurringQuickPreset?) -> Void
    ) {
        self.initial = initial
        self.onDone = onDone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(initial == nil ? "New custom preset" : "Edit preset")
                .font(Theme.Fonts.subheadline)

            Form {
                TextField("Label", text: $label)
                    .accessibilityIdentifier("preset.sheet.label")
                HStack {
                    Text("Time")
                    Spacer()
                    Picker("", selection: $hour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 70)
                    Text(":")
                    Picker("", selection: $minute) {
                        ForEach(stride(from: 0, to: 60, by: 5).map { $0 }, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 70)
                }
                LabeledContent {
                    HStack(spacing: 4) {
                        ForEach(RecurringPresetWeekday.orderedCases, id: \.self) { weekday in
                            WeekdayChip(
                                title: RecurringPresetWeekday.shortLabel(for: weekday),
                                isOn: weekdays.contains(weekday),
                                action: { toggle(weekday) }
                            )
                        }
                    }
                } label: {
                    Text("Days")
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { onDone(nil) }
                Button(initial == nil ? "Add" : "Save") {
                    let preset = RecurringQuickPreset(
                        id: initial?.id ?? UUID(),
                        label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                        targetHour: hour,
                        targetMinute: minute,
                        weekdays: weekdays
                    )
                    onDone(preset)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(minWidth: 380, minHeight: 280)
        .onAppear { hydrate() }
    }

    private var isValid: Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !weekdays.isEmpty
    }

    private func hydrate() {
        guard let initial else { return }
        label = initial.label
        hour = initial.targetHour
        minute = initial.targetMinute
        weekdays = initial.weekdays
    }

    private func toggle(_ weekday: Int) {
        if weekdays.contains(weekday) {
            weekdays.remove(weekday)
        } else {
            weekdays.insert(weekday)
        }
    }
}

// MARK: - Weekday chip

private struct WeekdayChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isOn ? Color.accentColor.opacity(0.85) : Color.primary.opacity(0.06))
                )
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("preset.sheet.weekday.\(title)")
    }
}

// MARK: - Weekday helpers (testable, locale-aware)

/// Pure helpers for weekday rendering and ordering. Kept out of the
/// SwiftUI view so they're trivially unit-testable. Calendar `.weekday`
/// convention: 1 = Sunday … 7 = Saturday.
public enum RecurringPresetWeekday {

    /// Render order for the weekday chips. Sunday-first matches the macOS
    /// system default; localisation-aware ordering is deferred.
    public static let orderedCases: [Int] = [1, 2, 3, 4, 5, 6, 7]

    /// Three-letter abbreviation matching system formatters but stable
    /// across CI hosts (en_US_POSIX). Owner-facing only — locale support
    /// is deferred to v2.x.
    public static func shortLabel(for weekday: Int) -> String {
        switch weekday {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "?"
        }
    }

    /// One-line summary for the editor row. Special-cases common patterns
    /// (Mon-Fri, Sat-Sun, Daily) so the row stays readable at a glance.
    public static func summary(for weekdays: Set<Int>) -> String {
        if weekdays.isEmpty { return "Never" }
        if weekdays == Set([1, 2, 3, 4, 5, 6, 7]) { return "Every day" }
        if weekdays == Set([2, 3, 4, 5, 6]) { return "Weekdays" }
        if weekdays == Set([1, 7]) { return "Weekends" }
        return orderedCases
            .filter { weekdays.contains($0) }
            .map { shortLabel(for: $0) }
            .joined(separator: ", ")
    }
}
