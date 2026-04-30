import XCTest
@testable import Latte

/// Owner-facing export of the activity log (C-3 deferred C). The exporter is
/// pure — it never touches the file system. ActivityTab wires it to NSSavePanel.
final class ActivityLogExporterTests: XCTestCase {

    private func entry(
        _ triggerId: String,
        _ kind: ActivityLogEntry.Kind = .on,
        _ reason: ActivityLogEntry.ReasonCode = .voteOn,
        timestamp: Date = Date(timeIntervalSince1970: 1_800_000_000),
        id: UUID = UUID()
    ) -> ActivityLogEntry {
        ActivityLogEntry(id: id, timestamp: timestamp, triggerId: triggerId, kind: kind, reasonCode: reason)
    }

    // MARK: - CSV

    func testCSVHeaderIsExactlyTheSchemaFieldsInSchemaOrder() {
        let csv = ActivityLogExporter.csv(from: [])
        let header = csv.split(separator: "\n").first.map(String.init) ?? ""
        XCTAssertEqual(header, "id,timestamp,triggerId,kind,reasonCode",
                       "CSV header must match the schema fields in §2 — privacy contract")
    }

    func testCSVEmitsOneRowPerEntryAfterHeader() {
        let entries = [
            entry("wifi", .on, .voteOn),
            entry("wifi", .off, .voteOff),
            entry("calendar", .on, .voteOn)
        ]
        let csv = ActivityLogExporter.csv(from: entries)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 4, "1 header + 3 data rows")
    }

    func testCSVRowFieldsAreEnumRawValuesNotDescriptions() {
        // CSV should be parseable round-trip — Kind.on must serialise as "on",
        // not the Swift `.on` description.
        let e = entry("wifi", .off, .userToggleOff)
        let csv = ActivityLogExporter.csv(from: [e])
        let dataRow = csv.split(separator: "\n").last.map(String.init) ?? ""
        XCTAssertTrue(dataRow.contains(",off,"), "kind raw value 'off' missing")
        XCTAssertTrue(dataRow.contains(",userToggleOff"), "reasonCode raw value missing")
        XCTAssertTrue(dataRow.contains(",wifi,"), "triggerId missing")
    }

    func testCSVTimestampIsISO8601() {
        // Date is precise in JSON (secondsSince1970 Double) but humans want
        // ISO8601 in spreadsheet exports.
        let date = Date(timeIntervalSince1970: 1_800_000_000)   // 2027-01-15T08:00:00Z
        let csv = ActivityLogExporter.csv(from: [entry("wifi", timestamp: date)])
        let dataRow = csv.split(separator: "\n").last.map(String.init) ?? ""
        XCTAssertTrue(dataRow.contains("2027-01-15T08:00:00Z"),
                      "expected ISO8601 timestamp, got: \(dataRow)")
    }

    // MARK: - JSON

    func testJSONIsArrayOfActivityLogEntryRoundTrippable() throws {
        let entries = [
            entry("wifi", .on, .voteOn),
            entry("calendar", .off, .voteOff)
        ]
        let data = try ActivityLogExporter.jsonData(from: entries)
        // Match the encoder's date strategy — both export and on-disk use
        // secondsSince1970 (see ActivityLogStore for rationale).
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode([ActivityLogEntry].self, from: data)
        XCTAssertEqual(decoded, entries,
                       "exported JSON must round-trip back into the schema — same coder as the on-disk log")
    }

    func testJSONIsPrettyPrintedForOwnerReadability() throws {
        // Owner opens the export in a text editor — collapsed-line JSON is unhelpful.
        let data = try ActivityLogExporter.jsonData(from: [entry("wifi")])
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\n"),
                      "pretty-printed JSON has newlines; got: \(text.prefix(80))…")
    }

    // MARK: - Filename suggestion

    func testSuggestedFilenameUsesISODate() {
        // The OS save panel needs a default — owner shouldn't have to type one.
        // Format: latte-activity-YYYY-MM-DD.<ext>.
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let csv = ActivityLogExporter.suggestedFilename(for: .csv, on: date)
        let json = ActivityLogExporter.suggestedFilename(for: .json, on: date)
        XCTAssertEqual(csv, "latte-activity-2027-01-15.csv")
        XCTAssertEqual(json, "latte-activity-2027-01-15.json")
    }
}
