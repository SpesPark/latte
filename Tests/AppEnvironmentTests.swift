import XCTest
@testable import Latte

@MainActor
final class AppEnvironmentTests: XCTestCase {

    /// `AppEnvironment` deliberately routes through `AwakeManager.shared` so
    /// AppIntents (out-of-process) and the in-process app share one FSM.
    /// That means tests in this file all observe the same singleton state.
    /// Defensively reset it before AND after each test so a crash in one
    /// `applyActivateOnLaunchIfEnabled` test cannot leak awake state into
    /// the next.
    override func setUp() {
        super.setUp()
        // setUp/tearDown override nonisolated XCTestCase methods, so they stay
        // nonisolated even in a @MainActor class. XCTest runs them on the main
        // thread for a main-actor test case, so assumeIsolated is safe.
        MainActor.assumeIsolated { AwakeManager.shared.deactivate() }
    }

    override func tearDown() {
        MainActor.assumeIsolated { AwakeManager.shared.deactivate() }
        super.tearDown()
    }

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
        env.applyActivateOnLaunchIfEnabled()
        XCTAssertFalse(env.manager.isAwake,
                       "onboarding-incomplete must suppress launch activation")
    }

    func testApplyActivateOnLaunchActivatesUnderLaunchReasonWhenEnabled() {
        let store = InMemorySettingsStore()
        store.setBool(true, for: .activateOnLaunch)
        store.setBool(true, for: .firstRunCompleted)
        let env = AppEnvironment(settings: store)
        env.applyActivateOnLaunchIfEnabled()
        XCTAssertTrue(env.manager.isAwake)
        XCTAssertEqual(env.manager.activeReason, .launch)
        // tearDown deactivates the shared manager.
    }

    // MARK: - Trigger registration

    func testRegistersDefaultTriggers() {
        // S8b: FocusTrigger is intentionally not registered for v1.0
        // pending the Communication Notifications entitlement (V2-03b
        // in v2-backlog). Calendar/App/WiFi/Schedule cover the core wedge;
        // V2-06 ExternalDisplay joined for v1.2.
        let env = AppEnvironment(settings: InMemorySettingsStore())
        let ids = env.coordinator.triggers.map(\.id)
        XCTAssertEqual(Set(ids), Set(["calendar", "app", "wifi", "schedule", "external-display"]))
        XCTAssertFalse(ids.contains("focus"),
                       "FocusTrigger must not be registered until V2-03b lands")
    }

    // MARK: - F: activity retention plumbing (S15)

    func testActivityRetentionDaysDefaultsTo14() {
        let env = AppEnvironment(settings: InMemorySettingsStore())
        XCTAssertEqual(env.activityRetentionDays, 14)
    }

    func testActivityRetentionDaysHydratesFromStoredValue() {
        let store = InMemorySettingsStore(initial: [.activityRetentionDays: 30])
        let env = AppEnvironment(settings: store)
        XCTAssertEqual(env.activityRetentionDays, 30)
    }

    func testActivityRetentionDaysClampsOutOfRangeStoredValue() {
        // 0 (or negative) is meaningless; >90 days is unbounded write — both
        // fall back to the 14-day default rather than crash.
        let store = InMemorySettingsStore(initial: [.activityRetentionDays: 9999])
        let env = AppEnvironment(settings: store)
        XCTAssertEqual(env.activityRetentionDays, 14)
    }

    func testActivityRetentionDaysAssignmentWritesThroughToStore() {
        let store = InMemorySettingsStore()
        let env = AppEnvironment(settings: store)
        env.activityRetentionDays = 7
        XCTAssertEqual(store.integer(.activityRetentionDays, default: -1), 7)
    }

    func testActivityRetentionDaysAssignmentPropagatesToStore() async {
        let env = AppEnvironment(settings: InMemorySettingsStore())
        guard let actor = env.activityStore else {
            XCTFail("activityStore unexpectedly nil — sandbox boot failure?")
            return
        }
        env.activityRetentionDays = 1

        // didSet schedules a Task to update the actor — give it up to ~1s
        // (well over a single MainActor → actor hop) before asserting.
        let target: TimeInterval = 86_400
        var observed: TimeInterval = -1
        for _ in 0..<50 {
            observed = await actor.currentRetention()
            if abs(observed - target) < 0.001 { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(observed, target, accuracy: 0.001,
                       "didSet should propagate the new retention to the actor within ~1s")
    }
}
