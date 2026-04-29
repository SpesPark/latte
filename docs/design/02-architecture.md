# 02 — Architecture

| Field | Value |
|---|---|
| **Document version** | 1.0 |
| **Status** | Approved (design phase closed at session 2; locked at v1.0 ahead of App Store submission) |
| **Resolves Open Questions** | OQ-05 (module boundaries), OQ-06 (Observable vs ObservableObject) |
| **Depends on** | [01-PRD.md](01-PRD.md) |
| **Successor docs** | [03-state-machine.md](03-state-machine.md), [04-data-model.md](04-data-model.md), [05-icon-spec.md](05-icon-spec.md), [../v2-backlog.md](../v2-backlog.md) |
| **Last updated** | 2026-04-27 |

---

## 1. Goals & Non-Goals

### 1.1 Architectural goals (in priority order)

1. **Testable** — Every module that has logic can be unit-tested without launching SwiftUI or touching real `IOPMAssertion`. All system boundaries are mockable via protocol.
2. **Single-developer-friendly** — One person navigates the codebase in <30 sec to find anything. No deep folder hierarchies, no abstract factories, no plugin loaders.
3. **Phase 2 ready** — When the iOS companion ships in Phase 2, the macOS app's *core* (state machine, settings, intents) can be lifted into a shared SPM package without rewrite.
4. **Crash-safe** — Any crash leaves the system in a clean state: power assertion released, files closed, no orphaned timers. `signal()` handler ensures release on SIGTERM/SIGINT.
5. **macOS 13 floor** — All architecture choices work on 13. Newer-OS-only enhancements (`@Observable`, Liquid Glass, `EKEventStore.requestFullAccessToEvents`) are gated with `#available` and have fallbacks.

### 1.2 Non-goals

- **Hexagonal/Clean Architecture purity** — too much ceremony for a 1-developer menu bar app.
- **Reactive programming framework** (Combine pipelines, RxSwift) — overkill; we use `@Published` for the ~5 observable properties total.
- **Dependency-injection container library** — manual constructor injection is sufficient at this scale.
- **Module-per-feature** SPM packages — folders are enough until Phase 2.
- **Generic plugin loader** for triggers — explicit registration in code is clearer.

---

## 2. High-level system view

```
┌──────────────────────────────────────────────────────────────────┐
│                         SwiftUI views                            │
│       MenuBarView · SettingsView · CoffeeCupView · …             │
│                          ↑ observe                               │
│                      @Published state                            │
│                          │                                       │
│  ┌───────────────────────┴───────────────────────────────────┐   │
│  │                  AwakeManager (@MainActor)                │   │
│  │   - Public API: toggle, activate(for:), deactivate        │   │
│  │   - State: isAwake, endsAt, activeDuration, allowDS       │   │
│  │   - Owns: timer, session lifecycle                        │   │
│  └───┬─────────────────────┬───────────────────────┬─────────┘   │
│      │ acquires            │ persists              │ receives    │
│      │                     │                       │ requests    │
│  ┌───▼──────────┐  ┌───────▼────────┐  ┌───────────▼─────────┐   │
│  │ PowerAssert. │  │ SettingsStore  │  │ TriggerCoordinator  │   │
│  │ (system)     │  │ (protocol)     │  │ (orchestrates N)    │   │
│  └──────┬───────┘  └────┬───────────┘  └──────────┬──────────┘   │
│         │ wraps         │ impls                   │ runs N       │
│         ▼               ▼                         ▼              │
│   IOKit.pwr_mgt   UserDefaultsStore        ┌─────────────┐       │
│   (kernel)        (now)  →  SwiftData      │ CalendarTr. │       │
│                   (Phase 2)                │ AppTrigger  │       │
│                                            │ WiFiTrigger │       │
│                                            │ FocusTrig.  │       │
│                                            └─────────────┘       │
│                                                                  │
│                  AppIntents (out-of-process)                     │
│                  Toggle / Start / Stop  →  AwakeManager.shared   │
└──────────────────────────────────────────────────────────────────┘
```

### 2.1 One-line summary of each component

| Component | Responsibility |
|---|---|
| **SwiftUI views** | Pure rendering; bind to `AwakeManager`'s `@Published` properties; no logic. |
| **AwakeManager** | Single source of truth for awake state. Coordinates assertion lifecycle, timer, and trigger requests. |
| **PowerAssertion** | Thin wrapper over `IOPMAssertionCreateWithName` / `IOPMAssertionRelease`. |
| **SettingsStore** | Protocol abstracting persistence. UserDefaults impl now; SwiftData impl in Phase 2 — see `04-data-model.md`. |
| **TriggerCoordinator** | Owns N triggers. Aggregates their "want awake" votes via combination policy → forwards to AwakeManager. |
| **Trigger** (4 implementations) | Each watches a system signal (calendar event, app launch, Wi-Fi SSID, Focus mode) and votes. |
| **AppIntents** | Shortcuts/Spotlight entry points. Talk to `AwakeManager.shared`. |

---

## 3. Module / folder structure

### 3.1 Decision: folders, not SPM packages (resolves OQ-05)

For v1, the app is a single Xcode target with these folders under `Sources/`:

```
Sources/
├── App/                       # Entry point + composition root
│   ├── LatteApp.swift         # @main, scene composition
│   └── AppEnvironment.swift   # Wires all dependencies for views
│
├── Core/                      # Pure-logic, no SwiftUI imports
│   ├── AwakeManager.swift
│   ├── AwakeDuration.swift
│   ├── PowerAssertion.swift
│   ├── SettingsStore.swift            # Protocol + UserDefaults impl
│   └── Logging.swift                  # os.Logger conveniences
│
├── Triggers/                  # Each file = one trigger + protocol
│   ├── Trigger.swift                  # Protocol + TriggerVote enum
│   ├── TriggerCoordinator.swift
│   ├── CalendarTrigger.swift
│   ├── AppTrigger.swift
│   ├── WiFiTrigger.swift
│   └── FocusTrigger.swift
│
├── Intents/                   # AppIntents (Shortcuts integration)
│   └── AwakeIntents.swift
│
├── UI/                        # All SwiftUI views
│   ├── MenuBar/
│   │   ├── MenuBarRoot.swift          # The menu bar window content
│   │   ├── DurationPickerRow.swift
│   │   └── HeaderView.swift
│   ├── Settings/
│   │   ├── SettingsRoot.swift         # TabView shell
│   │   ├── GeneralTab.swift
│   │   ├── TriggersTab.swift
│   │   └── AboutTab.swift
│   ├── Components/
│   │   ├── CoffeeCupView.swift
│   │   └── LiquidGlassModifier.swift  # macOS 26+ branch with fallback
│   └── Theme/
│       └── Theme.swift                # Colors, fonts, spacing constants
│
└── Resources/                 # Asset catalogs, plists referenced from project.yml
```

### 3.2 Dependency rule

Folders may **only** depend on folders to their left in this order:

