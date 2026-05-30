import Foundation
import Combine
import Darwin
import os

// MARK: - Public value types

public enum AwakeReason: Equatable, Sendable {
    case user
    case trigger(id: String)
    case launch
    case none
}

public struct TriggerVote: Equatable, Sendable {
    public let wantsAwake: Bool
    public let reason: String
    public let until: Date?
    /// Cool-down period (seconds) the state machine should hold the awake
    /// assertion before releasing it, when this vote turns OFF the last
    /// active trigger. 0 = release immediately (the v1 default for all
    /// triggers — see `Trigger.graceSecondsAfterOff`). Only meaningful on
    /// `wantsAwake == false` votes; ignored on ON votes.
    public let graceSecondsAfterOff: TimeInterval

    public init(
        wantsAwake: Bool,
        reason: String,
        until: Date? = nil,
        graceSecondsAfterOff: TimeInterval = 0
    ) {
        self.wantsAwake = wantsAwake
        self.reason = reason
        self.until = until
        self.graceSecondsAfterOff = graceSecondsAfterOff
    }
}

// MARK: - State machine

public enum AwakeState: Equatable, Sendable {
    case asleep
    case awakeUserIndefinite
    case awakeUserTimed(endsAt: Date)
    case awakeTriggered(votes: [String: TriggerVote])
    case coolingDown(until: Date, lastVotes: [String: TriggerVote])
    case snoozed(until: Date)

    public var isAwake: Bool {
        switch self {
        case .asleep, .snoozed: return false
        case .awakeUserIndefinite, .awakeUserTimed, .awakeTriggered, .coolingDown: return true
        }
    }

    public var assertionHeld: Bool { isAwake }

    public var endsAt: Date? {
        switch self {
        case .awakeUserTimed(let endsAt): return endsAt
        case .coolingDown(let until, _): return until
        case .snoozed(let until): return until
        case .asleep, .awakeUserIndefinite, .awakeTriggered: return nil
        }
    }
}

extension AwakeState: CustomStringConvertible {
    /// Privacy-safe rendering for os_log. The transition logger emits this at
    /// `privacy: .public`, so it must NOT include `TriggerVote.reason` — which
    /// carries user content (Wi-Fi SSID, calendar event title, running-app
    /// names). `.awakeTriggered` / `.coolingDown` therefore expose only the
    /// static voting trigger IDs (e.g. "wifi"), never the reasons. The default
    /// reflected `String(describing:)` would leak the full vote structs.
    public var description: String {
        switch self {
        case .asleep:
            return "asleep"
        case .awakeUserIndefinite:
            return "awakeUserIndefinite"
        case .awakeUserTimed(let endsAt):
            return "awakeUserTimed(endsAt: \(endsAt.timeIntervalSince1970))"
        case .awakeTriggered(let votes):
            return "awakeTriggered(triggers: \(Self.triggerIDList(votes)))"
        case .coolingDown(let until, let lastVotes):
            return "coolingDown(until: \(until.timeIntervalSince1970), triggers: \(Self.triggerIDList(lastVotes)))"
        case .snoozed(let until):
            return "snoozed(until: \(until.timeIntervalSince1970))"
        }
    }

    /// Sorted trigger IDs only — deterministic and PII-free.
    private static func triggerIDList(_ votes: [String: TriggerVote]) -> String {
        "[" + votes.keys.sorted().joined(separator: ", ") + "]"
    }
}

public enum AwakeInput: Equatable, Sendable {
    case userActivate(AwakeDuration)
    case userDeactivate
    case userToggle
    case triggerVoteOn(id: String, vote: TriggerVote)
    /// `graceSeconds` controls the post-OFF cool-down. 0 = release the
    /// assertion immediately and transition `.awakeTriggered → .asleep`
    /// when this is the last vote; >0 = honor the cool-down period before
    /// going to sleep. Sourced from the `TriggerVote` that wraps this
    /// transition (or 0 for user-explicit Toggle OFF / list edits).
    case triggerVoteOff(id: String, graceSeconds: TimeInterval)
    /// **S22 / P-issue-5**: a system-level constraint (pause-all flipping
    /// ON, AC unplug while requireAC) forces deactivation. Distinct from
    /// `.userDeactivate` because:
    /// - constraint-driven deactivate from `.awakeTriggered` must NOT
    ///   enter `.snoozed` — that would set `endsAt = now + 5min` and
    ///   `activeReason = .user`, painting a misleading "Until X" caption
    ///   in the header even though the user didn't initiate a session.
    /// - it must clear `pendingVotes` since the constraint says "ignore
    ///   triggers"; preserving the shadow set would replay a stale ON
    ///   when the constraint lifts.
    case constraintDeactivate
    case timerExpired
    case coolDownExpired
    case snoozeExpired
}

// MARK: - Side effects

