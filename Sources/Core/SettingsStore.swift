import Foundation
import os

public enum SettingsKey: String, CaseIterable, Sendable {
    // Versioning
    case schemaVersion         = "latte.schemaVersion"
    case firstRunCompleted     = "latte.firstRunCompleted"
    case firstRunCompletedAt   = "latte.firstRunCompletedAt"
    case lastQuitCleanly       = "latte.lastQuitCleanly"

    // General preferences
    case allowDisplaySleep     = "latte.allowDisplaySleep"
    case activateOnLaunch      = "latte.activateOnLaunch"
    case launchAtLogin         = "latte.launchAtLogin"
    case menuBarIconStyle      = "latte.menuBarIconStyle"
    case coffeeAccent          = "latte.coffeeAccent"

    // Calendar trigger
    case calendarTriggerEnabled            = "latte.calendarTrigger.enabled"
    case calendarTriggerCalendarIDs        = "latte.calendarTrigger.calendarIDs"
    case calendarTriggerExcludeAllDay      = "latte.calendarTrigger.excludeAllDay"
    case calendarTriggerLeadTimeMinutes    = "latte.calendarTrigger.leadTimeMinutes"
    case calendarTriggerTrailingMinutes    = "latte.calendarTrigger.trailingMinutes"

    // App-presence trigger
    case appTriggerEnabled         = "latte.appTrigger.enabled"
    case appTriggerBundleIDs       = "latte.appTrigger.bundleIDs"
    case hasSeededAppDefaults      = "latte.appTrigger.hasSeededDefaults"

    // Wi-Fi trigger
    case wifiTriggerEnabled        = "latte.wifiTrigger.enabled"
    case wifiTriggerSSIDs          = "latte.wifiTrigger.ssids"
    case wifiTriggerInverseLogic   = "latte.wifiTrigger.inverseLogic"

    // Focus trigger
    case focusTriggerEnabled   = "latte.focusTrigger.enabled"
    case focusTriggerFocusIDs  = "latte.focusTrigger.focusIDs"

    // Schedule trigger (V2-05)
    case scheduleTriggerEnabled = "latte.scheduleTrigger.enabled"
    case scheduleTriggerEntries = "latte.scheduleTrigger.entries"

    // External-display trigger (V2-06) — v1.2
    /// When true and at least one external display is connected, vote awake.
    /// Default off so installs don't change behaviour for users who never opt in.
    case externalDisplayEnabled = "latte.externalDisplayTrigger.enabled"

    // Battery-aware mode (C-1) and pause-all (C-9) — v1.1
    case requireACForAwake      = "latte.requireACForAwake"
    case triggersPaused         = "latte.triggersPaused"

    // Global keyboard shortcut (B1) — v1.1
    /// When true, the configured chord globally toggles Latte awake/asleep.
    /// Off by default to avoid stomping a system-wide chord on first launch.
    case keyboardShortcutEnabled = "latte.keyboardShortcut.enabled"

    // Custom keyboard-shortcut chord (B1.2) — v1.2
    /// JSON-encoded `KeyChord`; nil/missing → falls back to the default ⌘⇧L.
    /// Persisted only after the user actually customises the chord; stays
    /// absent for fresh installs (silent-default migration per 07-spec §8 Q4).
    case shortcutChord = "latte.keyboardShortcut.chord"

    // Activity history retention (C-3 deferred F) — v1.3.1
    /// Days of activity history to retain. Default 14, valid range 1…90 —
    /// values outside the range fall back to 14 via `clampedInteger`.
    case activityRetentionDays = "latte.activityHistory.retentionDays"
}

public protocol SettingsStore: AnyObject {
    func bool(_ key: SettingsKey, default defaultValue: Bool) -> Bool
    func setBool(_ value: Bool, for key: SettingsKey)
    func string(_ key: SettingsKey) -> String?
    func setString(_ value: String?, for key: SettingsKey)
    func integer(_ key: SettingsKey, default defaultValue: Int) -> Int
    func setInteger(_ value: Int, for key: SettingsKey)
    func double(_ key: SettingsKey, default defaultValue: Double) -> Double
    func setDouble(_ value: Double, for key: SettingsKey)
    func data(_ key: SettingsKey) -> Data?
    func setData(_ value: Data?, for key: SettingsKey)
    func remove(_ key: SettingsKey)
}

public extension SettingsStore {
    func decodeStringArray(_ key: SettingsKey) -> [String] {
        guard let raw = data(key) else { return [] }
        guard let decoded = try? JSONDecoder().decode([String].self, from: raw) else {
            settingsLogger.notice("settings key \(key.rawValue, privacy: .public) failed to decode as [String]; using default")
            return []
        }
        return decoded
    }

    func encodeStringArray(_ value: [String], for key: SettingsKey) {
        let encoded = try? JSONEncoder().encode(value)
        setData(encoded, for: key)
    }

