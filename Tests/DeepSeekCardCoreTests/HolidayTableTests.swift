import XCTest
@testable import DeepSeekCardCore

final class HolidayTableTests: XCTestCase {
    private let utc = TestSupport.utc

    func testEmbedded2026Has33Days() {
        let t = HolidayTable.embedded(year: 2026)
        XCTAssertEqual(t?.names.count, 33)
        XCTAssertEqual(t?.names["2026-10-01"], "National Day")
        XCTAssertEqual(t?.names["2026-05-03"], "Labor Day")
        XCTAssertEqual(t?.names["2026-09-27"], "Mid-Autumn Festival")
        XCTAssertNil(t?.names["2026-10-08"])   // first normal day after the holiday
        XCTAssertNil(t?.names["2026-01-04"])   // makeup workday, deliberately absent
        XCTAssertNil(HolidayTable.embedded(year: 2027))
    }

    func testMissingFileIsCreatedAndNoted() throws {
        let dir = TestSupport.tempDir()
        let t = HolidayTable.load(year: 2026, directory: dir)
        XCTAssertEqual(t.names.count, 33)
        XCTAssertEqual(t.note?.contains("Created default holiday data"), true, "note was \(t.note ?? "nil")")
        let url = HolidayTable.fileURL(forYear: 2026, directory: dir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let again = HolidayTable.load(year: 2026, directory: dir)
        XCTAssertNil(again.note)               // second load: file is valid, no note
        XCTAssertEqual(again.names.count, 33)
    }

    func testInvalidJSONFallsBackWithNote() throws {
        let dir = TestSupport.tempDir()
        let url = HolidayTable.fileURL(forYear: 2026, directory: dir)
        try "{ not json".write(to: url, atomically: true, encoding: .utf8)
        let t = HolidayTable.load(year: 2026, directory: dir)
        XCTAssertEqual(t.names.count, 33)
        XCTAssertEqual(t.note?.contains("invalid"), true, "note was \(t.note ?? "nil")")
    }

    func testValidFileIsUsedWithoutNote() throws {
        let dir = TestSupport.tempDir()
        let url = HolidayTable.fileURL(forYear: 2027, directory: dir)
        let json = #"[{"date":"2027-01-01","name":"New Year's Day"}]"#
        try json.write(to: url, atomically: true, encoding: .utf8)
        let t = HolidayTable.load(year: 2027, directory: dir)
        XCTAssertEqual(t.names, ["2027-01-01": "New Year's Day"])
        XCTAssertNil(t.note)
    }

    func testYearWithoutDataNotesIt() {
        let t = HolidayTable.load(year: 2027, directory: TestSupport.tempDir())
        XCTAssertTrue(t.names.isEmpty)
        XCTAssertEqual(t.note?.contains("No holiday data for 2027"), true, "note was \(t.note ?? "nil")")
    }

    func testEmptyFileNotesNoData() throws {
        let dir = TestSupport.tempDir()
        let url = HolidayTable.fileURL(forYear: 2028, directory: dir)
        try "[]".write(to: url, atomically: true, encoding: .utf8)
        let t = HolidayTable.load(year: 2028, directory: dir)
        XCTAssertTrue(t.names.isEmpty)
        XCTAssertEqual(t.note?.contains("No holiday data for 2028"), true, "note was \(t.note ?? "nil")")
    }

    func testNameLookupUsesCalendarZone() {
        let t = HolidayTable(year: 2026, names: ["2026-10-01": "National Day"])
        XCTAssertEqual(t.name(on: TestSupport.date("2026-10-01 00:30:00"), calendar: utcCalendarFor(utc)), "National Day")
        let minus3 = utcCalendarFor(TimeZone(identifier: "America/Sao_Paulo")!)  // UTC-3
        XCTAssertNil(t.name(on: TestSupport.date("2026-10-01 00:30:00"), calendar: minus3))  // still 2026-09-30 there
    }

    private func utcCalendarFor(_ zone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = zone; return c
    }
}
