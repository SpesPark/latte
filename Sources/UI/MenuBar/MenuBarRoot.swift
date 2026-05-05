import AppKit
import SwiftUI

public struct MenuBarRoot: View {

    @ObservedObject public var manager: AwakeManager
    @EnvironmentObject private var environment: AppEnvironment

    @State private var customExpanded: Bool = false
    @State private var customMinutes: Int = 60

    /// Local NSEvent monitor token, installed in `.onAppear` (popover
    /// open) and removed in `.onDisappear` (popover close). Carries
    /// ⌘, → Settings and ⌘Q → Quit through a key-event handler since
    /// SwiftUI `.keyboardShortcut(...)` doesn't fire inside the
    /// `MenuBarExtra(.window)` popover (S26 / B6 — S22 P-issue-4).
    @State private var keyMonitor: Any?

    public init(manager: AwakeManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 0) {
            HeaderView(manager: manager)

            Divider().opacity(0.5)

            pauseTriggersRow

            Divider().opacity(0.5)

            VStack(spacing: 0) {
                ForEach(AwakeDuration.presets, id: \.label) { duration in
                    DurationPickerRow(
                        duration: duration,
                        isActive: manager.activeDuration == duration && manager.isAwake,
                        action: { manager.activate(for: duration) }
                    )
                }
                CustomDurationRow(
                    isExpanded: $customExpanded,
                    minutes: $customMinutes,
                    // S23 / P-issue-2: AND `activeRecurringPresetID == nil` so a
                    // preset-driven `.minutes(N)` (which is also "unlisted") doesn't
                    // poach the Custom row's checkmark — the recurring preset row
                    // owns the marker via its own `isActive`.
                    isActive: manager.isAwake
                        && isUnlistedCustomDuration(manager.activeDuration)
                        && manager.activeRecurringPresetID == nil,
                    onStart: {
                        manager.activate(for: .minutes(customMinutes))
                    }
                )
            }
            .padding(.vertical, 2)

            Divider().opacity(0.5)

            // C-7 wall-clock target presets — seed-then-mutable model
            // (S19 #2). The three legacy rows (until 5 PM / 11 PM /
            // midnight) seed once into `recurringQuickPresets` at first
            // launch and become editable like any user preset. Filtered
            // by today's weekday — Mon-Fri preset never shows Saturday.
            // Click → minutes-from-now → activate(.minutes(N)).
            // Owner-cleared → empty section, popover stays clean.
            let activePresets = environment.recurringQuickPresets
                .filter { $0.isActiveOn(date: .now) }
            if !activePresets.isEmpty {
                VStack(spacing: 0) {
                    ForEach(activePresets) { preset in
                        RecurringQuickPresetRow(
                            preset: preset,
                            isActive: manager.isAwake
                                && manager.activeRecurringPresetID == preset.id,
                            action: {
                                let mins = preset.minutes(from: .now)
                                // S23 / P-issue-2: tag the activation so the
                                // popover shows the checkmark on this row,
                                // not on Custom.
                                manager.activate(for: .minutes(mins), fromRecurringPreset: preset.id)
                            }
                        )
                    }
                }
                .padding(.vertical, 2)

                Divider().opacity(0.5)
            }

            Button(role: .destructive, action: { manager.deactivate() }) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 13))
                        .frame(width: 16)
                    Text("Turn off")
                        .font(Theme.Fonts.body)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!manager.isAwake)
            .opacity(manager.isAwake ? 1.0 : 0.45)

            Divider().opacity(0.5)

            // S26 / B6 (S22 P-issue-4 close-out): `.keyboardShortcut(...)`
            // doesn't reach the `MenuBarExtra(.window)` popover, so we
            // install an `NSEvent.addLocalMonitorForEvents(.keyDown)` in
            // `.onAppear` below (scoped to popover open/close) that maps
            // ⌘, → Settings and ⌘Q → Quit via `PopoverKeyHandler.decide`.
            // The monitor is removed on `.onDisappear` so the keys go
            // back to their default no-op behaviour outside the popover.
            HStack {
                Button(action: openSettings) {
                    Text("Settings…")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: { NSApp.terminate(nil) }) {
                    Text("Quit")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .font(Theme.Fonts.caption)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .frame(width: Theme.Sizes.menuBarWidth)
        .liquidGlassBackground()
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }

    private func installKeyMonitor() {
        // Idempotent: in case `.onAppear` fires twice for the same
        // popover instance, only one monitor stays installed.
        if keyMonitor != nil { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch PopoverKeyHandler.decide(
                modifiers: event.modifierFlags,
                character: event.charactersIgnoringModifiers
            ) {
            case .openSettings:
                openSettings()
                return nil   // consume
            case .quit:
                NSApp.terminate(nil)
                return nil   // consume (terminate is async, so be explicit)
            case .passthrough:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    @ViewBuilder
    private var pauseTriggersRow: some View {
        Toggle(isOn: $manager.triggersPaused) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: manager.triggersPaused ? "pause.circle.fill" : "pause.circle")
                    .font(.system(size: 13))
                    .frame(width: 16)
                    .foregroundStyle(manager.triggersPaused ? environment.coffeeAccent.color : .secondary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(manager.triggersPaused ? "Triggers paused" : "Pause triggers")
                        .font(Theme.Fonts.body)
                    Text(manager.triggersPaused
                         ? "Manual activation still works."
                         : "Ignore Calendar / App / Wi\u{2011}Fi / Schedule votes.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityIdentifier("menubar.pauseTriggers")
    }

    private func isUnlistedCustomDuration(_ d: AwakeDuration?) -> Bool {
        guard let d else { return false }
        return !AwakeDuration.presets.contains(d)
    }

    private func openSettings() {
        SettingsWindowController.shared.show(
            manager: environment.manager,
            coordinator: environment.coordinator,
            environment: environment
        )
    }
}