```
Resources    ← (no deps)
Core         ← (no deps on app code; only Foundation, IOKit, os)
Triggers     ← Core
Intents      ← Core
UI           ← Core, Triggers (for status display only — never to mutate triggers directly)
App          ← all of the above
```

Concretely:
- **`Core/` MUST NOT import SwiftUI.** This makes Core unit-testable on Linux/CI without UI runtime.
- **`Triggers/` MUST NOT import SwiftUI.** Triggers can be tested headless.
- **`UI/` MAY import Core and Triggers** (for display) but MUST NOT mutate trigger state directly. UI calls `AwakeManager` methods only.
- **`Intents/` imports Core only.** AppIntents run in a separate process context; they must not assume UI is running.

A simple lint check (future): grep for `import SwiftUI` in `Core/` or `Triggers/` files — should always return zero matches.

### 3.3 When does a folder become an SPM package?

In Phase 2 (iOS companion app), `Core/` graduates to a local SPM package:

```
Latte.xcworkspace
├── Latte (macOS app target) ──┐
├── Latte iOS (iOS app target)─┤── depend on
└── Packages/
    └── LatteCore/             ←── (was Sources/Core)
        └── Package.swift
```

For v1, this is **deferred**. Premature packagization adds friction (separate build settings, tests run differently, no inline editing convenience).

**Trigger**: when iOS app gets its first commit, that's the cue to extract `Core/` into a package in the same PR.

---

## 4. Component contracts

This section defines the **public interface** of each major component. Implementations are written in subsequent sessions; the interfaces are locked here.

### 4.1 `AwakeManager`

```swift
@MainActor
public final class AwakeManager: ObservableObject {

    // Singleton for AppIntents access; injected to views via environment
    public static let shared: AwakeManager

    // MARK: Published state (read-only externally)
    @Published public private(set) var isAwake: Bool
    @Published public private(set) var endsAt: Date?
    @Published public private(set) var activeDuration: AwakeDuration?
    @Published public private(set) var activeReason: AwakeReason

    // MARK: Settings (read/write)
    @Published public var allowDisplaySleep: Bool

    // MARK: Public API
    public func toggle()
    public func activate(for duration: AwakeDuration, reason: AwakeReason = .user)
    public func deactivate(reason: AwakeReason = .user)

    // MARK: Trigger interface (TriggerCoordinator only)
    func receiveTriggerVote(_ vote: TriggerVote, from triggerId: String)
}

public enum AwakeReason: Equatable {
    case user                // Manual toggle / preset / AppIntent
    case trigger(id: String) // Activated by a trigger
    case launch              // "Activate on launch" preference
}
```

The `AwakeReason` field lets the UI explain *why* the Mac is awake ("Awake during your Zoom call") and lets state-machine policy (doc 03) decide conflict resolution.

### 4.2 `PowerAssertion`

```swift
public final class PowerAssertion {
    public enum Mode {
        case displayAndSystem  // kIOPMAssertionTypeNoDisplaySleep
        case systemOnly        // kIOPMAssertionTypeNoIdleSleep
    }

    public init() // creates an inactive assertion
    public var isActive: Bool { get }
    public var currentMode: Mode? { get }

    @discardableResult
    public func activate(mode: Mode, reason: String) -> Bool
    public func deactivate()

    deinit  // releases assertion if still active
}
```

Already drafted in skeleton (`Sources/PowerAssertion.swift`); the contract here is the canonical version.

### 4.3 `SettingsStore` (protocol)

```swift
public protocol SettingsStore: AnyObject {
    func bool(_ key: SettingsKey, default: Bool) -> Bool
    func setBool(_ value: Bool, for key: SettingsKey)
    func string(_ key: SettingsKey) -> String?
    func setString(_ value: String?, for key: SettingsKey)
    func data(_ key: SettingsKey) -> Data?
    func setData(_ value: Data?, for key: SettingsKey)
}

public enum SettingsKey: String {
    case allowDisplaySleep
    case activateOnLaunch
    case launchAtLogin
    case calendarTriggerEnabled
    case calendarTriggerCalendarIDs
    case appTriggerEnabled
    case appTriggerBundleIDs
    case wifiTriggerEnabled
    case wifiTriggerSSIDs
    case focusTriggerEnabled
    // ...extended in 04-data-model.md
}

public final class UserDefaultsSettingsStore: SettingsStore { … }
public final class InMemorySettingsStore: SettingsStore { … }  // for tests
```

Schema details and migration plan live in `04-data-model.md`. This file just locks the **shape**.

### 4.4 `Trigger` (protocol)

```swift
@MainActor
public protocol Trigger: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var symbol: String { get }      // SF Symbol for Settings UI
    var requiresPermission: Bool { get }

    var isEnabled: Bool { get set }
    var permissionStatus: TriggerPermissionStatus { get }

    func start() async
    func stop()
    func requestPermissionIfNeeded() async -> Bool

    var voteStream: AsyncStream<TriggerVote> { get }
}

public enum TriggerPermissionStatus {
    case notRequired
    case notDetermined
    case granted
    case denied
}

public struct TriggerVote: Equatable {
    public let wantsAwake: Bool
    public let reason: String       // e.g. "Zoom meeting (Standup)"
    public let until: Date?         // if known; otherwise nil = indefinite
}
```

The `voteStream` is an async sequence emitted whenever the trigger's opinion changes (e.g., calendar event starts/ends). `TriggerCoordinator` consumes these streams and aggregates votes per the policy in doc 03.

#### 4.4.1 `*Source` DI pattern (added session 4)

Each concrete trigger (`CalendarTrigger`, `AppTrigger`, `WiFiTrigger`, `FocusTrigger`) wraps its system API behind a small protocol — `CalendarSource`, `WorkspaceSource`, `WiFiSource`, `FocusSource` — injected via the trigger's initializer. Production binds the protocol to a real adapter (`EKCalendarSource`, `NSWorkspaceSource`, `CoreWLANSource`, `INFocusSource`); tests inject `MockCalendarSource`, `MockWorkspaceSource`, etc.

This keeps:
- Triggers' state machines (which event windows are "active", which apps are running, current SSID/Focus state) **testable without touching real EventKit, NSWorkspace, CoreWLAN, or INFocusStatusCenter**.
- Source adapters **focused** on translating one OS API surface into our protocol — no business logic.
- The `Trigger` protocol itself **unchanged** — only the implementation strategy changed.

The pattern matches the rules-style guidance in `swift-protocol-di-testing` (small focused protocols, default-parameter constructor injection).

### 4.5 `TriggerCoordinator`

```swift
@MainActor
public final class TriggerCoordinator: ObservableObject {

    public init(awakeManager: AwakeManager, store: SettingsStore)

    public func register(_ trigger: Trigger)
    public func startEnabledTriggers() async
    public func stopAll()

    @Published public private(set) var triggers: [Trigger]
    @Published public private(set) var activeVotes: [String: TriggerVote] // by trigger id
}
```

The coordinator:
- Holds the list of registered triggers
- Watches each trigger's `voteStream`
- Aggregates votes per the rules in `03-state-machine.md`
- Calls `awakeManager.receiveTriggerVote(...)` when the aggregate changes

