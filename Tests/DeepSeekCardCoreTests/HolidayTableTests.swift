import XCTest
@testable import DeepSeekCardCore

final class HolidayTableTests: XCTestCase {
    private let utc = TestSupport.utc

    // MARK: - The shipped file

    func testShippedFileParses() {
        let url = HolidaySource.bundledURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "missing \(url.path)")
        let t = HolidayTable.load(year: 2026, userURL: missingURL())
        XCTAssertEqual(t.names(forYear: 2026).count, 33)
        XCTAssertEqual(t.names["2026-10-01"], "National Day")
        XCTAssertEqual(t.names["2026-05-03"], "Labor Day")
        XCTAssertEqual(t.names["2026-09-27"], "Mid-Autumn Festival")
        XCTAssertNil(t.names["2026-10-08"])   // first normal day after the holiday
        XCTAssertNil(t.names["2026-01-04"])   // makeup workday, deliberately absent
        XCTAssertNil(t.note)
    }

    func testShippedFileHasProvisional2027() {
        let t = HolidayTable.load(year: 2027, userURL: missingURL())
        XCTAssertEqual(t.names(forYear: 2027).count, 18)
        XCTAssertEqual(t.names["2027-01-01"], "New Year's Day")
        XCTAssertEqual(t.names["2027-02-06"], "Spring Festival")
        XCTAssertEqual(t.names["2027-10-06"], "National Day")
        XCTAssertNil(t.names["2027-10-07"])   // gap in the provisional window
        XCTAssertNil(t.names["2027-05-02"])   // gap in the provisional window
        XCTAssertNil(t.note)
    }

    // MARK: - Parsing

    func testParsesFlatEntries() {
        let data = #"[{"date":"2027-01-01","name":"New Year's Day"},{"date":"2027-02-06","name":"Spring Festival"}]"#
        XCTAssertEqual(HolidayTable.parse(Data(data.utf8)),
                       ["2027-01-01": "New Year's Day", "2027-02-06": "Spring Festival"])
    }

    func testRejectsMalformedEntries() {
        XCTAssertNil(HolidayTable.parse(Data("{ not json".utf8)))
        XCTAssertNil(HolidayTable.parse(Data(#"[{"name":"No date"}]"#.utf8)))
        XCTAssertNil(HolidayTable.parse(Data(#"{"2026":[]}"#.utf8)))   // not an array
    }

    // MARK: - Bundled + user merge

    func testUserFileAddsAndOverrides() {
        let bundled = tempFile(#"[{"date":"2026-10-01","name":"National Day"}]"#)
        let user = tempFile(#"[{"date":"2026-10-01","name":"My Name"},{"date":"2026-12-25","name":"Extra"}]"#)
        let t = HolidayTable.load(year: 2026, bundledURL: bundled, userURL: user)
        XCTAssertEqual(t.names["2026-10-01"], "My Name")     // the user's entry wins
        XCTAssertEqual(t.names["2026-12-25"], "Extra")       // and new dates are added
        XCTAssertEqual(t.note?.contains("2 dates from"), true, "note was \(t.note ?? "nil")")
    }

    func testMissingUserFileIsFine() {
        let bundled = tempFile(#"[{"date":"2026-10-01","name":"National Day"}]"#)
        let t = HolidayTable.load(year: 2026, bundledURL: bundled, userURL: missingURL())
        XCTAssertEqual(t.names["2026-10-01"], "National Day")
        XCTAssertNil(t.note)
    }

    func testInvalidUserFileIsIgnoredWithNote() {
        let bundled = tempFile(#"[{"date":"2026-10-01","name":"National Day"}]"#)
        let user = tempFile("{ not json")
        let t = HolidayTable.load(year: 2026, bundledURL: bundled, userURL: user)
        XCTAssertEqual(t.names["2026-10-01"], "National Day")
        XCTAssertEqual(t.note?.contains("Ignoring"), true, "note was \(t.note ?? "nil")")
    }

    func testInvalidBundledFileNotesItButKeepsUserData() {
        let bundled = tempFile("{ not json")
        let user = tempFile(#"[{"date":"2026-10-01","name":"My Name"}]"#)
        let t = HolidayTable.load(year: 2026, bundledURL: bundled, userURL: user)
        XCTAssertEqual(t.names["2026-10-01"], "My Name")
        XCTAssertEqual(t.note?.contains("could not be read"), true, "note was \(t.note ?? "nil")")
    }

    func testNoDataForYearNotesIt() {
        let bundled = tempFile(#"[{"date":"2026-10-01","name":"National Day"}]"#)
        let t = HolidayTable.load(year: 2027, bundledURL: bundled, userURL: missingURL())
        XCTAssertTrue(t.names(forYear: 2027).isEmpty)
        XCTAssertEqual(t.note?.contains("No holiday data for 2027"), true, "note was \(t.note ?? "nil")")
    }

    // MARK: - User file creation

    func testEnsureUserFileCreatesEmptyArrayAndNeverClobbers() throws {
        let url = TestSupport.tempDir().appendingPathComponent("holidays.json")
        HolidayTable.ensureUserFile(at: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(HolidayTable.parse(try Data(contentsOf: url)), [:])

        try #"[{"date":"2026-12-25","name":"Extra"}]"#.write(to: url, atomically: true, encoding: .utf8)
        HolidayTable.ensureUserFile(at: url)
        XCTAssertEqual(HolidayTable.parse(try Data(contentsOf: url)), ["2026-12-25": "Extra"])
    }

    // MARK: - Change detection

    func testStampChangesWithFileContent() throws {
        let url = TestSupport.tempDir().appendingPathComponent("holidays.json")
        let absent = missingURL()
        try "[]".write(to: url, atomically: true, encoding: .utf8)
        let first = HolidaySource.stamp(bundledURL: url, userURL: absent)
        try #"[{"date":"2026-12-25","name":"Extra"}]"#.write(to: url, atomically: true, encoding: .utf8)
        XCTAssertNotEqual(first, HolidaySource.stamp(bundledURL: url, userURL: absent))
    }

    // MARK: - Lookup

    func testNameLookupUsesCalendarZone() {
        let t = HolidayTable(names: ["2026-10-01": "National Day"])
        XCTAssertEqual(t.name(on: TestSupport.date("2026-10-01 00:30:00"), calendar: calendar(in: utc)), "National Day")
        let minus3 = calendar(in: TimeZone(identifier: "America/Sao_Paulo")!)   // UTC-3
        XCTAssertNil(t.name(on: TestSupport.date("2026-10-01 00:30:00"), calendar: minus3))
    }

    func testNamesForYearFiltersByPrefix() {
        let t = HolidayTable(names: ["2026-10-01": "A", "2027-01-01": "B"])
        XCTAssertEqual(t.names(forYear: 2026), ["2026-10-01": "A"])
        XCTAssertEqual(t.names(forYear: 2027), ["2027-01-01": "B"])
        XCTAssertTrue(t.names(forYear: 2028).isEmpty)
    }

    // MARK: - Helpers

    private func calendar(in zone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = zone; return c
    }

    private func tempFile(_ contents: String) -> URL {
        let url = TestSupport.tempDir().appendingPathComponent("holidays.json")
        try! contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func missingURL() -> URL {
        TestSupport.tempDir().appendingPathComponent("absent.json")
    }
}