public enum TimerKind: Equatable, Sendable { case duration, coolDown, snooze }

public enum SideEffect: Equatable, Sendable {
    case acquireAssertion
    case releaseAssertion
    case refreshAssertion
    case scheduleTimer(kind: TimerKind, fireAt: Date)
    case cancelTimer(kind: TimerKind)
    case logFault(String)
}

// MARK: - Constants

public enum AwakeManagerConstants {
    public static let coolDownSeconds: TimeInterval = 60
    public static let snoozeSeconds: TimeInterval = 5 * 60
}

// MARK: - Pure step function

public struct AwakeStepResult: Equatable {
    public let state: AwakeState
    public let pendingVotes: [String: TriggerVote]
    public let effects: [SideEffect]
    public let activeReason: AwakeReason
}

public enum AwakeStateMachine {

    /// Pure step function. Given (state, pendingVotes, input, now) returns the new
    /// state, new shadow set, ordered side effects, and the user-facing reason.
    public static func step(
        state: AwakeState,
        pendingVotes: [String: TriggerVote],
        input: AwakeInput,
        now: Date
    ) -> AwakeStepResult {
        // Desugar userToggle at the boundary per 03 §4.
        if case .userToggle = input {
            let resolved: AwakeInput = state.assertionHeld ? .userDeactivate : .userActivate(.indefinite)
            return step(state: state, pendingVotes: pendingVotes, input: resolved, now: now)
        }

        // S22 / P-issue-5: constraint-driven deactivate (pause-all flips
        // ON, AC unplug while requireAC) routes through a single helper
        // that goes directly to `.asleep`, clears pendingVotes (constraint
        // forbids shadow replay), sets reason=.none, releases the
        // assertion, and cancels any pending timer for the leaving state.
        // Distinct from `.userDeactivate` to avoid the misleading
        // "Until X" snooze caption.
        if case .constraintDeactivate = input {
            return constraintDeactivateResult(leavingState: state)
        }

        switch (state, input) {

        // MARK: Asleep

        case (.asleep, .userActivate(let d)):
            return enter(userDuration: d, leavingState: state, pendingVotes: pendingVotes, now: now, reason: .user)

        case (.asleep, .userDeactivate):
            return noChange(state: state, pendingVotes: pendingVotes, reason: .none)

        case (.asleep, .triggerVoteOn(let id, let vote)):
            // Asleep cannot have a shadow set (none can exist here per table).
            let votes = [id: vote]
            return enterAwakeTriggered(votes: votes, leavingState: state, pendingVotes: [:], now: now)

        case (.asleep, .triggerVoteOff):
            return noChange(state: state, pendingVotes: pendingVotes, reason: .none)

        case (.asleep, .timerExpired),
             (.asleep, .coolDownExpired),
             (.asleep, .snoozeExpired):
            return invariantViolation(state: state, pendingVotes: pendingVotes, message: "expired timer in Asleep")

        // MARK: AwakeUserIndefinite

        case (.awakeUserIndefinite, .userActivate(let d)):
            return enter(userDuration: d, leavingState: state, pendingVotes: pendingVotes, now: now, reason: .user)

        case (.awakeUserIndefinite, .userDeactivate):
            return resolveDeactivate(from: state, pendingVotes: pendingVotes, now: now)

        case (.awakeUserIndefinite, .triggerVoteOn(let id, let vote)):
            var newPending = pendingVotes
            newPending[id] = vote
            return noChange(state: state, pendingVotes: newPending, reason: .user)

        case (.awakeUserIndefinite, .triggerVoteOff(let id, _)):
            var newPending = pendingVotes
            newPending.removeValue(forKey: id)
            return noChange(state: state, pendingVotes: newPending, reason: .user)

        case (.awakeUserIndefinite, .timerExpired),
             (.awakeUserIndefinite, .coolDownExpired),
             (.awakeUserIndefinite, .snoozeExpired):
            return invariantViolation(state: state, pendingVotes: pendingVotes, message: "expired timer in AwakeUserIndefinite")

        // MARK: AwakeUserTimed

        case (.awakeUserTimed, .userActivate(let d)):
            // Replace timer (idempotent if d is the same).
            return enter(userDuration: d, leavingState: state, pendingVotes: pendingVotes, now: now, reason: .user)

        case (.awakeUserTimed, .userDeactivate):
            return resolveDeactivate(from: state, pendingVotes: pendingVotes, now: now)

        case (.awakeUserTimed, .triggerVoteOn(let id, let vote)):
            var newPending = pendingVotes
            newPending[id] = vote
            return noChange(state: state, pendingVotes: newPending, reason: .user)

        case (.awakeUserTimed, .triggerVoteOff(let id, _)):
            var newPending = pendingVotes
            newPending.removeValue(forKey: id)
            return noChange(state: state, pendingVotes: newPending, reason: .user)

        case (.awakeUserTimed, .timerExpired):
            return resolveTimerExpired(pendingVotes: pendingVotes, leavingState: state, now: now)

        case (.awakeUserTimed, .coolDownExpired),
             (.awakeUserTimed, .snoozeExpired):
            return invariantViolation(state: state, pendingVotes: pendingVotes, message: "stale timer in AwakeUserTimed")

        // MARK: AwakeTriggered

        case (.awakeTriggered(let votes), .userActivate(let d)):
            // Per §7: votes preserved in shadow set when promoting to user-timed.
            return enter(userDuration: d, leavingState: state, pendingVotes: votes, now: now, reason: .user)

        case (.awakeTriggered, .userDeactivate):
            return enterSnoozed(leavingState: state, pendingVotes: votesFromState(state), now: now)

        case (.awakeTriggered(var votes), .triggerVoteOn(let id, let vote)):
            votes[id] = vote
            let voteReason: AwakeReason = .trigger(id: id)
            // Stay in awakeTriggered; assertion already held.
            return AwakeStepResult(
                state: .awakeTriggered(votes: votes),
                pendingVotes: pendingVotes,
                effects: [],
                activeReason: voteReason
            )

        case (.awakeTriggered(let votes), .triggerVoteOff(let id, let graceSeconds)):
            var newVotes = votes
            newVotes.removeValue(forKey: id)
            if newVotes.isEmpty {
                if graceSeconds <= 0 {
                    // Per-trigger grace = 0 (the v1 default for all triggers): release
                    // the assertion immediately. User-explicit OFF actions also flow
                    // through this branch with graceSeconds=0.
                    return AwakeStepResult(
                        state: .asleep,
                        pendingVotes: [:],
                        effects: [.releaseAssertion],
                        activeReason: .none
                    )
                } else {
                    // Honor the trigger's declared grace period via cool-down.
                    let until = now.addingTimeInterval(graceSeconds)
                    return AwakeStepResult(
                        state: .coolingDown(until: until, lastVotes: votes),
                        pendingVotes: pendingVotes,
                        effects: [.scheduleTimer(kind: .coolDown, fireAt: until)],
                        activeReason: lastReason(votes: votes)
                    )
                }
            } else {
                return AwakeStepResult(
                    state: .awakeTriggered(votes: newVotes),
                    pendingVotes: pendingVotes,
                    effects: [],
                    activeReason: lastReason(votes: newVotes)
                )
            }

        case (.awakeTriggered, .timerExpired),
             (.awakeTriggered, .coolDownExpired),
             (.awakeTriggered, .snoozeExpired):
            return invariantViolation(state: state, pendingVotes: pendingVotes, message: "stale timer in AwakeTriggered")

        // MARK: CoolingDown

        case (.coolingDown, .userActivate(let d)):
            return enter(userDuration: d, leavingState: state, pendingVotes: pendingVotes, now: now, reason: .user)

        case (.coolingDown, .userDeactivate):
            return enterSnoozed(leavingState: state, pendingVotes: pendingVotes, now: now)

        case (.coolingDown, .triggerVoteOn(let id, let vote)):
            // Cancel cool-down timer; return to awakeTriggered with this single new vote.
            let votes = [id: vote]
            return AwakeStepResult(
                state: .awakeTriggered(votes: votes),
                pendingVotes: pendingVotes,
                effects: [.cancelTimer(kind: .coolDown)],
                activeReason: .trigger(id: id)
            )

        case (.coolingDown, .triggerVoteOff):
            // Vote was already removed when entering CoolingDown.
            return noChange(state: state, pendingVotes: pendingVotes, reason: lastReason(forCooling: state))

        case (.coolingDown, .coolDownExpired):
            return AwakeStepResult(
                state: .asleep,
                pendingVotes: [:],
                effects: [.cancelTimer(kind: .coolDown), .releaseAssertion],
                activeReason: .none
            )

        case (.coolingDown, .timerExpired),
             (.coolingDown, .snoozeExpired):
            return invariantViolation(state: state, pendingVotes: pendingVotes, message: "stale timer in CoolingDown")

        // MARK: Snoozed

        case (.snoozed, .userActivate(let d)):
            // Cancel snooze timer, enter user state.
            return enter(userDuration: d, leavingState: state, pendingVotes: pendingVotes, now: now, reason: .user)

        case (.snoozed, .userDeactivate):
            return noChange(state: state, pendingVotes: pendingVotes, reason: .user)

        case (.snoozed, .triggerVoteOn(let id, let vote)):
            // Snooze suppresses; record in shadow set only.
            var newPending = pendingVotes
            newPending[id] = vote
            return noChange(state: state, pendingVotes: newPending, reason: .user)

        case (.snoozed, .triggerVoteOff(let id, _)):
            var newPending = pendingVotes
            newPending.removeValue(forKey: id)
            return noChange(state: state, pendingVotes: newPending, reason: .user)

        case (.snoozed, .snoozeExpired):
            return resolveSnoozeExpired(pendingVotes: pendingVotes, leavingState: state, now: now)

        case (.snoozed, .timerExpired),
             (.snoozed, .coolDownExpired):
            return invariantViolation(state: state, pendingVotes: pendingVotes, message: "stale timer in Snoozed")

        // userToggle is desugared at top of function; leave a defensive default.
        case (_, .userToggle):
            return noChange(state: state, pendingVotes: pendingVotes, reason: .none)

        // constraintDeactivate is short-circuited at top of function via
        // `constraintDeactivateResult(leavingState:)`; the catch-all here
        // makes the switch exhaustive over the input enum and would only
        // hit if the early-return is removed by a future edit.
        case (_, .constraintDeactivate):
            return constraintDeactivateResult(leavingState: state)
        }
    }