Triggers do **not** call `AwakeManager` directly — they only emit votes. This keeps trigger logic isolated and the state machine in one place.

---

## 5. Concurrency model

### 5.1 Decisions

- **`SWIFT_STRICT_CONCURRENCY=complete`** is enabled (already in `project.yml`). This forces sendability annotations and catches data races at compile time.
- **`@MainActor`** is applied to every stateful type (`AwakeManager`, `TriggerCoordinator`, every `Trigger`, every view). Reasons:
  - All state is read by SwiftUI on the main thread anyway.
  - The Mac app is not throughput-critical; making everything MainActor avoids a class of bugs at near-zero performance cost.
  - `IOPMAssertion` calls are documented as thread-safe but the assertion handle is best owned by one actor.
- **Background work** (e.g., EventKit polling, `CWWiFiClient` scans) happens via `Task.detached` or `nonisolated` async functions. Results are awaited and applied on `@MainActor`.
- **No `Combine.Publisher` chains.** `@Published` is used with SwiftUI's `ObservableObject` integration. Triggers use `AsyncStream` for vote events.

### 5.2 Observation: `ObservableObject` (resolves OQ-06)

**Decision**: Use `ObservableObject + @Published` for v1. **Defer `@Observable` macro to Phase 1.5 or later.**

Rationale:
- `@Observable` requires macOS 14+. We target macOS 13.
- `ObservableObject` is well-understood and has clear `@StateObject` / `@EnvironmentObject` semantics.
- Migrating to `@Observable` later is a mostly-mechanical refactor (~1 hour) that we can do when we drop macOS 13 support.

If a property has performance concerns from over-publishing, we use `objectWillChange.send()` manually in that one spot. We do not preemptively optimize.

### 5.3 Cancellation

- All `start()` async methods are cancellable. Calling `stop()` on a trigger must abort any in-flight permission request or polling task.
- `AwakeManager`'s timer is invalidated on every `deactivate()` and on `deinit`.

---

## 6. Error handling & logging

### 6.1 Error policy

- **Recoverable errors** (calendar permission denied, Wi-Fi access failure) → log + UI surfaces a banner in Settings. App continues working.
- **Programmer errors** (unreachable cases, broken invariants) → `preconditionFailure` in DEBUG, logged + best-effort continue in RELEASE.
- **System errors** (`IOPMAssertionCreateWithName` returns non-success) → log + UI shows "Could not keep Mac awake; try restarting Latte". This is the most user-visible error path; we treat it carefully.

### 6.2 Logging

- **`os.Logger`** is used everywhere. Each module has a `Logger(subsystem: "com.parkbyeongjun.latte", category: "<module>")`.
- **No `print()`** in production code. Lint check via grep before each commit.
- **Log levels**:
  - `.debug` — verbose tracing, off in Release
  - `.info` — lifecycle events (assertion activated, trigger registered)
  - `.notice` — user-visible state changes
  - `.error` — recoverable errors
  - `.fault` — programmer errors / invariant violations

### 6.3 Crash safety

