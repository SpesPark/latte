import Foundation

/// Seam for iCloud (CloudKit private-database) sync.
///
/// Ships **dark** behind the `LATTE_ICLOUD_SYNC` compile-time flag
/// (docs/design/10 §8 kill-switch, §11 Phase 1). With the flag absent — the
/// default build — `AppEnvironment.cloudSync` is `nil`, none of the CloudKit
/// code is compiled, and app behaviour is unchanged.
///
/// The production adapter `CloudKitSyncEngine` is the **only** type permitted to
/// touch `CKContainer` / `CKDatabase` (§10 lint rule). All conflict-bearing
/// logic — Settings last-writer-wins resolution (Domain A) and the activity-log
/// append-only union merge (Domain B) — lands in later phases as pure,
/// CloudKit-free functions that an engine drives, so it stays unit-testable
/// without a live iCloud account.
@MainActor
public protocol CloudSyncEngine: AnyObject {
    /// `true` once `start()` has brought the engine up with an available iCloud
    /// account. `false` before `start()`, after `stop()`, or whenever the
    /// account is signed out / the container is unavailable.
    var isRunning: Bool { get }

    /// Bring the engine up. Graceful degradation (§8): when the iCloud account
    /// is unavailable this is a no-op that leaves `isRunning == false` — sync
    /// silently stays off and never blocks the app.
    func start() async

    /// Tear the engine down and release CloudKit resources. Idempotent.
    func stop() async
}
