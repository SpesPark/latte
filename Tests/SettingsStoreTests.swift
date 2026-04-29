import XCTest
@testable import Latte

/// Parametrized base — each impl runs the same suite by overriding `makeStore`.
class SettingsStoreContractTests: XCTestCase {

    func makeStore() -> SettingsStore {
        InMemorySettingsStore()
    }

    func testBoolRoundTrip() {
        let store = makeStore()
        XCTAssertTrue(store.bool(.allowDisplaySleep, default: true))
        store.setBool(false, for: .allowDisplaySleep)
        XCTAssertFalse(store.bool(.allowDisplaySleep, default: true))
        store.setBool(true, for: .allowDisplaySleep)
        XCTAssertTrue(store.bool(.allowDisplaySleep, default: false))
    }

    func testStringRoundTrip() {
        let store = makeStore()
        XCTAssertNil(store.string(.menuBarIconStyle))
        store.setString("outline", for: .menuBarIconStyle)
        XCTAssertEqual(store.string(.menuBarIconStyle), "outline")
        store.setString(nil, for: .menuBarIconStyle)
        XCTAssertNil(store.string(.menuBarIconStyle))
    }

    func testIntegerRoundTrip() {
        let store = makeStore()
        XCTAssertEqual(store.integer(.calendarTriggerLeadTimeMinutes, default: 0), 0)
        store.setInteger(7, for: .calendarTriggerLeadTimeMinutes)
        XCTAssertEqual(store.integer(.calendarTriggerLeadTimeMinutes, default: 0), 7)
    }

    func testDataRoundTrip() {
        let store = makeStore()
        XCTAssertNil(store.data(.appTriggerBundleIDs))
        let payload = Data([0xDE, 0xAD, 0xBE, 0xEF])
        store.setData(payload, for: .appTriggerBundleIDs)
        XCTAssertEqual(store.data(.appTriggerBundleIDs), payload)
        store.setData(nil, for: .appTriggerBundleIDs)
        XCTAssertNil(store.data(.appTriggerBundleIDs))
    }

    func testStringArrayRoundTrip() {
        let store = makeStore()
        XCTAssertEqual(store.decodeStringArray(.appTriggerBundleIDs), [])
        let ids = ["us.zoom.xos", "com.tinyspeck.slackmacgap"]
        store.encodeStringArray(ids, for: .appTriggerBundleIDs)
        XCTAssertEqual(store.decodeStringArray(.appTriggerBundleIDs), ids)
    }

    func testStringArrayCorruptionFallsBackToDefault() {
        let store = makeStore()
        // Write garbage as Data — decode should fail and return [].
        store.setData(Data([0x01, 0x02, 0x03]), for: .appTriggerBundleIDs)
        XCTAssertEqual(store.decodeStringArray(.appTriggerBundleIDs), [])
    }

    func testClampedIntegerOutOfRangeReturnsDefault() {
        let store = makeStore()
        store.setInteger(99, for: .calendarTriggerLeadTimeMinutes)
        XCTAssertEqual(store.clampedInteger(.calendarTriggerLeadTimeMinutes, default: 0, range: 0...15), 0)
    }

    func testClampedIntegerInRangeReturnsValue() {
        let store = makeStore()
        store.setInteger(10, for: .calendarTriggerLeadTimeMinutes)
        XCTAssertEqual(store.clampedInteger(.calendarTriggerLeadTimeMinutes, default: 0, range: 0...15), 10)
    }

    func testRemoveRestoresDefault() {
        let store = makeStore()
        store.setBool(true, for: .activateOnLaunch)
        XCTAssertTrue(store.bool(.activateOnLaunch, default: false))
        store.remove(.activateOnLaunch)
        XCTAssertFalse(store.bool(.activateOnLaunch, default: false))
    }

    func testDoubleRoundTrip() {
        let store = makeStore()
        XCTAssertEqual(store.double(.calendarTriggerLeadTimeMinutes, default: 1.5), 1.5)
        store.setDouble(3.14, for: .calendarTriggerLeadTimeMinutes)
        XCTAssertEqual(store.double(.calendarTriggerLeadTimeMinutes, default: 0), 3.14, accuracy: 0.0001)
    }

    func testBoolTypeMismatchFallsBackToDefault() {
        let store = makeStore()
        store.setString("not-a-bool", for: .allowDisplaySleep)
        XCTAssertTrue(store.bool(.allowDisplaySleep, default: true))
        XCTAssertFalse(store.bool(.allowDisplaySleep, default: false))
    }

