import XCTest
@testable import Latte

@MainActor
final class AppEnvironmentTests: XCTestCase {

    // MARK: - Menu bar icon style ⇆ SettingsStore mirror

    func testMenuBarIconStyleDefaultsToFilledWhenNoneStored() {
        let store = InMemorySettingsStore()
        let env = AppEnvironment(settings: store)
        XCTAssertEqual(env.menuBarIconStyle, .filled)
    }

    func testMenuBarIconStyleHydratesFromStoredString() {
        let store = InMemorySettingsStore(initial: [.menuBarIconStyle: "outline"])
        let env = AppEnvironment(settings: store)
        XCTAssertEqual(env.menuBarIconStyle, .outline)
    }

    func testMenuBarIconStyleFallsBackToDefaultOnGarbage() {
        let store = InMemorySettingsStore(initial: [.menuBarIconStyle: "totally-bogus"])
        let env = AppEnvironment(settings: store)
        XCTAssertEqual(env.menuBarIconStyle, .filled,
                       "Unknown raw values should fall back to the default rather than crash")
    }

    func testMenuBarIconStyleAssignmentWritesThroughToStore() {
        let store = InMemorySettingsStore()
        let env = AppEnvironment(settings: store)

        env.menuBarIconStyle = .clock
        XCTAssertEqual(store.string(.menuBarIconStyle), "clock")

        env.menuBarIconStyle = .outline
        XCTAssertEqual(store.string(.menuBarIconStyle), "outline")
    }

    func testMenuBarIconStyleNoOpAssignmentDoesNotTouchStore() {
        // Persisted with explicit value `outline`. Assigning the same value
        // should not re-write — `didSet` short-circuits on equality. This
        // matters for `@Published` debouncing and reduces UserDefaults churn.
        let store = InMemorySettingsStore(initial: [.menuBarIconStyle: "outline"])
        let env = AppEnvironment(settings: store)
        store.remove(.menuBarIconStyle) // simulate someone wiping the key after init
        env.menuBarIconStyle = .outline // assign the same already-loaded value
        XCTAssertNil(store.string(.menuBarIconStyle),
                     "Equal-value assignment must not re-persist")
    }

    // MARK: - Coffee accent ⇆ SettingsStore mirror

    func testCoffeeAccentDefaultsToEspressoWhenNoneStored() {
        let store = InMemorySettingsStore()
        let env = AppEnvironment(settings: store)
        XCTAssertEqual(env.coffeeAccent, .espresso)
    }

    func testCoffeeAccentHydratesFromStoredString() {
        let store = InMemorySettingsStore(initial: [.coffeeAccent: "caramel"])
        let env = AppEnvironment(settings: store)
        XCTAssertEqual(env.coffeeAccent, .caramel)
    }

    func testCoffeeAccentFallsBackToDefaultOnGarbage() {
        let store = InMemorySettingsStore(initial: [.coffeeAccent: "fluorescent-pink"])
        let env = AppEnvironment(settings: store)
        XCTAssertEqual(env.coffeeAccent, .espresso)
    }

    func testCoffeeAccentAssignmentWritesThroughToStore() {
        let store = InMemorySettingsStore()
        let env = AppEnvironment(settings: store)

        env.coffeeAccent = .mocha
        XCTAssertEqual(store.string(.coffeeAccent), "mocha")

        env.coffeeAccent = .latte
        XCTAssertEqual(store.string(.coffeeAccent), "latte")
    }

    func testCoffeeAccentNoOpAssignmentDoesNotTouchStore() {
        let store = InMemorySettingsStore(initial: [.coffeeAccent: "noir"])
        let env = AppEnvironment(settings: store)
        store.remove(.coffeeAccent)
        env.coffeeAccent = .noir
        XCTAssertNil(store.string(.coffeeAccent))
    }

    // MARK: - Trigger registration

    func testRegistersFourDefaultTriggers() {
        // S8b: FocusTrigger is intentionally not registered for v1.0
        // pending the Communication Notifications entitlement (V2-03b
        // in v2-backlog). Calendar/App/WiFi/Schedule cover the core wedge.
        let env = AppEnvironment(settings: InMemorySettingsStore())
        let ids = env.coordinator.triggers.map(\.id)
        XCTAssertEqual(Set(ids), Set(["calendar", "app", "wifi", "schedule"]))
        XCTAssertFalse(ids.contains("focus"),
                       "FocusTrigger must not be registered until V2-03b lands")
    }
}
