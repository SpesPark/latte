import Foundation
import Combine

@MainActor
public final class TriggerCoordinator: ObservableObject {

    @Published public private(set) var triggers: [any Trigger] = []
    @Published public private(set) var activeVotes: [String: TriggerVote] = [:]

    private let awakeManager: AwakeManager
    private let settings: SettingsStore
    private let logger = LatteLog.triggers
    private var consumerTasks: [String: Task<Void, Never>] = [:]

    public init(awakeManager: AwakeManager, settings: SettingsStore) {
        self.awakeManager = awakeManager
        self.settings = settings
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
    }
}
