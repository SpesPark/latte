import Foundation

/// Configuration for the marketing demo cup window. All values are bounded so
/// the URL surface is safe even if a third party crafts a hostile URL.
public struct DemoCupConfig: Equatable, Sendable {
    public let fillRatio: Double
    public let accent: CoffeeAccent
    public let isAwake: Bool

    public init(fillRatio: Double = 1.0, accent: CoffeeAccent = .default, isAwake: Bool = true) {
        self.fillRatio = max(0.0, min(1.0, fillRatio))
        self.accent = accent
        self.isAwake = isAwake
    }
}

/// Parses `latte://demo/...` URLs into demo configurations. Used to drive the
/// marketing capture pipeline (see `~/dev/smoke-harness/.../scenarios/12-...`).
///
/// Supported forms:
///   - `latte://demo/cup`                                  → defaults
///   - `latte://demo/cup?fill=0.55`                        → mid-fill
///   - `latte://demo/cup?fill=0.6&accent=caramel`          → with accent
///   - `latte://demo/cup?fill=0.6&accent=mocha&awake=true` → all params
public enum DemoURLHandler {

    public static let scheme = "latte"
    public static let demoHost = "demo"
    public static let cupPath = "cup"

    public enum DemoTarget: Equatable, Sendable {
        case cup(DemoCupConfig)
    }

    public static func parse(_ url: URL) -> DemoTarget? {
        guard url.scheme == scheme, url.host == demoHost else {
            return nil
        }
        let trimmed = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard trimmed == cupPath else { return nil }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let lookup = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let v = item.value else { return nil }
            return (item.name, v)
        })

        let fill = lookup["fill"].flatMap(Double.init) ?? 1.0
        let accent = lookup["accent"].flatMap { CoffeeAccent(rawValue: $0) } ?? .default
        let awake = lookup["awake"].flatMap { ["true", "1", "yes"].contains($0.lowercased()) } ?? true

        return .cup(DemoCupConfig(fillRatio: fill, accent: accent, isAwake: awake))
    }
}