The app installs a `signal()` handler in `main` (or `@main`'s init equivalent) for `SIGINT`, `SIGTERM`, `SIGABRT`:

```swift
// At app boot
signal(SIGINT) { _ in
    AwakeManager.shared.deactivate(reason: .user)
    exit(0)
}
```

This ensures the power assertion is released even on hard kill, preventing the worst-case scenario where Latte crashes overnight and the user's Mac never sleeps.

---

## 7. Build system & dependency policy

### 7.1 Build

- **XcodeGen** generates `Latte.xcodeproj` from `project.yml`.
- The `.xcodeproj` is **gitignored**. Only `project.yml` is committed.
- `xcodegen generate` is the canonical way to (re)create the project locally and on CI.

### 7.2 Dependencies

- **Zero third-party SPM packages** in v1. Every dependency added increases:
  - App Store review surface
  - Maintenance burden when Swift/Xcode upgrades
  - Risk of supply-chain issues (a sleep utility doesn't need this)
- **System frameworks only**: `SwiftUI`, `AppKit` (minimal), `IOKit.pwr_mgt`, `EventKit`, `CoreWLAN`, `AppIntents`, `ServiceManagement`, `os.log`.
- Re-evaluate at Phase 1.5. Likely first additions:
  - `KeyboardShortcuts` (sindresorhus) for global hotkey support
  - `Sparkle` if we ever distribute outside App Store (not currently planned)

### 7.3 CI

- **GitHub Actions** on private repo, macOS-14 runner.
- One workflow: lint (SwiftFormat dry-run + `grep -r "print(" Sources/`), build, test.
- Triggered on every push and PR.
- Total runtime budget: <5 min per run.

---

## 8. Testing architecture

### 8.1 Test layers

| Layer | Tooling | What's tested | Approx. % of total tests |
|---|---|---|---|
| **Unit** | XCTest | `AwakeManager`, `PowerAssertion` (with mock IOKit), `Duration`, `SettingsStore` (in-memory), `TriggerCoordinator` (with mock triggers) | 60% |
| **Integration** | XCTest | Trigger ↔ AwakeManager wiring, SettingsStore migration, AppIntents → AwakeManager | 30% |
| **UI smoke** | XCUITest (lightweight) | Menu bar opens, toggle changes icon, Settings tabs render | 10% |

We target **80% coverage on `Sources/Core/` and `Sources/Triggers/`** (the logic-heavy folders). UI views are not coverage-targeted.

### 8.2 Mocking strategy

- **`MockPowerAssertion`** — implements the same public surface as `PowerAssertion` but records calls without touching IOKit. `AwakeManager` accepts a protocol-typed assertion in its initializer (default: real one).
- **`InMemorySettingsStore`** — `SettingsStore` impl backed by a dict.
- **`MockTrigger`** — manual `voteStream` for testing `TriggerCoordinator` aggregation logic.

### 8.3 What we deliberately don't test

- IOKit's behavior — that's Apple's job.
- SwiftUI rendering — too brittle, low ROI for menu-bar utility.
- Private `os.Logger` output — tested implicitly.

---

## 9. Phase 2 readiness — what enables iOS app later

Decisions made now to keep the iOS port cheap:

| Decision | Why it helps Phase 2 |
|---|---|
| `Core/` is SwiftUI-free | Lifts cleanly into shared SPM package |
| `SettingsStore` is a protocol | iOS impl can write to iCloud KVStore |
| `AwakeReason` includes `.trigger(id:)` | Cross-device "iPhone toggled it" reason fits naturally |
| Triggers vote via streams | A "remote toggle from iPhone" can be modeled as another trigger |
| `AppIntents` are first-class | Same intent surface used on both platforms |
| No third-party deps | Less to port and audit on iOS |

What is **explicitly not** designed for now (deferred until iOS app is real):
- APNs token lifecycle
- iCloud KVStore conflict resolution
- Watch app architecture

---

## 10. Skeleton ↔ this architecture: gap list

> **Status (session 3 close)**: The migration described below is **complete**. `Sources/` and `Tests/` now match the target layout. The `current → target` mapping is preserved as historical reference.

The current `Sources/` skeleton (from session 1's earlier work) had a different folder layout. Migration in session 3:

| Current | Target |
|---|---|
| `Sources/CaffeinatedApp.swift` | `Sources/App/LatteApp.swift` |
| `Sources/AwakeManager.swift` | `Sources/Core/AwakeManager.swift` |
| `Sources/PowerAssertion.swift` | `Sources/Core/PowerAssertion.swift` |
| `Sources/Duration.swift` | `Sources/Core/AwakeDuration.swift` |
| `Sources/MenuBarView.swift` | `Sources/UI/MenuBar/MenuBarRoot.swift` (split into 3 files) |
| `Sources/SettingsView.swift` | `Sources/UI/Settings/SettingsRoot.swift` (split into 3 tab files) |
| `Sources/CoffeeCupView.swift` | `Sources/UI/Components/CoffeeCupView.swift` |
| `Sources/Triggers/*.swift` | `Sources/Triggers/*.swift` (mostly unchanged) |
| `Sources/Intents/AwakeIntents.swift` | `Sources/Intents/AwakeIntents.swift` (unchanged) |
| (none) | `Sources/Core/SettingsStore.swift` (new) |
| (none) | `Sources/Core/Logging.swift` (new) |
| (none) | `Sources/Triggers/TriggerCoordinator.swift` (new) |
| (none) | `Sources/UI/Theme/Theme.swift` (new) |

This is the work for **session 3** (Phase 1.0 implementation). **Completed 2026-04-25.**

---

## 11. Open Questions resolved by this doc

| ID | Status |
|---|---|
| OQ-05 (module boundaries — folders or SPM?) | **Resolved**: folders for v1; extract `Core/` to SPM in Phase 2 |
| OQ-06 (`@Observable` vs `ObservableObject`) | **Resolved**: `ObservableObject` for v1; `@Observable` deferred to post-macOS-13-deprecation |

Remaining Open Questions (status as of session 2):

| ID | Status |
|---|---|
| OQ-01, OQ-02 (trigger priority, manual vs trigger conflict) | ✅ **Resolved (S2)** in [03-state-machine.md](03-state-machine.md) |
| OQ-03, OQ-04 (UserDefaults vs SwiftData; migration) | ✅ **Resolved (S2)** in [04-data-model.md](04-data-model.md) |
| OQ-07 (onboarding) | ⚪ Deferred to 06-ui-spec.md |
| OQ-08 (app icon direction) | ⚪ Deferred to 06-ui-spec.md |
| OQ-09 (App Store category) | ⚪ Deferred to 10-release-plan.md |
| OQ-10 (Korean copy tone) | ⚪ Deferred to 11-localization.md |

---

## 12. Decisions Log (this doc)

| Date | Decision |
|---|---|
| 2026-04-25 | Folder-based modules in v1; `Core/` extraction to SPM deferred to Phase 2 |
| 2026-04-25 | `ObservableObject + @Published` for v1 observation; `@Observable` migration deferred |
| 2026-04-25 | `@MainActor` everywhere stateful + `SWIFT_STRICT_CONCURRENCY=complete` |
| 2026-04-25 | Zero third-party SPM dependencies in v1 |
| 2026-04-25 | Triggers communicate via `AsyncStream<TriggerVote>` to coordinator (not direct `AwakeManager` access) |
| 2026-04-25 | `signal()` handler ensures power assertion release on SIGINT/SIGTERM/SIGABRT |
| 2026-04-25 | Test coverage target: **80% on `Core/` and `Triggers/`**; UI views not coverage-targeted |

---

## 13. Document Change Log

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-04-25 | Initial draft (session 1) |
| 0.2 | 2026-04-25 | Session 2: marked OQ-01 ~ OQ-04 resolved with cross-references; status flipped to Approved; sign-off checklist confirmed |
| 0.3 | 2026-04-25 | Session 3: §10 skeleton-rewrite gap marked complete; no contract changes |
| 0.4 | 2026-04-26 | Session 4: §4.4.1 added — documents `*Source` DI pattern that arrived with real EventKit/NSWorkspace/CoreWLAN/INFocusStatusCenter wiring. `Trigger` protocol unchanged. |
| 0.5 | 2026-04-26 | Session 5: Phase 1.C UI primitives — `CoffeeCupView` (Canvas + TimelineView, pure `CoffeeCupGeometry` for tests), `LiquidGlassModifier` (`.liquidGlassBackground()` + new `.liquidGlassCard()`), `MenuBarIconStyle` enum mirrored on `AppEnvironment` (@Published). UI module folders unchanged from §3.1. Successor doc [05-icon-spec.md](05-icon-spec.md) added (owner-facing icon brief). |
| 0.6 | 2026-04-26 | Session 6: First green Xcode build (Xcode 26.4.1, macOS 26.4 SDK, deploymentTarget macOS 13.0). Build/test fixes — no architectural changes: (a) `AppIntent` static properties switched from `var` → `let` to satisfy Swift 6 strict concurrency (App Intents protocol allows; getter-only requirement). (b) `@Parameter(... inclusiveRange: (1, 24*60))` requires compile-time literal under macros — replaced with `(1, 1440)`. (c) `@Environment(\.openSettings)` is macOS 14+; replaced with `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` to preserve macOS 13 deployment target. (d) `WiFiTrigger.evaluate` and `FocusTrigger.evaluate`: added first-OFF silence guard (`if lastVote == nil && !wantsAwake { return }`) so initial false condition emits no vote — matches `AppTrigger.start` semantic. Tests reflect intent (silence == "no opinion"). All 178 tests pass. |
| 0.7 | 2026-04-26 | Session 6 (extended). Post-build smoke surfaced two surprises that needed fixes; both are documented here so future sessions don't relearn: **(1) Settings window**: `Settings { }` SwiftUI scene + `SettingsLink` does *not* reliably wire into the menu/responder chain for `LSUIElement` (menu-bar-only) apps — `SettingsLink` taps fire but produce no window; both `Selector(("showSettingsWindow:"))` and `Selector(("showPreferencesWindow:"))` are unhandled because the app has no main menu attached. Fix: new `Sources/UI/Settings/SettingsWindowController` that hosts `SettingsRoot` in a real `NSWindow` via `NSHostingController`, owned as a singleton. `LatteApp` no longer declares the `Settings { }` scene; `MenuBarRoot` calls `SettingsWindowController.shared.show(...)` directly. **(2) Accent color resolution in Canvas**: `Color.accentColor` on macOS follows the user's system tint (overrides `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`), and `Color.primary` is not always resolved against current appearance inside `Canvas` rendering. Fix: `Theme.Colors.accentAwake` and the new `Theme.Colors.cupStroke` are now built from explicit `NSColor(name:dynamicProvider:)` (light/dark variants in code, not asset catalog). `Theme.swift` now imports `AppKit`. Polish on the same pass: `DurationPickerRow` hover state + 3pt caramel accent bar, divider opacity 0.5, `CoffeeCupView` liquid recolored to `accentAwake`. **Custom duration α**: new `Sources/UI/MenuBar/CustomDurationRow` adds an inline expandable Stepper (1–1440 min) + Start to `MenuBarRoot`, animated with `.animation(_:value:)` scoped to the row's own `VStack` so sibling rows don't get pulled into the layout transaction. All 178 tests still pass. |
| 1.2 | 2026-04-29 | Session 9.5 — **Battery-aware (C-1) + Pause-all triggers (C-9)**. Two new `@Published` flags on `AwakeManager` (`requireACForAwake`, `triggersPaused`) plus an observed `isOnAC` snapshot, all backed by `SettingsKey.requireACForAwake` / `.triggersPaused`. New file `Sources/Core/PowerSource.swift` introduces `PowerSourceType` protocol + real `IOPowerSource` (uses `IOPSCopyPowerSourcesInfo` + `IOPSNotificationCreateRunLoopSource` on the main runloop) + `MockPowerSource` for tests. `AwakeManager.init` injects the source via DI (mirror of §4.4.1 `*Source` pattern, even though no Trigger is involved — same shape so tests follow the established convention) and subscribes via `observe`; the observation is held as `powerObservation: PowerSourceObservation?`. **Gate semantics** (no state-machine changes): a private `blockReason(forManualActivation:) -> String?` consults the two flags and `isOnAC`. (a) `requireACForAwake && !isOnAC` blocks **all** awake transitions (manual + trigger). (b) `triggersPaused` blocks only trigger ON votes — manual activation is the user's explicit intent and is honored regardless. `activate(for:)` and `receiveTriggerVote(_:from:)` consult the gate at the input boundary; ON votes that fail the gate are dropped (logged at info level), never reaching `process(.triggerVoteOn(...))`. OFF votes always flow so `pendingVotes` stays in sync — when the user un-pauses or plugs back in, there is no stale-ON replay. A `enforceConstraintsIfNeeded(reason:)` is invoked from each flag's `didSet` and from the AC-state observer; if the new state forbids the current awake (and the flag scope applies — pause-all only releases trigger-driven awake, not user-manual), it dispatches `process(.userDeactivate)` to release the assertion and unwind to `.asleep`. **Explicit non-feature**: re-plugging AC or un-pausing does **not** auto-reactivate — unattended battery cycles must not silently re-acquire the assertion; the user / trigger must re-engage. UI: Settings → General → Behavior gains `Toggle("Sleep when on battery", isOn: $manager.requireACForAwake)` plus a battery-state hint when the constraint is currently suppressing awake. The menu-bar popover gains a top-row `Pause triggers` toggle bound to `manager.triggersPaused` with caption-style sub-text explaining that manual activation still works. `MockPowerAssertion`'s `deactivationCount` (already present) is the test seam for verifying release count on constraint flips. 23 new tests in `Tests/PowerSourceAndConstraintsTests.swift` cover MockPowerSource observe/cancel semantics, AwakeManager hydrate-from-settings, persist-on-write, manual-activation gating in all four (battery × require-AC) quadrants, trigger-vote gating, flip-flag-while-awake behavior in both feature scopes, AC-unplug-while-awake observer path, no-auto-replay on AC-return / unpause, OFF-vote-flow-while-paused invariant, and combined-flag both-block-everything case. `SettingsKeyEnumTests.testRequiredKeysExist` extended with the two new keys. 337 → **360 tests, all PASS**. The state machine, `PowerAssertion`, `Trigger` protocol surface, and persistence schema for triggers are all unchanged. Tracked as ✅ C-1 + ✅ C-9 in `docs/v2-backlog.md`. |
| 1.1 | 2026-04-29 | Session 9 — **V2-05 Schedule trigger lands as a 5th registered trigger**. New file `Sources/Triggers/ScheduleTrigger.swift` introduces three pure value types — `Weekday` (Sun=1..Sat=7 aligned with `Calendar.weekday`), `TimeOfDay` (hour+minute, clamped on construction, `Comparable`), and `ScheduleEntry` (UUID + weekday set + start/end TimeOfDay + label + isEnabled, `Codable`+`Sendable`+`Identifiable`) — alongside the trigger itself. The trigger conforms to the existing `Trigger` protocol (no protocol change), polls every 30 s, and emits exactly one ON vote on enter / one OFF vote on exit (no per-poll re-emit) by tracking `activeEntryID: UUID?` between polls. Midnight-crossing semantics: when `end < start`, the late half `[start, 24:00)` matches the entry's listed weekday (today), and the early half `[00:00, end)` matches yesterday's weekday — a Mon 22:00–02:00 entry covers Monday night through Tuesday 02:00 only, not Tuesday night. No `*Source` adapter needed (clock + calendar are plain values, injected as `now: () -> Date` and `calendar: Calendar` for tests). Persistence: two new `SettingsKey` cases — `scheduleTriggerEnabled` (Bool) and `scheduleTriggerEntries` (Data, JSON-encoded `[ScheduleEntry]`); SettingsStore extension `scheduleTriggerEntries` handles encode/decode with empty-default fallback on corruption. UI: `ScheduleTriggerConfigForm` added in `Sources/UI/Settings/TriggersTab.swift` — per-entry enable Toggle + label TextField + start/end DatePicker (hourAndMinute) + 7-chip weekday selector in Mon..Sun display order + add/remove buttons + a footer hint when the entry crosses midnight. Edits commit immediately and call `trigger.reevaluate()` so the cup state reflects within one render pass (mirrors the App/WiFi/Calendar S8b contract). `AppEnvironment.registerDefaultTriggers()` registers `ScheduleTrigger(settings:)` after the existing three; `OnboardingView.description(for:)` adds the `"schedule"` case. Tests: 28 new in `Tests/ScheduleTriggerTests.swift` covering TimeOfDay clamping/comparable, ScheduleEntry same-day/midnight-crossing in both halves/Sunday-wraps-to-Saturday/zero-length/empty-weekday/disabled/full-day, Codable round-trip, SettingsStore round-trip + corruption fallback, ScheduleTrigger reason formatting (label vs HH:MM–HH:MM), ON/OFF transitions, no-re-emit on repeated polls, overlapping-entry stable order, disabled no-op, and stream-lifetime preserved across stop/start (S7.11 invariant). Two existing tests updated for the new key set: `AppEnvironmentTests.testRegistersThreeDefaultTriggers` → `testRegistersFourDefaultTriggers`, `SettingsKeyEnumTests.testRequiredKeysExist` extended with the two new keys. 309 → **337 tests, all PASS**. Tracked as ✅ V2-05 in `docs/v2-backlog.md`. |
| 1.0 | 2026-04-27 | Session 8 — **Architecture locked at v1.0 ahead of App Store submission**. No code changes to the architecture itself; this version represents the "design freeze" gate before public release. Concrete deltas: (a) bundle ID changed from placeholder `com.example.latte` to default `com.parkbyeongjun.latte` across `project.yml` (3 spots), `Sources/Core/{Logging,PowerAssertion,SettingsStore}.swift` (3 spots), `01-PRD.md`, `04-data-model.md`, `02-architecture.md` §6.2, `docs/QA_LOG.md`, `docs/site/privacy.html`, `docs/store/*-url.txt`. Owner-revisit captured as `v2-backlog.md` V2-20. (b) `MARKETING_VERSION` bumped `0.1.0 → 1.0.0`; `CURRENT_PROJECT_VERSION` stays at `1` for first submission. (c) Repo folder rename `Caffeinated-Clone/ → Latte/` (cosmetic). (d) Marketing site (`docs/site/`) and App Store metadata (`docs/store/`) added — no architectural impact, listed for completeness. `v2-backlog.md` is now the canonical place for items deferred from v1.0; this changelog continues only for v1.x architectural changes. |
| 0.16 | 2026-04-27 | Session 7.11 — **Stream-lifecycle parity for Calendar/WiFi/Focus + first AppIcon raster set**. Post-S7.10 review surfaced that the S7.9 stream-lifecycle fix had been applied to `AppTrigger` only; `CalendarTrigger.stop()` / `WiFiTrigger.stop()` / `FocusTrigger.stop()` still called `continuation.finish()`. Result: any future Toggle OFF→ON cycle on those three triggers would silently kill the AsyncStream, future yields silently dropped, the cup never re-activates. The bug was latent (owner is currently exercising App trigger only) but a clear regression risk for the next smoke pass. Fix: removed `continuation.finish()` from all three `stop()` methods, identical to S7.9 AppTrigger fix; identical explanatory comment in each. Three corresponding tests (`CalendarTriggerTests` line ~302, `WiFiTriggerTests` line ~187, `FocusTriggerTests` line ~126) refreshed from "stream finishes after stop" assertions to "no further votes after stop" bounded-timeout `Task.cancel()` probes (matches the AppTrigger test pattern). No protocol or state machine changes — `Trigger` API surface unchanged. Coverage stays PASS (CalendarTrigger 98.79% up from 98.75%, WiFiTrigger 96.61% up from 96.55%, FocusTrigger 97.98% up from 97.94%). 261 → 263 tests. **F-1.C.04 (App icon)** lands the bundle: 10 raster sizes (16/32/64/128/256/512/1024 covering 1x/2x of 16/32/128/256/512) generated from owner's 1254×1254 master via `sips`, committed to `Resources/Assets.xcassets/AppIcon.appiconset/` with `Contents.json` `filename` references per Apple's asset catalog format. Master + 1024×1024 marketing variant filed under `docs/design/assets/icon-master-1254.png` + `icon-1024.png` for App Store / press use. Original repo-root file moved out so we don't ship a stray PNG. **This commit closes the S7-family iteration** (S7 → S7.11, eight sub-sessions across 2026-04-26 → 2026-04-27, 178 → 263 tests, 16 incremental ROADMAP version bumps). Remaining S8 work is owner-side. |
| 0.15 | 2026-04-26 | Session 7.10 — **Per-trigger grace replaces the blanket 60 s cool-down (state machine + protocol surgery, UX win)**. Owner re-smoke against S7.9 confirmed Toggle OFF + watched-list edits do flow through the state machine, but the cup stayed activated for 60 seconds afterwards because `(.awakeTriggered, .triggerVoteOff)` always entered `.coolingDown(60s)` — `.coolingDown` is `isAwake = true`. To owner that read as a bug, not graceful handoff. Cross-app analysis (Amphetamine, Owly, KeepingYouAwake, Caffeinated, Theine, Lungo) showed no leading sleep-prevention app uses a hidden cool-down; competitors transition immediately on trigger state changes, and there's no documented user complaint about flicker in those apps. Combined with the fact that Latte's `.asleep` only releases the IOPMAssertion (macOS still respects its own 5–15 min idle timeout before actually sleeping), the cool-down was largely working invisibly underneath the OS timer. **Fix**: replace the blanket cool-down with **per-trigger grace**. (1) `Trigger` protocol gains `var graceSecondsAfterOff: TimeInterval { get }` with a default-impl extension returning `0` — every trigger inherits the v1 default of immediate release. (2) `TriggerVote` gains `graceSecondsAfterOff: TimeInterval` (Sendable struct; new field defaults to 0 so existing call sites compile unchanged). (3) `AwakeInput.triggerVoteOff` extended from `(id: String)` to `(id: String, graceSeconds: TimeInterval)` so the state machine can branch on it. (4) `AwakeStateMachine.step` for `(.awakeTriggered, .triggerVoteOff(id, grace))`: when `newVotes.isEmpty`, fork on `grace == 0` (return `.asleep` + `.releaseAssertion`, no timer) vs `grace > 0` (return `.coolingDown(now + grace, lastVotes: votes)` + `.scheduleTimer(.coolDown, until)` — same shape as before, just with the grace from the vote rather than the global constant). Other states' `.triggerVoteOff` arms add `, _` to ignore grace (irrelevant when not in `.awakeTriggered`). (5) `AwakeManager.receiveTriggerVote` extracts grace from `vote.graceSecondsAfterOff` when forwarding to `process(.triggerVoteOff(...))`. (6) `TriggerCoordinator.stop` (UI Toggle OFF path) synthesizes its vote-OFF with `graceSecondsAfterOff: 0` explicitly — user-explicit actions always bypass the grace, regardless of the trigger's declared value. (7) `AppTrigger.reevaluateWatched` does the same when the watched-list edit causes a transition to OFF (user edited the list, expects immediate effect). `AppTrigger.handleTerminate` (organic — system reported the watched app died) emits with `graceSecondsAfterOff: graceSecondsAfterOff` so triggers can opt into a grace period if they ever override the default. The `Trigger` surface is unchanged for existing call sites (default-impl). v1: all 4 triggers stay at grace = 0, so Toggle OFF / list edit / app-terminate / calendar-end / WiFi-leave / Focus-off all release the assertion immediately. Cool-down infrastructure is preserved for future opt-in. 7 test sites updated: §8 worked-example tests for cool-down behavior now pass `graceSecondsAfterOff: 30` explicitly to exercise the cooling path; new test `testAwakeTriggered_triggerVoteOff_lastVote_grace0_goesToAsleepImmediately` covers the v1 default; new test `testAwakeTriggered_triggerVoteOff_lastVote_gracePositive_goesToCoolingDown` re-asserts the legacy cool-down path; two AwakeManager-level tests verify `receiveTriggerVote` dispatches grace correctly into the state machine. The S7.9 owner-scenario integration tests in `TriggerCoordinatorTests` were tightened from "coolingDown OR asleep" to strict "asleep" since coordinator.stop now sends grace = 0 deterministically. 255 → 261 tests, all pass. Coverage gate: AwakeManager 94.26% (up from 94.12%), AppTrigger 98.62%, TriggerCoordinator 92.96% — all above 80%. `03-state-machine.md` v0.2 documents the new design in §5.2 with the full revised rationale. |
| 0.14 | 2026-04-26 | Session 7.9 — **Trigger lifecycle: Toggle OFF and watched-list edit now actually deactivate (UI rewiring + 1 small AppTrigger API extension)**. Two related bugs surfaced by the S7.8 smoke. (A) `TriggerSection.Toggle.onChange` (Sources/UI/Settings/TriggersTab.swift) only persisted `trigger.isEnabled = newValue` and did nothing to the live trigger — the `WorkspaceObservation` stayed alive, the `voteStream` consumer Task in `TriggerCoordinator.consumerTasks` kept forwarding stale ON votes, the FSM stayed in `.awakeTriggered`, the cup stayed on. Fix: `TriggerSection` now takes a `coordinator: TriggerCoordinator`; the Toggle's `onChange` dispatches a Task that calls `coordinator.start(trigger)` on ON or `coordinator.stop(trigger.id)` on OFF (`coordinator.stop` already synthesizes a vote-OFF). Universal across all 4 triggers. (B) `AppTrigger.start()` captured a `let watched = Set(settings.appTriggerBundleIDs)` into the `onLaunch:` / `onTerminate:` closures; the closures kept using that frozen capture even after the user mutated the watched list via the UI, so `matchingRunning` retained removed bundle IDs, no vote-OFF emitted, cup stayed on. Fix: `AppTrigger.watchedSet` is now an instance var (set in `start()`, cleared in `stop()`); `handleLaunch(bundleID:)` / `handleTerminate(bundleID:)` simplified to read it; new public `AppTrigger.reevaluateWatched()` re-reads `settings.appTriggerBundleIDs`, recomputes `matchingRunning = running ∩ watched`, and emits vote ON/OFF/re-emit-ON-with-fresh-reason on transition (idempotent when nothing changed; no-op when the trigger is stopped — the next `start()` will read fresh data anyway). `AppTriggerConfigForm.commit(_:)` calls it after writing settings. Additional **stream lifecycle hardening**: removed `continuation.finish()` from `AppTrigger.stop()` — finishing the AsyncStream permanently silenced the trigger across any future Toggle OFF → ON cycle (consumer's `for await` would terminate, future `yield`s drop). Stream is now long-lived; the coordinator's consumer Task is cancelled on stop and recreated on start, both reading from the same stream. The `Trigger` protocol surface is unchanged; `reevaluateWatched()` is a public method on `AppTrigger` only (other triggers will get their own equivalents in S7.10 if needed). 6 new tests: 5 reevaluateWatched scenarios (add match → emit ON, remove last match → emit OFF, no-op when settings unchanged, set changed but still non-empty → re-emit ON for fresh reason, no-op when stopped) + 1 restart-after-stop regression test. `testStopCancelsObservation` comment refreshed. 249 → 255 tests; coverage gate still PASS (AppTrigger 98.06% with adapter classes + inner closures excluded). |
| 0.13 | 2026-04-26 | Session 7.8 — **App trigger pickable filter + installed-only seed (UI + 2 protocol extensions + persistence flag)**. `WorkspaceSource` (live-system adapter abstraction, §4.4.1) gains two new requirements: `var pickableRunningBundleIDs: [String]` (UI-pickable subset of `runningBundleIDs`, real impl filters `activationPolicy == .regular` and excludes the current process by `Bundle.main.bundleIdentifier`) and `func isInstalled(_ bundleID: String) -> Bool` (real impl checks `NSWorkspace.urlForApplication(withBundleIdentifier:)`). The unfiltered `runningBundleIDs` stays as-is so trigger lifecycle (start-snapshot intersection + launch/terminate observation) keeps working for `.accessory` apps the user manually adds via Advanced. New persistence key `SettingsKey.hasSeededAppDefaults: Bool` records that first-launch seeding has run once. `AppTrigger.init` invokes a private `seedInstalledDefaultsIfNeeded()` that, gated on the flag, populates `SettingsStore.appTriggerBundleIDs` with `AppTriggerDefaults.installedDefaults(in: source)` (curated 6 filtered to those `isInstalled`) — idempotent across re-launches, skipped entirely if the user already has a non-empty configuration. The legacy fallback in `SettingsStore.appTriggerBundleIDs` getter (return all 6 curated IDs when raw is empty) is removed; empty raw now means "watch nothing." `AppTriggerDefaults` gains two helpers: `installedDefaults(in:)` (used by the seeder) and `symbolHint(for:)` (SF Symbol category mapping: video-call apps → `video.fill`, chat apps → `bubble.left.and.bubble.right.fill`) used as the icon fallback in both watched-list `AppRow` and "Add from running apps" Menu items. `MockWorkspaceSource` extended with `pickableOverride` and `installedOverride` for explicit test control; defaults treat `runningBundleIDs` as the installed/pickable set. UI in `Sources/UI/Settings/TriggersTab.AppTriggerConfigForm`: Menu uses `pickableRunningBundleIDs`, items render via `Label { Text(name) } icon: { Image(nsImage:) }` (real icon when present, SF Symbol category when not, plain Text only as last resort); empty-state copy refreshed to invite the user to add their own apps. The `Trigger` protocol, `TriggerCoordinator`, and all other architecture layers are unchanged. 14 new tests + 1 keys-list test extended; 235 → 249 tests; coverage gate still PASS (AppTrigger 98.89% with adapter classes + inner closures excluded). |
| 0.12 | 2026-04-26 | Session 7.7 — **App trigger UX friendly names (UI + small protocol extension)**. `WorkspaceSource` (the live-system adapter abstraction defined in §4.4.1) gains one new requirement: `func displayInfo(for bundleID: String) -> AppDisplayInfo?`, returning a `Sendable` struct of `displayName: String` + optional `iconImageData: Data?` (PNG bytes, ~64pt downsample). The protocol stays `@MainActor` and platform-agnostic — `AppDisplayInfo` is `Sendable` because it carries `Data`, not `NSImage`. Real `NSWorkspaceSource.displayInfo(for:)` resolves in priority order (running app → installed bundle → curated default → nil); inner closures and the new private `pngData(from:)` helper sit on `NSWorkspaceSource` and are therefore covered by the existing adapter exemption (§13 v0.9). `MockWorkspaceSource` gains a stubbable `displayInfoLookup` dict and a fallback to `AppTriggerDefaults.displayName(for:)`. `AppTrigger` exposes a `displayInfo(for:)` thin passthrough so the UI layer never reaches into the source. Curated default name table is added as `AppTriggerDefaults.displayName(for:)` covering the 6 default IDs. The `Trigger` protocol is unchanged; `TriggerCoordinator` is unchanged; persistence (`SettingsStore.appTriggerBundleIDs`) is unchanged — friendly resolution is purely render-time. UI: `Sources/UI/Settings/TriggersTab.AppTriggerConfigForm` rewritten with new `AppRow` (icon + display name + bundle ID muted secondary), purpose-explaining caption, "Add from running apps" Menu items showing display names sorted case-insensitively, and the manual bundle-ID textfield collapsed into a `DisclosureGroup("Advanced — add by bundle ID")` closed by default — note this DisclosureGroup's label is purely a non-interactive caption + icon, satisfying the S7.6 lesson (DisclosureGroup labels must not contain Toggles or other tappable controls). 6 new tests; 229 → 235. Coverage gate: still PASS (`Triggers/AppTrigger` 98.68% with adapter classes + their inner closures excluded). |
| 0.11 | 2026-04-26 | Session 7.6 — **TriggersTab UX rewrite (UI-only fix-first)**. No protocol or architecture changes; the Trigger / Source / Coordinator layers are untouched. Surface change is in `Sources/UI/Settings/TriggersTab` only: the previous `DisclosureGroup`-with-Toggle-in-label structure (which caused click-target collision between label expand and the inline Toggle, plus a stale-`subtitle` window because `subtitle` read `trigger.isEnabled` from `SettingsStore` while the Toggle UI bound to a local `@State`) is replaced by **Section-per-trigger**: each registered `Trigger` becomes its own `Form` `Section` with a single standalone `Toggle("Enable")` row, the per-trigger config form rendered inline beneath when `isOn`, the trigger icon + name + live voting dot in the section header, and the live vote-reason / permission-status copy in the section footer. The `if newValue { isExpanded = true }` side-effect that ran inside Toggle's `onChange` is gone — there is no separate `isExpanded` state any more. `AppTriggerConfigForm`'s "Add from running apps" went from a nested `DisclosureGroup` to a `Menu` (candidates listed as Buttons), eliminating the second nested-disclosure hit-target ambiguity. The `WiFi` mode picker was upgraded from `.radioGroup` to `.segmented` for clearer binary choice. The outer `ForEach` switched from `id: \.offset` to `id: \.id` so SwiftUI tracks each `TriggerSection` by trigger identifier rather than ordinal position. The `subtitle` helper is removed entirely; the Toggle is the single source-of-truth for enabled-state display. 229/229 tests still pass — coverage gate still PASS. |
| 0.10 | 2026-04-26 | Session 7.5 — **Phase 1.5.A per-trigger configuration surface**. UI-only addition with two minor public-API extensions: `AppTrigger.runningBundleIDs: [String]` and `WiFiTrigger.currentSSID: String?` — both are read-only passthroughs to the corresponding `*Source` adapter, exposed so the Settings UI can offer "Add from running apps" and "Add current network" without the view tier reaching into the source layer directly. The `Trigger` protocol itself is unchanged, so the addition does not affect `TriggerCoordinator` or other consumers. `Sources/UI/Settings/TriggersTab` is restructured around `DisclosureGroup`: each trigger row's expanded body dispatches on `trigger.id` to one of four config forms (`AppTriggerConfigForm` / `WiFiTriggerConfigForm` / `CalendarTriggerConfigForm` / `FocusTriggerConfigInfo`). Each form binds local `@State` mirrors of the relevant `SettingsStore` extension properties (e.g. `appTriggerBundleIDs`, `wifiTriggerSSIDs`, `wifiTriggerInverseLogic`, `calendarTriggerLeadTimeMinutes`/`Trailing`/`ExcludeAllDay`) and writes-through on every mutation, keeping persistence atomic and avoiding "Save" buttons. Two surfaces are deliberately deferred: the EventKit calendar-list picker (needs live `EKEventStore.calendars(for:)` + permission flow; lands in Phase 1.5.B) and per-Focus selection (depends on Apple stabilizing third-party Focus identifiers). The TriggersTab UI's Form/Footer copy is updated to reflect the new capability. 229/229 tests pass; coverage gate still PASS (lowest gated file 82.8%). |
| 0.9 | 2026-04-26 | Session 7 — coverage + QA gate (no contract changes; documentation + test-only). The 80% line-coverage gate from PRD §10 is now formally interpreted: it applies to `Sources/Core/**` and `Sources/Triggers/**`, and **excludes the live-system adapter classes** `EKCalendarSource`, `NSWorkspaceSource`, `INFocusSource`, `CoreWLANSource` — these wrap user-interactive permission flows and hardware queries that cannot be exercised from a unit-test process. Their consumers (the corresponding `*Trigger` types) are tested at ≥97% via the parallel `Mock*Source` types injected through the existing DI seam (§4.4.1). `PowerAssertion` was originally a candidate for the same exemption but was promoted onto the gate after we confirmed `IOPMAssertionCreateWithName` works in any macOS process without entitlements; new `Tests/PowerAssertionTests.swift` exercises the real adapter end-to-end (activate / deactivate / mode-switch / idempotency / inactive-deactivate). Result: 227/227 tests, all gated files ≥80% (lowest is `Triggers/Trigger` at 82.8%, highest several at 100%). Snapshot + reproduction command + per-file table now live in `docs/QA_LOG.md`. The same doc carries the owner-side smoke checklist (menu-bar UI, custom duration, coffee tone, icon style, triggers, quit hygiene) and defers macOS 13/14/15 matrix testing to TestFlight (S9). |
| 0.8 | 2026-04-26 | Session 6 (extended again). New customization surface: **`Sources/UI/Theme/CoffeeAccent`** — 5-case enum (`espresso`/`caramel`/`mocha`/`latte`/`noir`), each holding light + dark sRGB pairs, resolved into a `Color` via `NSColor(name:dynamicProvider:)`. Replaces the previous static `Theme.Colors.accentAwake` as the source-of-truth for accent — that constant remains as a compatibility alias defaulting to `CoffeeAccent.default.color`. Persistence: new `SettingsKey.coffeeAccent` (string raw value); `AppEnvironment.@Published var coffeeAccent` mirrors it the same way `menuBarIconStyle` does. Consuming views switched from `Theme.Colors.accentAwake` to `environment.coffeeAccent.color`: `HeaderView` (passes through to `CoffeeCupView.liquidColor`), `CoffeeCupView` (now takes a `liquidColor` parameter, default `CoffeeAccent.default.color`), `DurationPickerRow` + `CustomDurationRow` (accent bar + checkmark), `GeneralTab` status dot, `TriggersTab` voting indicator, `AboutTab` hero cup. UI: `GeneralTab` Appearance section gains a `Coffee tone` Picker (5 rows with 12pt color-dot preview + display name + short description) **plus** a `Preview` `LabeledContent` row at the top with a 36pt `CoffeeCupView` so the user can see the live tone change while interacting with the picker — necessary because the menu-bar popover auto-closes when Settings takes focus. Tests: 17 added (12 `CoffeeAccentTests` covering case order, raw-value stability, decode tolerance, color resolution; 5 `AppEnvironmentTests` covering hydrate/write-through/no-op short-circuit on the accent property). 195/195 pass. |

---

## 14. Sign-off Checklist

- [x] Owner accepts module/folder structure (§3)
- [x] Owner accepts ObservableObject decision (§5.2)
- [x] Owner accepts no-third-party-deps stance (§7.2)
- [x] Owner accepts the trigger vote-stream pattern over direct manager calls (§4.4–4.5)
- [x] Owner agrees with the gap list in §10 (rewrite work in session 3)

Approved 2026-04-25 (session 2 close). Subsequent edits require a version bump and a note in §13.
