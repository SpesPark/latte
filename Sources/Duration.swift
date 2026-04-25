import Foundation

enum AwakeDuration: Hashable, Identifiable {
    case minutes(Int)
    case hours(Int)
    case indefinite

    var id: String { label }

    /// Returns nil for indefinite.
    var seconds: TimeInterval? {
        switch self {
        case .minutes(let m): return TimeInterval(m * 60)
        case .hours(let h): return TimeInterval(h * 3600)
        case .indefinite: return nil
        }
    }

    var label: String {
        switch self {
        case .minutes(let m): return "\(m) minutes"
        case .hours(let h): return h == 1 ? "1 hour" : "\(h) hours"
        case .indefinite: return "Indefinitely"
        }
    }

    var symbol: String {
        switch self {
        case .minutes: return "timer"
        case .hours: return "clock"
        case .indefinite: return "infinity"
        }
    }

    static let presets: [AwakeDuration] = [
        .minutes(5),
        .minutes(15),
        .minutes(30),
        .hours(1),
        .hours(2),
        .hours(5),
        .indefinite
    ]
}
