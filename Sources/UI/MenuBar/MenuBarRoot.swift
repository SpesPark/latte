import AppKit
import SwiftUI

public struct MenuBarRoot: View {

    @ObservedObject public var manager: AwakeManager
    @EnvironmentObject private var environment: AppEnvironment

    @State private var customExpanded: Bool = false
    @State private var customMinutes: Int = 60

    /// Natural height of `middleContent`, measured from a hidden copy (see
    /// `body`). Seeded so the first frame decides correctly before the geometry
    /// read lands. Used ONLY to decide whether the content is taller than the
    /// screen and must scroll (`MenuBarLayout.needsScroll`) — never to size the
    /// displayed content, so an under-report can't clip rows.
    @State private var measuredContentHeight: CGFloat = MenuBarLayout.seedContentHeight

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
        // Guideline 4 truncation fix: when the content fits the screen it is
        // rendered at NATURAL size — the popover window hugs it (grows / shrinks
        // with the Custom row, no gap, no scrollbar) and every row is shown.
        // Only when the content is taller than the screen does it fall back to a
        // ScrollView capped at the screen, so the pinned Settings / Quit footer
        // stays reachable on notched 14"/16" displays.
        //
        // A hidden, fixedSize copy of `middleContent` measures its natural
        // height; that measurement is used ONLY to decide whether to scroll
        // (`needsScroll`), never to size the displayed content — driving the
        // displayed height from the measurement clipped rows when it
        // under-reported (owner saw the last preset cut off), and the
        // MenuBarExtra window can't be smoothly frame-animated anyway.
        //
        // Use the SMALLEST visibleFrame across all screens, not `NSScreen.main`:
        // this is an LSUIElement app, so `NSScreen.main` (the key-window screen)
        // is unreliable, and with "Displays have separate Spaces" the popover
        // can open on any display. Sizing for the smallest display guarantees
        // the footer stays on-screen wherever the popover lands.
        let screenHeight = NSScreen.screens
            .map(\.visibleFrame.height)
            .min() ?? MenuBarLayout.fallbackScreenHeight
        let needsScroll = MenuBarLayout.needsScroll(
            measuredContentHeight: measuredContentHeight,
            visibleScreenHeight: screenHeight
        )

        return VStack(spacing: 0) {
            HeaderView(manager: manager)

            Divider().opacity(0.5)

            // When the content fits the screen, render it at natural size so the
            // popover window grows / shrinks with it (no fixed window, no
            // scrollbar) and every row is shown. Driving the displayed height
            // from the runtime measurement instead clips content when the
            // measurement under-reports (owner saw the last preset row cut off),
            // so the measurement is used ONLY to decide whether to scroll. Only
            // when the content is taller than the screen does it scroll, capped
            // so the Settings / Quit footer below stays reachable.
            Group {
                if needsScroll {
                    ScrollView { middleContent }
                        .frame(height: MenuBarLayout.maxScrollHeight(forVisibleScreenHeight: screenHeight))
                } else {
                    middleContent
                }
            }
            // Measure the middle section's natural height from a hidden copy
            // forced to its ideal size — independent of whether the visible copy
            // is scrolling, so it reports the true content height (never 0) and
            // drives the scroll decision above.
            .background(
                middleContent
                    .frame(width: Theme.Sizes.menuBarWidth)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .allowsHitTesting(false)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: MenuBarContentHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    )
            )

            Divider().opacity(0.5)

            settingsFooter
        }
        .frame(width: Theme.Sizes.menuBarWidth)
        // Animate the content layout when the Custom row expands / collapses.
        // NOTE: the MenuBarExtra(.window) window itself resizes in one step
        // (AppKit snaps the popover window to the content's final size); the
        // SwiftUI animation here smooths the inner content. Forcing the window
        // frame to animate requires pinning an explicit measured height, which
        // clips content when the measurement under-reports — so we keep natural
        // sizing (every row shown) and animate only what reliably animates.
        .animation(.easeInOut(duration: 0.18), value: customExpanded)
        .liquidGlassBackground()
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
        .onPreferenceChange(MenuBarContentHeightKey.self) { height in
            if height > 0 { measuredContentHeight = height }
        }
    }

    // MARK: - Sections

    /// The scrollable middle: pause toggle + durations + recurring presets +
    /// Turn off. Defined once and rendered twice — visibly in the ScrollView,
    /// and hidden in `.background` purely to measure its natural height.
    private var middleContent: some View {
        VStack(spacing: 0) {
            pauseTriggersRow

            Divider().opacity(0.5)

            durationsSection

            Divider().opacity(0.5)

            recurringSection

            turnOffButton
        }
    }

    private var durationsSection: some View {
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
    }

    // C-7 wall-clock target presets — seed-then-mutable model (S19 #2). The
    // three legacy rows (until 5 PM / 11 PM / midnight) seed once into
    // `recurringQuickPresets` at first launch and become editable like any
    // user preset. Filtered by today's weekday — Mon-Fri preset never shows
    // Saturday. Click → minutes-from-now → activate(.minutes(N)).
    // Owner-cleared → empty section, popover stays clean (no trailing divider).
    @ViewBuilder
    private var recurringSection: some View {
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
    }

    private var turnOffButton: some View {
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
    }

    // S26 / B6 (S22 P-issue-4 close-out): `.keyboardShortcut(...)` doesn't
    // reach the `MenuBarExtra(.window)` popover, so we install an
    // `NSEvent.addLocalMonitorForEvents(.keyDown)` in `.onAppear` (scoped to
    // popover open/close) that maps ⌘Q → Quit via `PopoverKeyHandler.decide`.
    // The monitor is removed on `.onDisappear`. S27: ⌘, popover binding
    // removed (low-value — popover is already mouse-bound). Only ⌘Q remains.
    // Pinned outside the ScrollView so it is always reachable (Guideline 4).
    private var settingsFooter: some View {
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

    private func installKeyMonitor() {
        // Idempotent: in case `.onAppear` fires twice for the same
        // popover instance, only one monitor stays installed.
        if keyMonitor != nil { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch PopoverKeyHandler.decide(
                modifiers: event.modifierFlags,
                character: event.charactersIgnoringModifiers
            ) {
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

/// Carries the measured natural height of `middleContent` up to `MenuBarRoot`
/// so the ScrollView can hug the content. Part of the Guideline 4 truncation
/// fix.
private struct MenuBarContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // Single emitter (one hidden measurement copy); take the latest.
        value = nextValue()
    }
}