    func testStringTypeMismatchReturnsNil() {
        let store = makeStore()
        store.setInteger(42, for: .menuBarIconStyle)
        XCTAssertNil(store.string(.menuBarIconStyle))
    }

    func testIntegerTypeMismatchFallsBackToDefault() {
        let store = makeStore()
        store.setString("not-an-int", for: .calendarTriggerLeadTimeMinutes)
        XCTAssertEqual(store.integer(.calendarTriggerLeadTimeMinutes, default: 7), 7)
    }

    func testDoubleTypeMismatchFallsBackToDefault() {
        let store = makeStore()
        store.setString("not-a-double", for: .calendarTriggerLeadTimeMinutes)
        XCTAssertEqual(store.double(.calendarTriggerLeadTimeMinutes, default: 9.5), 9.5)
    }

    func testDataTypeMismatchReturnsNil() {
        let store = makeStore()
        store.setString("not-data", for: .appTriggerBundleIDs)
        XCTAssertNil(store.data(.appTriggerBundleIDs))
    }
}

final class InMemorySettingsStoreTests: SettingsStoreContractTests {
    override func makeStore() -> SettingsStore {
        InMemorySettingsStore()
    }
}

final class UserDefaultsSettingsStoreTests: SettingsStoreContractTests {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    override func makeStore() -> SettingsStore {
        UserDefaultsSettingsStore(defaults: defaults)
    }
}

final class SettingsKeyEnumTests: XCTestCase {

    /// Every key must use the `latte.` prefix per 04-data-model.md §3.1.
    func testAllKeysAreLattePrefixed() {
        for key in SettingsKey.allCases {
            XCTAssertTrue(key.rawValue.hasPrefix("latte."), "key \(key.rawValue) missing latte. prefix")
        }
    }

    /// Keys defined in 04 §5 must all exist.
    func testRequiredKeysExist() {
        let required: Set<String> = [
            "latte.schemaVersion",
            "latte.firstRunCompleted",
            "latte.firstRunCompletedAt",
            "latte.lastQuitCleanly",
            "latte.allowDisplaySleep",
            "latte.activateOnLaunch",
            "latte.launchAtLogin",
            "latte.menuBarIconStyle",
            "latte.coffeeAccent",
            "latte.calendarTrigger.enabled",
            "latte.calendarTrigger.calendarIDs",
            "latte.calendarTrigger.excludeAllDay",
            "latte.calendarTrigger.leadTimeMinutes",
            "latte.calendarTrigger.trailingMinutes",
            "latte.appTrigger.enabled",
            "latte.appTrigger.bundleIDs",
            "latte.appTrigger.hasSeededDefaults",
            "latte.wifiTrigger.enabled",
            "latte.wifiTrigger.ssids",
            "latte.wifiTrigger.inverseLogic",
            "latte.focusTrigger.enabled",
            "latte.focusTrigger.focusIDs",
            "latte.scheduleTrigger.enabled",
            "latte.scheduleTrigger.entries",
            "latte.externalDisplayTrigger.enabled",
            "latte.requireACForAwake",
            "latte.triggersPaused",
            "latte.keyboardShortcut.enabled"
        ]
        let actual = Set(SettingsKey.allCases.map { $0.rawValue })
        XCTAssertEqual(actual, required)
    }
}

final class AppTriggerDefaultsTests: XCTestCase {

    func testCuratedBundleIDsContainExpected() {
        let ids = AppTriggerDefaults.bundleIDs
        XCTAssertTrue(ids.contains("us.zoom.xos"))
        XCTAssertTrue(ids.contains("com.microsoft.teams2"))
        XCTAssertTrue(ids.contains("com.cisco.webex.meetings"))
        XCTAssertTrue(ids.contains("com.hnc.Discord"))
        XCTAssertTrue(ids.contains("com.tinyspeck.slackmacgap"))
    }

    func testSanitizeAcceptsValidBundleIDs() {
        let valid = ["us.zoom.xos", "com.example.app-name"]
        XCTAssertEqual(AppTriggerDefaults.sanitize(valid), valid)
    }

    func testSanitizeRejectsInvalidCharacters() {
        let mixed = ["us.zoom.xos", "bad/id", "with space", "ok.id"]
        XCTAssertEqual(AppTriggerDefaults.sanitize(mixed), ["us.zoom.xos", "ok.id"])
    }

    func testSanitizeRejectsTooLong() {
        let long = String(repeating: "a", count: 201)
        XCTAssertTrue(AppTriggerDefaults.sanitize([long]).isEmpty)
    }

    func testSanitizeRejectsEmpty() {
        XCTAssertTrue(AppTriggerDefaults.sanitize([""]).isEmpty)
    }
}