    // MARK: - Helpers

    /// Single source-of-truth for constraint-driven deactivation. See
    /// `AwakeInput.constraintDeactivate` doc-comment for design rationale.
    private static func constraintDeactivateResult(leavingState: AwakeState) -> AwakeStepResult {
        var effects: [SideEffect] = leaveTimers(leavingState)
        if leavingState.assertionHeld {
            effects.append(.releaseAssertion)
        }
        return AwakeStepResult(
            state: .asleep,
            pendingVotes: [:],
            effects: effects,
            activeReason: .none
        )
    }

    private static func noChange(
        state: AwakeState,
        pendingVotes: [String: TriggerVote],
        reason: AwakeReason
    ) -> AwakeStepResult {
        AwakeStepResult(state: state, pendingVotes: pendingVotes, effects: [], activeReason: reason)
    }

    private static func invariantViolation(
        state: AwakeState,
        pendingVotes: [String: TriggerVote],
        message: String
    ) -> AwakeStepResult {
        AwakeStepResult(
            state: state,
            pendingVotes: pendingVotes,
            effects: [.logFault(message)],
            activeReason: .none
        )
    }

    /// Enter a user-driven awake state. Picks indefinite vs timed by the duration.
    /// Cancels any leaving-state timers.
    private static func enter(
        userDuration duration: AwakeDuration,
        leavingState: AwakeState,
        pendingVotes: [String: TriggerVote],
        now: Date,
        reason: AwakeReason
    ) -> AwakeStepResult {
        var effects: [SideEffect] = []
        // Cancel any timer associated with the leaving state.
        effects.append(contentsOf: leaveTimers(leavingState))

        let needsAcquire = !leavingState.assertionHeld
        if needsAcquire { effects.append(.acquireAssertion) }

        if let seconds = duration.seconds {
            let endsAt = now.addingTimeInterval(seconds)
            effects.append(.scheduleTimer(kind: .duration, fireAt: endsAt))
            return AwakeStepResult(
                state: .awakeUserTimed(endsAt: endsAt),
                pendingVotes: pendingVotes,
                effects: effects,
                activeReason: reason
            )
        } else {
            return AwakeStepResult(
                state: .awakeUserIndefinite,
                pendingVotes: pendingVotes,
                effects: effects,
                activeReason: reason
            )
        }
    }

