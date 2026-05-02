import Foundation
import Combine

@MainActor
public final class TriggerCoordinator: ObservableObject {

    @Published public private(set) var triggers: [any Trigger] = []
    @Published public private(set) var activeVotes: [String: TriggerVote] = [:]

    private let awakeManager: AwakeManager
    private let settings: SettingsStore
    private let activityStore: ActivityLogStore?
    private let logger = LatteLog.triggers
    private var consumerTasks: [String: Task<Void, Never>] = [:]
    private var pauseLiftObserver: NSObjectProtocol?

    public init(
        awakeManager: AwakeManager,
        settings: SettingsStore,
        activityStore: ActivityLogStore? = nil
    ) {
        self.awakeManager = awakeManager
        self.settings = settings
        self.activityStore = activityStore
        // S22 / P-issue-5: when pause-all is lifted, ask every enabled
        // trigger to re-emit its current vote. AwakeManager has already
        // cleared pendingVotes via .constraintDeactivate, so the only way
        // a steady-state condition (Notion still running, calendar event
        // still in progress) can wake the cup back up is by replaying
        // through the trigger's voteStream.
        pauseLiftObserver = NotificationCenter.default.addObserver(
            forName: .latteTriggerPauseDidLift,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reevaluateAll()
            }
        }
    }

    deinit {
        if let pauseLiftObserver {
            NotificationCenter.default.removeObserver(pauseLiftObserver)
        }
    }

    /// Asks every enabled trigger to re-evaluate its current condition and
    /// re-emit the vote. Called from the `.latteTriggerPauseDidLift`
    /// observer, but exposed publicly so tests / future callers can drive
    /// it directly.
    public func reevaluateAll() {
        for trigger in triggers where trigger.isEnabled {
            trigger.reevaluateWatched()
        }
    }

    public func register(_ trigger: any Trigger) {
        guard !triggers.contains(where: { $0.id == trigger.id }) else {
            logger.notice("trigger \(trigger.id, privacy: .public) already registered")
            return
        }
        triggers.append(trigger)
    }

    public func startEnabledTriggers() async {
        for trigger in triggers where trigger.isEnabled {
            await start(trigger)
        }
    }

    public func start(_ trigger: any Trigger) async {
        await trigger.start()
        // Reuse the existing consumer task if one is alive — cancelling
        // it on stop would terminate the underlying AsyncStream (the
        // iterator's task-cancellation handler calls storage.cancel()
        // even though we never finished the continuation), so any
        // subsequent yield from a future trigger.start() would be
        // silently dropped. The S8b regression where Toggle OFF→ON left
        // the cup permanently asleep traces directly to that. We keep
        // the consumer alive across the trigger's full registered
        // lifetime; trigger.stop() simply pauses yields.
        guard consumerTasks[trigger.id] == nil else { return }
        let task = Task { @MainActor [weak self] in
            for await vote in trigger.voteStream {
                guard let self else { break }
                self.handleVote(vote, from: trigger.id)
            }
        }
        consumerTasks[trigger.id] = task
    }

    public func stop(_ triggerId: String) {
        if let trigger = triggers.first(where: { $0.id == triggerId }) {
            trigger.stop()
        }
        // Do NOT cancel `consumerTasks[triggerId]`. See `start(_:)` for
        // why — task cancellation cancels the underlying AsyncStream's
        // storage, breaking future restarts. The trigger's own stop()
        // halts emissions; the consumer task simply waits idly until
        // the next start() resumes yielding.
        if activeVotes.removeValue(forKey: triggerId) != nil {
            // User-explicit OFF (Toggle in Settings, etc.) — bypass any
            // per-trigger grace period and release the assertion immediately.
            awakeManager.receiveTriggerVote(
                TriggerVote(
                    wantsAwake: false,
                    reason: "trigger stopped",
                    graceSecondsAfterOff: 0
                ),
                from: triggerId
            )
            recordActivity(triggerId: triggerId, kind: .off, reasonCode: .userToggleOff)
        }
    }

    public func stopAll() {
        for trigger in triggers {
            stop(trigger.id)
        }
    }

    private func handleVote(_ vote: TriggerVote, from triggerId: String) {
        if vote.wantsAwake {
            activeVotes[triggerId] = vote
        } else {
            activeVotes.removeValue(forKey: triggerId)
        }
        awakeManager.receiveTriggerVote(vote, from: triggerId)
        recordActivity(
            triggerId: triggerId,
            kind: vote.wantsAwake ? .on : .off,
            reasonCode: vote.wantsAwake ? .voteOn : .voteOff
        )
    }

    /// Fire-and-forget log to the activity store. No-op if no store is wired
    /// (the unit-test rig path). Privacy: only the structured fields cross the
    /// boundary — the raw `TriggerVote.reason` string is intentionally dropped.
    private func recordActivity(
        triggerId: String,
        kind: ActivityLogEntry.Kind,
        reasonCode: ActivityLogEntry.ReasonCode
    ) {
        guard let activityStore else { return }
        let entry = ActivityLogEntry(
            timestamp: .now,
            triggerId: triggerId,
            kind: kind,
            reasonCode: reasonCode
        )
        Task { await activityStore.append(entry) }
        // Live-refresh signal for an open Activity tab. Posting from
        // @MainActor synchronously (the actor task above is queued; by the
        // time a subscriber's reload `await`s a snapshot, FIFO actor
        // ordering guarantees the append has committed). No userInfo —
        // the canonical consumer just refetches the snapshot, so emitting
        // triggerId/kind to every in-process observer would be needless
        // payload.
        NotificationCenter.default.post(name: .activityLogDidAppend, object: self)
    }
}

extension Notification.Name {
    /// Posted by `TriggerCoordinator` after every activity-log mutation
    /// (vote ON / vote OFF / user-explicit stop). An open Activity tab
    /// listens to this and re-fetches the snapshot so the charts update
    /// while the tab is visible — replaces the prior `.task`-on-appear-only
    /// behaviour. See `docs/design/09-c3-activity-history.md` §10/§14.
    public static let activityLogDidAppend = Notification.Name("LatteActivityLogDidAppend")
}
