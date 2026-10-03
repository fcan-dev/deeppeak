import XCTest
@testable import DeepPeakCore

final class HolidaySourceTests: XCTestCase {
    func testUserFileLivesInTheDeepPeakConfigDirectory() {
        XCTAssertEqual(HolidaySource.userFileURL.lastPathComponent, "holidays.json")
        XCTAssertEqual(HolidaySource.userFileURL.deletingLastPathComponent().lastPathComponent, "deeppeak")
        XCTAssertEqual(HolidaySource.legacyUserFileURL.deletingLastPathComponent().lastPathComponent, "deepseek-card")
    }

    func testMigrateMovesALegacyFile() throws {
        let from = TestSupport.tempDir().appendingPathComponent("holidays.json")
        let to = TestSupport.tempDir().appendingPathComponent("holidays.json")
        try #"[{"date":"2026-12-25","name":"Extra"}]"#.write(to: from, atomically: true, encoding: .utf8)

        XCTAssertTrue(HolidaySource.migrateLegacyUserFile(from: from, to: to))
        XCTAssertEqual(HolidayTable.parse(try Data(contentsOf: to)), ["2026-12-25": "Extra"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: from.path),
                       "moved, not copied — two files would drift")
    }

    func testMigrateNeverOverwritesAnExistingFile() throws {
        let from = TestSupport.tempDir().appendingPathComponent("holidays.json")
        let to = TestSupport.tempDir().appendingPathComponent("holidays.json")
        try #"[{"date":"2026-01-01","name":"Legacy"}]"#.write(to: from, atomically: true, encoding: .utf8)
        try #"[{"date":"2026-12-25","name":"Current"}]"#.write(to: to, atomically: true, encoding: .utf8)

        XCTAssertFalse(HolidaySource.migrateLegacyUserFile(from: from, to: to))
        XCTAssertEqual(HolidayTable.parse(try Data(contentsOf: to)), ["2026-12-25": "Current"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: from.path), "the legacy file is left alone")
    }

    func testMigrateIsANoOpWithoutALegacyFile() {
        let from = TestSupport.tempDir().appendingPathComponent("absent.json")
        let to = TestSupport.tempDir().appendingPathComponent("holidays.json")

        XCTAssertFalse(HolidaySource.migrateLegacyUserFile(from: from, to: to))
        XCTAssertFalse(FileManager.default.fileExists(atPath: to.path))
    }
}
