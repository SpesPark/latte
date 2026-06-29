import Foundation
import os

public enum LatteLog {
    public static let subsystem = "com.araforge.latte"

    public static func logger(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }

    public static let awake = logger("awake")
    public static let triggers = logger("triggers")
    public static let calendar = logger("trigger.calendar")
    public static let app = logger("trigger.app")
    public static let wifi = logger("trigger.wifi")
    public static let focus = logger("trigger.focus")
    public static let schedule = logger("trigger.schedule")
    public static let display = logger("trigger.display")
    public static let powerSource = logger("power.source")
    public static let shortcut = logger("shortcut")
    public static let intents = logger("intents")
    public static let ui = logger("ui")
    public static let activity = logger("activity")
}
