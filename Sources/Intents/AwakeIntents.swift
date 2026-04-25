import AppIntents
import Foundation

public struct ToggleAwakeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Toggle Latte"
    public static var description = IntentDescription("Toggle Latte awake/asleep state.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        AwakeManager.shared.toggle()
        return .result()
    }
}

public struct StartAwakeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Latte"
    public static var description = IntentDescription("Keep the Mac awake for a duration.")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Minutes", default: 30, inclusiveRange: (1, 24 * 60))
    public var minutes: Int

    public init() {}
    public init(minutes: Int) { self.minutes = minutes }

    @MainActor
    public func perform() async throws -> some IntentResult {
        AwakeManager.shared.activate(for: .minutes(minutes))
        return .result()
    }
}

public struct StopAwakeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Stop Latte"
    public static var description = IntentDescription("Allow the Mac to sleep again.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        AwakeManager.shared.deactivate()
        return .result()
    }
}

public struct LatteShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleAwakeIntent(),
            phrases: [
                "Toggle \(.applicationName)",
                "Switch \(.applicationName)"
            ],
            shortTitle: "Toggle",
            systemImageName: "cup.and.saucer.fill"
        )
        AppShortcut(
            intent: StartAwakeIntent(),
            phrases: [
                "Start \(.applicationName)",
                "Keep awake with \(.applicationName)"
            ],
            shortTitle: "Start",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: StopAwakeIntent(),
            phrases: [
                "Stop \(.applicationName)",
                "Sleep with \(.applicationName)"
            ],
            shortTitle: "Stop",
            systemImageName: "stop.fill"
        )
    }
}
