import Foundation

/// One side of a per-record last-writer-wins comparison: a settings value
/// stamped with the moment it was last written (docs/design/04-data-model §2.2,
/// the `GeneralSetting.updatedAt` field).
public struct LWWRecord<Value: Equatable & Sendable>: Equatable, Sendable {
    public let value: Value
    public let updatedAt: Date

    public init(value: Value, updatedAt: Date) {
        self.value = value
        self.updatedAt = updatedAt
    }
}

/// Which side a last-writer-wins comparison selected, from the perspective of
/// the device performing the merge.
public enum LWWWinner: Equatable, Sendable {
    case local
    case remote
}

/// Last-writer-wins conflict resolution for **Domain A (Settings) only**
/// (docs/design/10 §6). Pure and CloudKit-free (§10): the production
/// `CloudKitSyncEngine` drives this, so the conflict-bearing logic stays
/// unit-testable without a live iCloud account. Pre-built dark in S42 ahead of
/// the S8.5-gated activation.
///
/// **The activity log (Domain B) must never reach this path.** §6: LWW on an
/// append-only event log silently destroys concurrent-day history — that domain
/// uses an append-only union merge instead. This type is deliberately named and
/// scoped to settings to make misuse obvious.
///
/// Rule: adopt the remote record only when it is *strictly* newer; on an exact
/// timestamp tie keep the local record. §3 justifies the conservative tie-break:
/// settings are low-frequency, single-user, and a clobbered toggle is
/// re-toggle-recoverable, so a same-instant two-device collision is both
/// vanishingly rare and harmless.
public enum SettingsLWWResolver {

    /// Returns the winning record: `remote` iff it is strictly newer than
    /// `local`, otherwise `local`.
    public static func resolve<Value>(
        local: LWWRecord<Value>,
        remote: LWWRecord<Value>
    ) -> LWWRecord<Value> {
        remote.updatedAt > local.updatedAt ? remote : local
    }

    /// Reports which side `resolve(local:remote:)` would select.
    public static func winner<Value>(
        local: LWWRecord<Value>,
        remote: LWWRecord<Value>
    ) -> LWWWinner {
        remote.updatedAt > local.updatedAt ? .remote : .local
    }
}
