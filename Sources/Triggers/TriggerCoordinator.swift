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
    private var userDeactivateObserver: NSObjectProtocol?

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
        // **S22 / P-issue-6b**: queue=nil so the block runs synchronously
        // on the posting thread. AwakeManager.deactivate() and the
        // triggersPaused didSet both run on @MainActor, so the post is
        // from main; queue=.main would defer the block to the next run
        // loop iteration and (per owner-reported runtime evidence) the
        // deferral can leak past UI navigation, leaving Settings UI
        // stale. Synchronous execution + MainActor.assumeIsolated is
        // safe because we only post from MainActor contexts.
        pauseLiftObserver = NotificationCenter.default.addObserver(
            forName: .latteTriggerPauseDidLift,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reevaluateAll()
            }
        }
        // S22 / P-issue-6: when the user explicitly turns off (popover
        // Turn off / ⌘⇧L toggle from awake / AppIntent deactivate),
        // disable every enabled trigger. Pause-all stays the path for
        // temporary suspension; Turn off is the "big red button".
        userDeactivateObserver = NotificationCenter.default.addObserver(
            forName: .latteUserExplicitDeactivate,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.disableAll()
            }
        }
    }

    isolated deinit {
        // `isolated deinit` (SE-0371) runs on the main actor so the teardown
        // can read the @MainActor-isolated observer tokens.
        if let pauseLiftObserver {
            NotificationCenter.default.removeObserver(pauseLiftObserver)
        }
        if let userDeactivateObserver {
            NotificationCenter.default.removeObserver(userDeactivateObserver)
        }
    }

    /// Asks every enabled trigger to re-emit its current vote based on
    /// present conditions. Called from the `.latteTriggerPauseDidLift`
    /// observer, but exposed publicly so tests / future callers can drive
    /// it directly. **S22 / P-issue-5b**: switched from
    /// `reevaluateWatched()` (Settings-driven, dedup-on-no-diff) to
    /// `reemitCurrentVote()` (constraint-driven, force re-emit) — owner
    /// reported the cup didn't auto-recover after pause OFF because
    /// `reevaluateWatched()` short-circuited when the watched-set hadn't
    /// changed.
    public func reevaluateAll() {
        for trigger in triggers where trigger.isEnabled {
            trigger.reemitCurrentVote()
        }
    }

    /// **S22 / P-issue-6**: disable every currently-enabled trigger.
    /// Called from the `.latteUserExplicitDeactivate` observer to
    /// implement the "Turn off = big red button" semantic. Each
    /// trigger's `isEnabled` setter persists to UserDefaults so the
    /// Settings UI reflects the state, and `stop(_:)` halts emissions
    /// + sends an OFF vote (clearing AwakeManager's shadow set so the
    /// snooze deadline doesn't replay this trigger). To resume, the
    /// user re-enables the trigger in Settings.
    public func disableAll() {
        for trigger in triggers where trigger.isEnabled {
            trigger.isEnabled = false
            stop(trigger.id)
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
        // Append, THEN signal. The post happens inside the task *after* the
        // append `await` returns, so any subscriber that re-fetches the
        // snapshot in response is guaranteed to see the committed row. (The
        // post used to run synchronously before this task even started,
        // relying on the consumer's debounce to mask the gap — a real
        // ordering guarantee replaces that accidental one.) No userInfo —
        // the canonical consumer just refetches the snapshot, so emitting
        // triggerId/kind to every in-process observer would be needless
        // payload.
        Task { [weak self] in
            await activityStore.append(entry)
            NotificationCenter.default.post(name: .activityLogDidAppend, object: self)
        }
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
