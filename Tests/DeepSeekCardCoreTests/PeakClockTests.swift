import XCTest
@testable import DeepSeekCardCore

@MainActor
final class PeakClockTests: XCTestCase {
    /// Box for a Date that a test advances between ticks. Unchecked because the
    /// tests touch it only from the main actor.
    private final class MutableDate: @unchecked Sendable {
        var value: Date
        init(_ value: Date) { self.value = value }
    }

    // MARK: - Derived state

    func testPhaseAndNextSwitchAtFixedTime() {
        // Uses the shipped holidays.json: 2026-10-02 is National Day.
        let current = TestSupport.date("2026-10-02 12:00:00")
        let clock = PeakClock(now: current, userURL: TestSupport.absentURL(),
                              nowProvider: { current }, tickInterval: .seconds(3600))
        clock.tick()
        XCTAssertEqual(clock.now, current)
        XCTAssertEqual(clock.phase, .offPeak(.chineseHoliday("National Day")))
        XCTAssertEqual(clock.nextSwitch, TestSupport.date("2026-10-08 01:00:00"))
        XCTAssertEqual(clock.timeRemaining, TestSupport.date("2026-10-08 01:00:00").timeIntervalSince(current))
    }

    func testTickAdvancesPhaseAcrossBoundary() {
        let current = MutableDate(TestSupport.date("2026-10-08 00:59:58"))
        let clock = PeakClock(now: current.value, userURL: TestSupport.absentURL(),
                              nowProvider: { current.value }, tickInterval: .seconds(1))
        clock.tick()
        XCTAssertEqual(clock.phase, .offPeak(.weekday))
        current.value = TestSupport.date("2026-10-08 00:59:59")
        clock.tick()
        XCTAssertEqual(clock.phase, .offPeak(.weekday))
        current.value = TestSupport.date("2026-10-08 01:00:00")
        clock.tick()
        XCTAssertEqual(clock.phase, .peak)                    // flips with no restart
        XCTAssertEqual(clock.nextSwitch, TestSupport.date("2026-10-08 04:00:00"))
    }

    // MARK: - Reloading

    func testReloadsWhenUserFileChanges() throws {
        let bundled = tempFile(#"[{"date":"2026-10-01","name":"National Day"}]"#)
        let userURL = TestSupport.tempDir().appendingPathComponent("holidays.json")
        try "[]".write(to: userURL, atomically: true, encoding: .utf8)
        let current = MutableDate(TestSupport.date("2026-10-08 12:00:00"))
        let clock = PeakClock(now: current.value, bundledURL: bundled, userURL: userURL,
                              nowProvider: { current.value }, tickInterval: .seconds(1))
        XCTAssertEqual(clock.holidayTable.names.count, 1)

        // Same UTC day: the user clicked *Edit Holidays* and added a bridge day.
        try #"[{"date":"2026-10-08","name":"Bridge Day"}]"#.write(to: userURL, atomically: true, encoding: .utf8)
        clock.tick()
        XCTAssertEqual(clock.holidayTable.names.count, 2)
        XCTAssertEqual(clock.phase, .offPeak(.chineseHoliday("Bridge Day")))
    }

    func testReloadsAcrossYearBoundary() throws {
        let bundled = tempFile(#"[{"date":"2026-10-01","name":"National Day"}]"#)
        let current = MutableDate(TestSupport.date("2026-12-31 23:59:00"))
        let clock = PeakClock(now: current.value, bundledURL: bundled, userURL: TestSupport.absentURL(),
                              nowProvider: { current.value }, tickInterval: .seconds(1))
        XCTAssertNil(clock.holidayNote)                       // 2026 has data
        current.value = TestSupport.date("2027-01-01 00:00:30")
        clock.tick()
        XCTAssertEqual(clock.holidayNote?.contains("No holiday data for 2027"), true,
                       "note was \(clock.holidayNote ?? "nil")")
    }

    func testStartAndStopTicking() async throws {
        let clock = PeakClock(now: TestSupport.date("2026-10-08 12:00:00"),
                              userURL: TestSupport.absentURL(),
                              tickInterval: .milliseconds(20))
        clock.start()
        clock.start()                                          // idempotent
        try await Task.sleep(for: .milliseconds(60))
        clock.stop()
        let stopped = clock.now
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(clock.now, stopped)
    }

    // MARK: - Helpers

    private func tempFile(_ contents: String) -> URL {
        let url = TestSupport.tempDir().appendingPathComponent("holidays.json")
        try! contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
