import XCTest
@testable import Latte

/// `AwakeManager` logs state transitions with `String(describing:)` at
/// `privacy: .public`. The default reflected rendering of
/// `.awakeTriggered(votes:)` / `.coolingDown(lastVotes:)` would include each
/// `TriggerVote.reason` — which carries user content: the Wi-Fi SSID, the
/// calendar event title, the running-app names. That would write PII into the
/// system log, readable by any process via Console / `log stream`, undermining
/// the app's "No Data Collected" privacy posture.
///
/// `AwakeState: CustomStringConvertible` renders a privacy-safe form that
/// exposes only the static trigger IDs (non-PII, e.g. "wifi") for diagnostics.
final class AwakeStateDescriptionTests: XCTestCase {

    func testAwakeTriggeredDescriptionOmitsReasonPII() {
        let vote = TriggerVote(wantsAwake: true, reason: "Wi-Fi: on TopSecretSSID")
        let state = AwakeState.awakeTriggered(votes: ["wifi": vote])
        let desc = String(describing: state)
        XCTAssertFalse(desc.contains("TopSecretSSID"), "AwakeState description must not leak TriggerVote.reason (PII)")
        XCTAssertFalse(desc.contains("Wi-Fi: on"), "reason text must not appear in the log rendering")
        XCTAssertTrue(desc.contains("wifi"), "static trigger id should remain for diagnostics")
    }

    func testCoolingDownDescriptionOmitsReasonPII() {
        let vote = TriggerVote(wantsAwake: true, reason: "Calendar: Quarterly Board Meeting")
        let state = AwakeState.coolingDown(
            until: Date(timeIntervalSince1970: 1_000),
            lastVotes: ["calendar": vote]
        )
        let desc = String(describing: state)
        XCTAssertFalse(desc.contains("Quarterly Board Meeting"), "calendar event title must not leak")
        XCTAssertTrue(desc.contains("calendar"))
    }

    func testTriggerListIsSortedAndDeterministic() {
        let v = TriggerVote(wantsAwake: true, reason: "x")
        let state = AwakeState.awakeTriggered(votes: ["wifi": v, "calendar": v, "app": v])
        XCTAssertEqual(String(describing: state), "awakeTriggered(triggers: [app, calendar, wifi])")
    }

    func testSimpleStatesRenderStably() {
        XCTAssertEqual(String(describing: AwakeState.asleep), "asleep")
        XCTAssertEqual(String(describing: AwakeState.awakeUserIndefinite), "awakeUserIndefinite")
    }
}