    private static func enterAwakeTriggered(
        votes: [String: TriggerVote],
        leavingState: AwakeState,
        pendingVotes: [String: TriggerVote],
        now: Date
    ) -> AwakeStepResult {
        var effects: [SideEffect] = []
        effects.append(contentsOf: leaveTimers(leavingState))
        if !leavingState.assertionHeld { effects.append(.acquireAssertion) }
        return AwakeStepResult(
            state: .awakeTriggered(votes: votes),
            pendingVotes: pendingVotes,
            effects: effects,
            activeReason: lastReason(votes: votes)
        )
    }

    private static func enterSnoozed(
        leavingState: AwakeState,
        pendingVotes: [String: TriggerVote],
        now: Date
    ) -> AwakeStepResult {
        let until = now.addingTimeInterval(AwakeManagerConstants.snoozeSeconds)
        var effects: [SideEffect] = []
        effects.append(contentsOf: leaveTimers(leavingState))
        if leavingState.assertionHeld { effects.append(.releaseAssertion) }
        effects.append(.scheduleTimer(kind: .snooze, fireAt: until))
        return AwakeStepResult(
            state: .snoozed(until: until),
            pendingVotes: pendingVotes,
            effects: effects,
            activeReason: .user
        )
    }

    /// AwakeUserIndefinite or AwakeUserTimed received userDeactivate.
    private static func resolveDeactivate(
        from leavingState: AwakeState,
        pendingVotes: [String: TriggerVote],
        now: Date
    ) -> AwakeStepResult {
        let active = aggregateActiveVotes(pendingVotes)
        if !active.isEmpty {
            return enterSnoozed(leavingState: leavingState, pendingVotes: pendingVotes, now: now)
        }
        var effects: [SideEffect] = leaveTimers(leavingState)
        if leavingState.assertionHeld { effects.append(.releaseAssertion) }
        return AwakeStepResult(
            state: .asleep,
            pendingVotes: [:],
            effects: effects,
            activeReason: .none
        )
    }

