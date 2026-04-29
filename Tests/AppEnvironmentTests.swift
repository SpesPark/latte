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

    // MARK: - Activate-on-launch ⇆ SettingsStore mirror

    func testActivateOnLaunchDefaultsToFalse() {
        let env = AppEnvironment(settings: InMemorySettingsStore())
        XCTAssertFalse(env.activateOnLaunch)
    }

    func testActivateOnLaunchHydratesFromStoredValue() {
        let store = InMemorySettingsStore()
        store.setBool(true, for: .activateOnLaunch)
        let env = AppEnvironment(settings: store)
        XCTAssertTrue(env.activateOnLaunch)
    }

    func testActivateOnLaunchAssignmentWritesThroughToStore() {
        let store = InMemorySettingsStore()
        let env = AppEnvironment(settings: store)
        env.activateOnLaunch = true
        XCTAssertTrue(store.bool(.activateOnLaunch, default: false))
        env.activateOnLaunch = false
        XCTAssertFalse(store.bool(.activateOnLaunch, default: true))
    }

    func testActivateOnLaunchNoOpAssignmentDoesNotTouchStore() {
        let store = InMemorySettingsStore()
        store.setBool(true, for: .activateOnLaunch)
        let env = AppEnvironment(settings: store)
        store.remove(.activateOnLaunch) // simulate someone wiping the key after init
        env.activateOnLaunch = true     // assign the same already-loaded value
        XCTAssertFalse(store.bool(.activateOnLaunch, default: false),
                       "Equal-value assignment must not re-persist")
    }

    // MARK: - applyActivateOnLaunchIfEnabled gating

    func testApplyActivateOnLaunchIsNoOpWhenFlagDisabled() {
        let store = InMemorySettingsStore()
        store.setBool(true, for: .firstRunCompleted) // satisfy the onboarding gate
        let env = AppEnvironment(settings: store)
        AwakeManager.shared.deactivate() // ensure clean baseline
        env.applyActivateOnLaunchIfEnabled()
        XCTAssertFalse(env.manager.isAwake,
                       "flag-off must leave manager untouched")
    }

    func testApplyActivateOnLaunchIsNoOpWhenOnboardingIncomplete() {
        let store = InMemorySettingsStore()
        store.setBool(true, for: .activateOnLaunch)
        // firstRunCompleted intentionally NOT set — onboarding gate must
        // suppress the activation so a brand-new install doesn't auto-awake
        // before the user finishes the wizard.
        let env = AppEnvironment(settings: store)
        AwakeManager.shared.deactivate()
        env.applyActivateOnLaunchIfEnabled()
        XCTAssertFalse(env.manager.isAwake,
                       "onboarding-incomplete must suppress launch activation")
    }

    func testApplyActivateOnLaunchActivatesUnderLaunchReasonWhenEnabled() {
        let store = InMemorySettingsStore()
        store.setBool(true, for: .activateOnLaunch)
        store.setBool(true, for: .firstRunCompleted)
        let env = AppEnvironment(settings: store)
        AwakeManager.shared.deactivate()
        env.applyActivateOnLaunchIfEnabled()
        XCTAssertTrue(env.manager.isAwake)
        XCTAssertEqual(env.manager.activeReason, .launch)
        // Cleanup: leave the shared manager in a known state for downstream
        // tests that might run in the same process.
        AwakeManager.shared.deactivate()
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
