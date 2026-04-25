import AppIntents
import Foundation

/// Toggle the awake state. Maps to a Shortcut you can add to Focus filters,
/// keyboard shortcuts, the Action Button on iPhone (via cross-device extension),
/// or run from Spotlight.
struct ToggleAwakeIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Caffeinated"
    static var description = IntentDescription("Toggle whether your Mac stays awake.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        AwakeManager.shared.toggle()
        return .result()
    }
}

/// Activate awake mode for a configurable number of minutes.
struct StartAwakeIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Caffeinated"
    static var description = IntentDescription("Keep your Mac awake for a specific duration.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Minutes", default: 30)
    var minutes: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        let duration: AwakeDuration = minutes <= 0 ? .indefinite : .minutes(minutes)
        AwakeManager.shared.activate(for: duration)
        return .result()
    }
}

/// Deactivate immediately. Equivalent to clicking off the menu bar toggle.
struct StopAwakeIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Caffeinated"
    static var description = IntentDescription("Allow your Mac to sleep again.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        AwakeManager.shared.deactivate()
        return .result()
    }
}

/// Surfaces the intents in Shortcuts/Spotlight without requiring user setup.
struct CaffeinatedShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleAwakeIntent(),
            phrases: [
                "Toggle \(.applicationName)",
                "Caffeinate my Mac with \(.applicationName)"
            ],
            shortTitle: "Toggle Caffeinated",
            systemImageName: "cup.and.saucer.fill"
        )
        AppShortcut(
            intent: StartAwakeIntent(),
            phrases: [
                "Start \(.applicationName)",
                "Keep my Mac awake with \(.applicationName)"
            ],
            shortTitle: "Start Caffeinated",
            systemImageName: "cup.and.saucer"
        )
        AppShortcut(
            intent: StopAwakeIntent(),
            phrases: [
                "Stop \(.applicationName)",
                "Let my Mac sleep with \(.applicationName)"
            ],
            shortTitle: "Stop Caffeinated",
            systemImageName: "powersleep"
        )
    }
}