    /// AwakeUserTimed timerExpired: promote shadow set if any want awake; else asleep.
    private static func resolveTimerExpired(
        pendingVotes: [String: TriggerVote],
        leavingState: AwakeState,
        now: Date
    ) -> AwakeStepResult {
        let active = aggregateActiveVotes(pendingVotes)
        if !active.isEmpty {
            // Promote shadow set into awakeTriggered. Assertion stays held.
            return AwakeStepResult(
                state: .awakeTriggered(votes: active),
                pendingVotes: [:],
                effects: [.cancelTimer(kind: .duration)],
                activeReason: lastReason(votes: active)
            )
        }
        return AwakeStepResult(
            state: .asleep,
            pendingVotes: [:],
            effects: [.cancelTimer(kind: .duration), .releaseAssertion],
            activeReason: .none
        )
    }

    /// Snoozed snoozeExpired: promote shadow set if any want awake; else asleep.
    private static func resolveSnoozeExpired(
        pendingVotes: [String: TriggerVote],
        leavingState: AwakeState,
        now: Date
    ) -> AwakeStepResult {
        let active = aggregateActiveVotes(pendingVotes)
        if !active.isEmpty {
            return AwakeStepResult(
                state: .awakeTriggered(votes: active),
                pendingVotes: [:],
                effects: [.cancelTimer(kind: .snooze), .acquireAssertion],
                activeReason: lastReason(votes: active)
            )
        }
        return AwakeStepResult(
            state: .asleep,
            pendingVotes: [:],
            effects: [.cancelTimer(kind: .snooze)],
            activeReason: .none
        )
    }

    private static func leaveTimers(_ state: AwakeState) -> [SideEffect] {
        switch state {
        case .awakeUserTimed: return [.cancelTimer(kind: .duration)]
        case .coolingDown: return [.cancelTimer(kind: .coolDown)]
        case .snoozed: return [.cancelTimer(kind: .snooze)]
        case .asleep, .awakeUserIndefinite, .awakeTriggered: return []
        }
    }

    private static func aggregateActiveVotes(_ votes: [String: TriggerVote]) -> [String: TriggerVote] {
        votes.filter { $0.value.wantsAwake }
    }

    private static func votesFromState(_ state: AwakeState) -> [String: TriggerVote] {
        if case .awakeTriggered(let votes) = state { return votes }
        return [:]
    }

    private static func lastReason(votes: [String: TriggerVote]) -> AwakeReason {
        guard let id = votes.keys.sorted().first else { return .none }
        return .trigger(id: id)
    }

    private static func lastReason(forCooling state: AwakeState) -> AwakeReason {
        if case .coolingDown(_, let lastVotes) = state {
            return lastReason(votes: lastVotes)
        }
        return .none
    }
}

// MARK: - AwakeManager

@MainActor
public final class AwakeManager: ObservableObject {

    public static let shared = AwakeManager()

    // MARK: Published state
    @Published public private(set) var state: AwakeState = .asleep
    @Published public private(set) var isAwake: Bool = false
    @Published public private(set) var endsAt: Date?
    @Published public private(set) var activeDuration: AwakeDuration?
    @Published public private(set) var activeReason: AwakeReason = .none

    /// **S23 / P-issue-2**: when an awake session was started by clicking a
    /// `RecurringQuickPreset` in the popover, holds that preset's UUID so
    /// the popover can render the checkmark on the matching preset row
    /// instead of the Custom row (the `.minutes(N)` duration derived from
    /// a wall-clock target is never in `AwakeDuration.presets`, so without
    /// this signal the Custom row would claim the active marker).
    /// Cleared automatically on any non-`.awakeUserTimed` state and on any
    /// non-preset activation. Single source of truth — no view-local state
    /// needed.
    @Published public private(set) var activeRecurringPresetID: UUID?

    // MARK: Settings
    @Published public var allowDisplaySleep: Bool {
        didSet {
            settings.setBool(allowDisplaySleep, for: .allowDisplaySleep)
            if assertion.isActive {
                assertion.activate(mode: assertionMode, reason: "allowDisplaySleep changed")
            }
        }
    }

    /// C-1: when true, Latte never holds an awake assertion while the Mac is
    /// drawing from battery power. ON votes from triggers and manual
    /// activations are blocked at the manager input boundary; if the
    /// constraint flips on while currently awake (or AC is unplugged while
    /// awake), the manager auto-deactivates.
    @Published public var requireACForAwake: Bool {
        didSet {
            settings.setBool(requireACForAwake, for: .requireACForAwake)
            enforceConstraintsIfNeeded(reason: "requireACForAwake changed")
        }
    }

