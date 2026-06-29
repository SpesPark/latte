#if LATTE_ICLOUD_SYNC
import CloudKit
import Foundation

/// Production `CloudSyncEngine` backed by the user's **private** CloudKit
/// database (docs/design/10 §3, §5). Compiled only when the `LATTE_ICLOUD_SYNC`
/// kill-switch is defined; the default build never links this in, so iCloud
/// sync ships dark with zero behaviour change (§8, §11 Phase 1).
///
/// **This is the only file permitted to reference `CKContainer` / `CKDatabase`**
/// (§10 lint rule, enforced by `scripts/check_doc_drift.sh`). The
/// conflict-bearing logic — Settings last-writer-wins (Domain A) and the
/// activity-log append-only union merge (Domain B) — lands in Phase 2/3 as
/// pure, CloudKit-free functions this engine drives, so it stays unit-testable
/// without a live account.
@MainActor
public final class CloudKitSyncEngine: CloudSyncEngine {

    /// CloudKit container id (§9, RFC Q4). Tracks the bundle id; revisit if
    /// V2-20 changes the bundle prefix. The literal lives here and in the
    /// entitlement file only.
    public static let defaultContainerIdentifier = "iCloud.com.araforge.latte"

    private let container: CKContainer
    public private(set) var isRunning = false

    public init(containerIdentifier: String = CloudKitSyncEngine.defaultContainerIdentifier) {
        self.container = CKContainer(identifier: containerIdentifier)
    }

    /// Bring sync up only when an iCloud account is available (§8 graceful
    /// degradation). A signed-out account, disabled iCloud Drive, or an
    /// unavailable container leaves `isRunning == false` and never blocks the
    /// app. Phase 1 establishes the availability gate; the Domain A/B sync
    /// drivers attach in Phase 2/3 (S8.5-gated).
    public func start() async {
        let status = try? await container.accountStatus()
        isRunning = (status == .available)
    }

    public func stop() async {
        isRunning = false
    }
}
#endif
