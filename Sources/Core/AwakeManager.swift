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

    public init(wantsAwake: Bool, reason: String, until: Date? = nil) {
        self.wantsAwake = wantsAwake
        self.reason = reason
        self.until = until
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

public enum AwakeInput: Equatable, Sendable {
    case userActivate(AwakeDuration)
    case userDeactivate
    case userToggle
    case triggerVoteOn(id: String, vote: TriggerVote)
    case triggerVoteOff(id: String)
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

        case (.awakeUserIndefinite, .triggerVoteOff(let id)):
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

        case (.awakeUserTimed, .triggerVoteOff(let id)):
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

        case (.awakeTriggered(let votes), .triggerVoteOff(let id)):
            let snapshot = votes
            var newVotes = votes
            newVotes.removeValue(forKey: id)
            if newVotes.isEmpty {
                let until = now.addingTimeInterval(AwakeManagerConstants.coolDownSeconds)
                return AwakeStepResult(
                    state: .coolingDown(until: until, lastVotes: snapshot),
                    pendingVotes: pendingVotes,
                    effects: [.scheduleTimer(kind: .coolDown, fireAt: until)],
                    activeReason: lastReason(votes: snapshot)
                )
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

        case (.snoozed, .triggerVoteOff(let id)):
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
        }
    }

    // MARK: - Helpers

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

    // MARK: Settings
    @Published public var allowDisplaySleep: Bool {
        didSet {
            settings.setBool(allowDisplaySleep, for: .allowDisplaySleep)
            if assertion.isActive {
                assertion.activate(mode: assertionMode, reason: "allowDisplaySleep changed")
            }
        }
    }

    // MARK: Internals
    private let assertion: PowerAssertionType
    private let settings: SettingsStore
    private let logger = LatteLog.awake
    private var pendingVotes: [String: TriggerVote] = [:]
    private var lastUserDuration: AwakeDuration?

    private var durationTask: Task<Void, Never>?
    private var coolDownTask: Task<Void, Never>?
    private var snoozeTask: Task<Void, Never>?

    private static var signalHandlerInstalled = false

    public init(
        assertion: PowerAssertionType = PowerAssertion(),
        settings: SettingsStore = UserDefaultsSettingsStore()
    ) {
        self.assertion = assertion
        self.settings = settings
        self.allowDisplaySleep = settings.bool(.allowDisplaySleep, default: false)
    }

    // MARK: Public API

    public func toggle() {
        process(.userToggle)
    }

    public func activate(for duration: AwakeDuration, reason: AwakeReason = .user) {
        lastUserDuration = duration
        process(.userActivate(duration))
    }

    public func deactivate(reason: AwakeReason = .user) {
        process(.userDeactivate)
    }

    public func receiveTriggerVote(_ vote: TriggerVote, from triggerId: String) {
        if vote.wantsAwake {
            process(.triggerVoteOn(id: triggerId, vote: vote))
        } else {
            process(.triggerVoteOff(id: triggerId))
        }
    }

    /// Installs SIGINT/SIGTERM/SIGABRT handlers that release the assertion.
    /// Idempotent — safe to call multiple times.
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
        signal(SIGABRT, handler)
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
        case .awakeUserIndefinite:
            self.endsAt = nil
            self.activeDuration = .indefinite
        case .asleep, .awakeTriggered, .coolingDown, .snoozed:
            self.endsAt = state.endsAt
            self.activeDuration = nil
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