    /// C-9: when true, all trigger votes are ignored. Manual activation
    /// (popover Duration rows / Toggle action / AppIntents) still works —
    /// "pause" is for triggers, not for the user's explicit intent. If
    /// flipped on while currently in `.awakeTriggered`, the manager
    /// auto-deactivates so the cup doesn't linger on stale trigger votes.
    /// **S22 / P-issue-5**: when flipping OFF (pause lifted), posts
    /// `.latteTriggerPauseDidLift` so `TriggerCoordinator` can ask every
    /// enabled trigger to re-evaluate and re-emit the current vote —
    /// otherwise the cup stays asleep until each trigger naturally
    /// re-fires (which never happens for steady-state conditions like
    /// "Notion is still running").
    @Published public var triggersPaused: Bool {
        didSet {
            settings.setBool(triggersPaused, for: .triggersPaused)
            enforceConstraintsIfNeeded(reason: "triggersPaused changed")
            if oldValue && !triggersPaused {
                NotificationCenter.default.post(name: .latteTriggerPauseDidLift, object: self)
            }
        }
    }

    /// Snapshot of the current AC state. Updated by `powerSource.observe`.
    @Published public private(set) var isOnAC: Bool

    // MARK: Internals
    private let assertion: PowerAssertionType
    private let powerSource: PowerSourceType
    private let settings: SettingsStore
    private let logger = LatteLog.awake
    private var pendingVotes: [String: TriggerVote] = [:]
    private var lastUserDuration: AwakeDuration?

    private var durationTask: Task<Void, Never>?
    private var coolDownTask: Task<Void, Never>?
    private var snoozeTask: Task<Void, Never>?
    private var powerObservation: PowerSourceObservation?

    private static var signalHandlerInstalled = false

    public init(
        assertion: PowerAssertionType = PowerAssertion(),
        settings: SettingsStore = UserDefaultsSettingsStore(),
        powerSource: PowerSourceType? = nil
    ) {
        self.assertion = assertion
        self.settings = settings
        if let powerSource {
            self.powerSource = powerSource
        } else {
            #if canImport(IOKit)
            self.powerSource = IOPowerSource()
            #else
            self.powerSource = MockPowerSource(isOnAC: true)
            #endif
        }
        self.allowDisplaySleep = settings.bool(.allowDisplaySleep, default: false)
        self.requireACForAwake = settings.bool(.requireACForAwake, default: false)
        self.triggersPaused = settings.bool(.triggersPaused, default: false)
        self.isOnAC = self.powerSource.isOnAC
        self.powerObservation = self.powerSource.observe { [weak self] onAC in
            guard let self else { return }
            self.isOnAC = onAC
            self.enforceConstraintsIfNeeded(reason: "AC state \(onAC ? "ON" : "OFF")")
        }
    }

    isolated deinit {
        // PowerSourceObservation cancellation is @MainActor. `isolated deinit`
        // (SE-0371) runs this teardown on the main actor so it can touch the
        // isolated `powerObservation`. Drop the strong ref; the IOPowerSource
        // observer table also drops via [weak self], so the run-loop callback
        // no-ops.
        powerObservation = nil
    }

    // MARK: Public API

    public func toggle() {
        let wasAwake = state.isAwake
        // **S22 / P-issue-6c**: when toggling from awake → not-awake, route
        // through `.constraintDeactivate` so we go directly to `.asleep`
        // (clearing pendingVotes, no snooze). The original `.userToggle →
        // .userDeactivate → enterSnoozed` path locked the manager in
        // `.snoozed` for 5 min, which suppressed any vote ON from a
        // user-re-enabled trigger — owner reported during the resumed Step
        // 6 manual smoke that re-enabling AppTrigger after Turn off did
        // not wake the cup until snooze expired. Snooze was originally
        // meant to prevent immediate re-fire from the SAME trigger; with
        // P-issue-6's `disableAll()` clearing the trigger config on
        // user-explicit deactivate, snooze is moot — the trigger can't
        // re-fire until the user explicitly re-enables it, at which
        // point an immediate wake is the correct UX.
        if state.assertionHeld {
            process(.constraintDeactivate)
        } else {
            process(.userActivate(.indefinite))
        }
        postUserExplicitDeactivateIfTransitioned(wasAwake: wasAwake)
    }

