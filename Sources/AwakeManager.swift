import Foundation
import Combine
import os.log

/// Coordinates the power assertion lifecycle and the optional auto-deactivation timer.
///
/// `AwakeManager.shared` is used by AppIntents (Shortcuts) to access the same
/// instance the SwiftUI views observe. The class is `@MainActor` to keep all
/// state mutations on the main thread.
@MainActor
final class AwakeManager: ObservableObject {

    static let shared = AwakeManager()

    private static let logger = Logger(subsystem: "com.example.caffeinated", category: "AwakeManager")

    @Published private(set) var isAwake = false
    @Published private(set) var endsAt: Date?
    @Published private(set) var activeDuration: AwakeDuration?

    @Published var allowDisplaySleep: Bool {
        didSet {
            UserDefaults.standard.set(allowDisplaySleep, forKey: Self.allowDisplaySleepKey)
            if isAwake { reapplyMode() }
        }
    }

    private let assertion = PowerAssertion()
    private var timer: Timer?

    private static let allowDisplaySleepKey = "allowDisplaySleep"

    init() {
        self.allowDisplaySleep = UserDefaults.standard.bool(forKey: Self.allowDisplaySleepKey)
    }

    func toggle() {
        isAwake ? deactivate() : activate(for: .indefinite)
    }

    func activate(for duration: AwakeDuration) {
        guard assertion.activate(mode: currentMode()) else {
            Self.logger.error("Failed to acquire power assertion")
            return
        }
        isAwake = true
        activeDuration = duration

        if let seconds = duration.seconds {
            endsAt = Date().addingTimeInterval(seconds)
            scheduleTimer(seconds)
        } else {
            endsAt = nil
            cancelTimer()
        }
    }

    func deactivate() {
        cancelTimer()
        assertion.deactivate()
        isAwake = false
        endsAt = nil
        activeDuration = nil
    }

    private func currentMode() -> PowerAssertion.Mode {
        allowDisplaySleep ? .systemOnly : .displayAndSystem
    }

    private func reapplyMode() {
        assertion.activate(mode: currentMode())
    }

    private func scheduleTimer(_ seconds: TimeInterval) {
        cancelTimer()
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.deactivate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }
}
