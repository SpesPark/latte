import Foundation
import os

/// Persistent flag indicating the user has completed (or skipped) the
/// first-run onboarding wizard. Backed by `SettingsKey.firstRunCompleted`
/// + `SettingsKey.firstRunCompletedAt`.
///
/// The wizard helps the user pick their first trigger so the app has
/// real value on day 1 (KYA reviews surface "I didn't know what to do"
/// pain). If we let the popover open with zero triggers configured,
/// retention dies before review #1.
@MainActor
public final class OnboardingState: ObservableObject {

    /// Mirrored copy of the persisted flag. Settings tab can read this
    /// to expose a "Show onboarding again" affordance later if owner
    /// wants. Direct mutation here writes through to settings.
    @Published public private(set) var hasCompletedOnboarding: Bool

    private let settings: SettingsStore
    private let logger = Logger(subsystem: "com.araforge.latte", category: "onboarding")
    private let dateProvider: @Sendable () -> Date

    public init(
        settings: SettingsStore,
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.settings = settings
        self.dateProvider = dateProvider
        self.hasCompletedOnboarding = settings.bool(.firstRunCompleted, default: false)
    }

    /// Mark the onboarding as done. Idempotent — calling twice is a no-op.
    public func markCompleted() {
        guard !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
        settings.setBool(true, for: .firstRunCompleted)
        let now = dateProvider()
        settings.setDouble(now.timeIntervalSince1970, for: .firstRunCompletedAt)
        logger.info("onboarding marked complete at \(now.timeIntervalSince1970)")
    }

    /// Reset for testing or for an owner-facing "Show again" path.
    public func reset() {
        hasCompletedOnboarding = false
        settings.setBool(false, for: .firstRunCompleted)
        settings.remove(.firstRunCompletedAt)
    }
}