    public func activate(
        for duration: AwakeDuration,
        reason: AwakeReason = .user,
        fromRecurringPreset presetID: UUID? = nil
    ) {
        if let block = blockReason(forManualActivation: true) {
            logger.info("manual activation blocked: \(block, privacy: .public)")
            return
        }
        lastUserDuration = duration
        // S23 / P-issue-2: set BEFORE process() so publishDerived sees the
        // correct value when transitioning into .awakeUserTimed. Non-preset
        // callers default to nil → existing presetID gets cleared, so a
        // manual 30m click after a preset click correctly drops the marker.
        activeRecurringPresetID = presetID
        process(.userActivate(duration))
        // The FSM hardcodes `.user` as the reason for `.userActivate` inputs
        // because the input itself doesn't carry one. When the caller wants
        // a different presentation reason (e.g. `.launch` for the
        // "Activate at launch" feature), override the published reason
        // post-step. State + side-effects are unchanged; only the label
        // swaps. Skip when the FSM short-circuited (e.g. blocked by a
        // constraint) — `isAwake` would be false in that case.
        if reason != .user, isAwake {
            activeReason = reason
        }
    }

    public func deactivate(reason: AwakeReason = .user) {
        let wasAwake = state.isAwake
        // **S22 / P-issue-6c**: see `toggle()` doc-comment. User-explicit
        // deactivate routes through `.constraintDeactivate` so we go
        // directly to `.asleep` and skip the 5-min snooze that would
        // otherwise suppress vote ON from a re-enabled trigger.
        process(.constraintDeactivate)
        postUserExplicitDeactivateIfTransitioned(wasAwake: wasAwake)
    }

    /// **S22 / P-issue-6**: when an awake state is dismissed by an
    /// explicit user action (popover Turn off, ⌘⇧L toggle, AppIntent
    /// deactivate), post `.latteUserExplicitDeactivate` so the
    /// `TriggerCoordinator` can disable every enabled trigger. This
    /// makes Turn off the "big red button" — Pause-all keeps triggers
    /// enabled (temporary), Turn off disables them (explicit
    /// termination). No post when the manager wasn't awake to begin
    /// with, and no post when the post-process state is still awake
    /// (e.g. `.userActivate` from a toggle).
    private func postUserExplicitDeactivateIfTransitioned(wasAwake: Bool) {
        guard wasAwake, !state.isAwake else { return }
        NotificationCenter.default.post(name: .latteUserExplicitDeactivate, object: self)
    }

    public func receiveTriggerVote(_ vote: TriggerVote, from triggerId: String) {
        if vote.wantsAwake {
            if let block = blockReason(forManualActivation: false) {
                logger.info("trigger ON vote dropped (\(triggerId, privacy: .public)): \(block, privacy: .public)")
                return
            }
            process(.triggerVoteOn(id: triggerId, vote: vote))
        } else {
            // OFF votes always flow so pendingVotes stays in sync; if the
            // user un-pauses or plugs back in, we don't replay stale ON state.
            process(.triggerVoteOff(id: triggerId, graceSeconds: vote.graceSecondsAfterOff))
        }
    }

    /// Installs SIGINT/SIGTERM handlers that release the assertion on
    /// deliberate termination. Idempotent — safe to call multiple times.
    ///
    /// Deliberately does NOT handle SIGABRT: that signal is raised from an
    /// already-faulting runtime (failed assertion, abort()), where spawning
    /// a Swift `Task` is unsafe and — worse — catching it suppresses the OS
    /// crash report, blinding production debugging. The kernel releases the
    /// IOPMAssertion automatically on process death, so the handler buys
    /// nothing on the crash path. SIGINT/SIGTERM are user-driven terminations
    /// delivered while the process is in a normal state, so the best-effort
    /// Task-based release is acceptable there.
    public static func installSignalHandlers() {
        guard !signalHandlerInstalled else { return }
        signalHandlerInstalled = true
        let handler: @convention(c) (Int32) -> Void = { _ in
            // Cannot capture self in @convention(c); use shared singleton.
            // Best-effort assertion release; the process is exiting.
            Task { @MainActor in
                AwakeManager.shared.deactivate()
                exit(0)
            }
        }
        signal(SIGINT, handler)
        signal(SIGTERM, handler)
    }

    // MARK: Constraint enforcement (C-1, C-9)

    /// Returns a non-nil reason string if the current input should be
    /// blocked. `forManualActivation` distinguishes user-explicit
    /// activation (popover/intent/menu) from trigger ON votes — pause-all
    /// affects only triggers, AC requirement affects both.
    private func blockReason(forManualActivation: Bool) -> String? {
        if requireACForAwake && !isOnAC {
            return "battery-aware mode active and Mac is on battery"
        }
        if !forManualActivation && triggersPaused {
            return "triggers are paused"
        }
        return nil
    }