    func clampedInteger(_ key: SettingsKey, default defaultValue: Int, range: ClosedRange<Int>) -> Int {
        let raw = integer(key, default: defaultValue)
        if range.contains(raw) { return raw }
        settingsLogger.notice("settings key \(key.rawValue, privacy: .public) value \(raw) out of range \(range.lowerBound)…\(range.upperBound); using default")
        return defaultValue
    }
}

let settingsLogger = Logger(subsystem: "com.parkbyeongjun.latte", category: "settings")

public final class UserDefaultsSettingsStore: SettingsStore {

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func bool(_ key: SettingsKey, default defaultValue: Bool) -> Bool {
        guard let object = defaults.object(forKey: key.rawValue) else { return defaultValue }
        if let value = object as? Bool { return value }
        if let value = object as? NSNumber { return value.boolValue }
        settingsLogger.notice("settings key \(key.rawValue, privacy: .public) had unexpected type, using default")
        return defaultValue
    }

    public func setBool(_ value: Bool, for key: SettingsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    public func string(_ key: SettingsKey) -> String? {
        guard let object = defaults.object(forKey: key.rawValue) else { return nil }
        if let value = object as? String { return value }
        settingsLogger.notice("settings key \(key.rawValue, privacy: .public) had unexpected type, using default")
        return nil
    }

    public func setString(_ value: String?, for key: SettingsKey) {
        if let value {
            defaults.set(value, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    public func integer(_ key: SettingsKey, default defaultValue: Int) -> Int {
        guard let object = defaults.object(forKey: key.rawValue) else { return defaultValue }
        if let value = object as? Int { return value }
        if let value = object as? NSNumber { return value.intValue }
        settingsLogger.notice("settings key \(key.rawValue, privacy: .public) had unexpected type, using default")
        return defaultValue
    }

    public func setInteger(_ value: Int, for key: SettingsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    public func double(_ key: SettingsKey, default defaultValue: Double) -> Double {
        guard let object = defaults.object(forKey: key.rawValue) else { return defaultValue }
        if let value = object as? Double { return value }
        if let value = object as? NSNumber { return value.doubleValue }
        settingsLogger.notice("settings key \(key.rawValue, privacy: .public) had unexpected type, using default")
        return defaultValue
    }

    public func setDouble(_ value: Double, for key: SettingsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    public func data(_ key: SettingsKey) -> Data? {
        guard let object = defaults.object(forKey: key.rawValue) else { return nil }
        if let value = object as? Data { return value }
        settingsLogger.notice("settings key \(key.rawValue, privacy: .public) had unexpected type, using default")
        return nil
    }

    public func setData(_ value: Data?, for key: SettingsKey) {
        if let value {
            defaults.set(value, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    public func remove(_ key: SettingsKey) {
        defaults.removeObject(forKey: key.rawValue)
    }
}

public final class InMemorySettingsStore: SettingsStore {

    private var storage: [String: Any] = [:]

    public init(initial: [SettingsKey: Any] = [:]) {
        for (key, value) in initial { storage[key.rawValue] = value }
    }

    public func bool(_ key: SettingsKey, default defaultValue: Bool) -> Bool {
        guard let raw = storage[key.rawValue] else { return defaultValue }
        if let value = raw as? Bool { return value }
        return defaultValue
    }

    public func setBool(_ value: Bool, for key: SettingsKey) {
        storage[key.rawValue] = value
    }

    public func string(_ key: SettingsKey) -> String? {
        storage[key.rawValue] as? String
    }

    public func setString(_ value: String?, for key: SettingsKey) {
        if let value {
            storage[key.rawValue] = value
        } else {
            storage.removeValue(forKey: key.rawValue)
        }
    }

    public func integer(_ key: SettingsKey, default defaultValue: Int) -> Int {
        guard let raw = storage[key.rawValue] else { return defaultValue }
        if let value = raw as? Int { return value }
        return defaultValue
    }

    public func setInteger(_ value: Int, for key: SettingsKey) {
        storage[key.rawValue] = value
    }

    public func double(_ key: SettingsKey, default defaultValue: Double) -> Double {
        guard let raw = storage[key.rawValue] else { return defaultValue }
        if let value = raw as? Double { return value }
        return defaultValue
    }

    public func setDouble(_ value: Double, for key: SettingsKey) {
        storage[key.rawValue] = value
    }

    public func data(_ key: SettingsKey) -> Data? {
        storage[key.rawValue] as? Data
    }

    public func setData(_ value: Data?, for key: SettingsKey) {
        if let value {
            storage[key.rawValue] = value
        } else {
            storage.removeValue(forKey: key.rawValue)
        }
    }

    public func remove(_ key: SettingsKey) {
        storage.removeValue(forKey: key.rawValue)
    }
}
