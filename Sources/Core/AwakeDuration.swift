import Foundation

public enum AwakeDuration: Equatable, Hashable, Sendable {
    case minutes(Int)
    case hours(Int)
    case indefinite

    public var seconds: TimeInterval? {
        switch self {
        case .minutes(let m): return TimeInterval(m * 60)
        case .hours(let h): return TimeInterval(h * 3600)
        case .indefinite: return nil
        }
    }

    public var label: String {
        switch self {
        case .minutes(let m):
            return String(localized: "\(m) minutes")
        case .hours(let h):
            return String(localized: "\(h) hours")
        case .indefinite:
            return String(localized: "Indefinitely")
        }
    }

    public var isFinite: Bool { seconds != nil }

    public static let presets: [AwakeDuration] = [
        .minutes(5),
        .minutes(15),
        .minutes(30),
        .hours(1),
        .hours(2),
        .hours(5),
        .indefinite
    ]
}