    /// Called from constraint-flag `didSet` and AC-state observer. If the
    /// new state forbids the current awake state, drive `process(.constraintDeactivate)`
    /// to release the assertion and unwind directly to `.asleep`
    /// (clearing pendingVotes — see input doc-comment for rationale).
    /// Idempotent.
    private func enforceConstraintsIfNeeded(reason: String) {
        guard state.assertionHeld else { return }
        // Manual awake states (.awakeUserIndefinite, .awakeUserTimed) are only
        // affected by the AC constraint — pause-all does not override the
        // user's explicit intent. Trigger-driven states (.awakeTriggered,
        // .coolingDown) are affected by both.
        let isManualState: Bool
        switch state {
        case .awakeUserIndefinite, .awakeUserTimed: isManualState = true
        default: isManualState = false
        }
        if let block = blockReason(forManualActivation: isManualState) {
            logger.info("constraint-driven deactivate (\(reason, privacy: .public)): \(block, privacy: .public)")
            process(.constraintDeactivate)
        }
    }

    // MARK: Step + side effects

    private var assertionMode: PowerAssertionMode {
        allowDisplaySleep ? .systemOnly : .displayAndSystem
    }

    private func process(_ input: AwakeInput) {
        let result = AwakeStateMachine.step(
            state: state,
            pendingVotes: pendingVotes,
            input: input,
            now: Date()
        )
        applyTransition(result)
    }

    private func applyTransition(_ result: AwakeStepResult) {
        let prev = state
        // Update state & shadow set first so derived published values are coherent.
        state = result.state
        pendingVotes = result.pendingVotes
        applyEffects(result.effects)
        publishDerived()
        activeReason = result.activeReason
        logger.info("transition \(String(describing: prev), privacy: .public) -> \(String(describing: result.state), privacy: .public)")
    }

    private func publishDerived() {
        isAwake = state.isAwake
        switch state {
        case .awakeUserTimed(let endsAt):
            self.endsAt = endsAt
            self.activeDuration = lastUserDuration
            // activeRecurringPresetID is set by activate(...) before process()
            // and intentionally preserved here.
        case .awakeUserIndefinite:
            self.endsAt = nil
            self.activeDuration = .indefinite
            self.activeRecurringPresetID = nil
        case .asleep, .awakeTriggered, .coolingDown, .snoozed:
            self.endsAt = state.endsAt
            self.activeDuration = nil
            self.activeRecurringPresetID = nil
        }
    }

    private func applyEffects(_ effects: [SideEffect]) {
        for effect in effects {
            switch effect {
            case .acquireAssertion:
                assertion.activate(mode: assertionMode, reason: "Latte awake")
            case .releaseAssertion:
                assertion.deactivate()
            case .refreshAssertion:
                if assertion.isActive {
                    assertion.activate(mode: assertionMode, reason: "Latte mode change")
                }
            case .scheduleTimer(let kind, let fireAt):
                schedule(kind: kind, fireAt: fireAt)
            case .cancelTimer(let kind):
                cancelTimer(kind)
            case .logFault(let message):
                logger.fault("invariant violated: \(message, privacy: .public)")
            }
        }
    }

    private func schedule(kind: TimerKind, fireAt: Date) {
        cancelTimer(kind)
        let interval = max(0, fireAt.timeIntervalSinceNow)
        let task = Task { @MainActor [weak self] in
            let nanos = UInt64(interval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            if Task.isCancelled { return }
            guard let self else { return }
            switch kind {
            case .duration: self.process(.timerExpired)
            case .coolDown: self.process(.coolDownExpired)
            case .snooze: self.process(.snoozeExpired)
            }
        }
        switch kind {
        case .duration: durationTask = task
        case .coolDown: coolDownTask = task
        case .snooze: snoozeTask = task
        }
    }

    private func cancelTimer(_ kind: TimerKind) {
        switch kind {
        case .duration:
            durationTask?.cancel()
            durationTask = nil
        case .coolDown:
            coolDownTask?.cancel()
            coolDownTask = nil
        case .snooze:
            snoozeTask?.cancel()
            snoozeTask = nil
        }
    }
}

extension Notification.Name {
    /// **S22 / P-issue-5**: posted by `AwakeManager` when `triggersPaused`
    /// transitions from true → false. `TriggerCoordinator` listens and
    /// asks every enabled trigger to re-evaluate so steady-state
    /// conditions (e.g. "Notion is still running") re-emit a vote ON and
    /// the cup wakes back up. Object is the posting `AwakeManager`.
    public static let latteTriggerPauseDidLift = Notification.Name("LatteTriggerPauseDidLift")

    /// **S22 / P-issue-6**: posted by `AwakeManager` when an explicit
    /// user action (popover Turn off, ⌘⇧L toggle from awake, AppIntent
    /// deactivate) transitions the manager from awake → not-awake.
    /// `TriggerCoordinator` listens and disables every enabled trigger
    /// — the "big red button" semantic that delineates Pause-all
    /// (temporary, triggers stay enabled) from Turn off (explicit
    /// termination, triggers must be re-enabled in Settings to resume).
    /// Object is the posting `AwakeManager`.
    public static let latteUserExplicitDeactivate = Notification.Name("LatteUserExplicitDeactivate")
}
