import Foundation

/// Common interface for an automation trigger that can request the awake state.
///
/// Each concrete trigger (Calendar, App, Wi-Fi, Focus) owns its own listener
/// and calls back into `AwakeManager` when its conditions are met. Triggers
/// must be safe to start/stop repeatedly.
@MainActor
protocol Trigger: AnyObject {
    var id: String { get }
    var name: String { get }
    var isEnabled: Bool { get set }

    func start()
    func stop()
}
