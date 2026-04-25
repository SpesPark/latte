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

    // MARK: - Trigger registration

    func testRegistersFourDefaultTriggers() {
        let env = AppEnvironment(settings: InMemorySettingsStore())
        let ids = env.coordinator.triggers.map(\.id)
        XCTAssertEqual(Set(ids), Set(["calendar", "app", "wifi", "focus"]))
    }
}
