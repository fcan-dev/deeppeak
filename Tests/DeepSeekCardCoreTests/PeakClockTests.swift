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

    func testPhaseAndNextSwitchAtFixedTime() {
        let current = TestSupport.date("2026-10-02 12:00:00")   // National Day, Friday
        let clock = PeakClock(now: current, holidayDirectory: TestSupport.tempDir(),
                              nowProvider: { current }, tickInterval: .seconds(3600))
        clock.tick()
        XCTAssertEqual(clock.now, current)
        XCTAssertEqual(clock.phase, .offPeak(.chineseHoliday("National Day")))
        XCTAssertEqual(clock.nextSwitch, TestSupport.date("2026-10-08 01:00:00"))
        XCTAssertEqual(clock.timeRemaining, TestSupport.date("2026-10-08 01:00:00").timeIntervalSince(current))
    }

    func testTickAdvancesPhaseAcrossBoundary() {
        let current = MutableDate(TestSupport.date("2026-10-08 00:59:58"))
        let clock = PeakClock(now: current.value, holidayDirectory: TestSupport.tempDir(),
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

    func testReloadsHolidayFileOnDayChange() throws {
        let dir = TestSupport.tempDir()
        let url = HolidayTable.fileURL(forYear: 2026, directory: dir)
        try #"[{"date":"2026-01-01","name":"New Year's Day"}]"#
            .write(to: url, atomically: true, encoding: .utf8)
        let current = MutableDate(TestSupport.date("2026-10-08 23:59:00"))
        let clock = PeakClock(now: current.value, holidayDirectory: dir,
                              nowProvider: { current.value }, tickInterval: .seconds(1))
        XCTAssertEqual(clock.holidayTable.names.count, 1)
        XCTAssertNil(clock.holidayNote)

        try #"[{"date":"2026-01-01","name":"New Year's Day"},{"date":"2026-10-09","name":"Bridge Day"}]"#
            .write(to: url, atomically: true, encoding: .utf8)
        current.value = TestSupport.date("2026-10-09 00:00:30")   // next UTC day
        clock.tick()
        XCTAssertEqual(clock.holidayTable.names.count, 2)         // reloaded
        XCTAssertEqual(clock.phase, .offPeak(.chineseHoliday("Bridge Day")))
    }

    func testStartAndStopTicking() async throws {
        let clock = PeakClock(now: TestSupport.date("2026-10-08 12:00:00"),
                              holidayDirectory: TestSupport.tempDir(),
                              tickInterval: .milliseconds(20))
        clock.start()
        clock.start()                                          // idempotent
        try await Task.sleep(for: .milliseconds(60))
        clock.stop()
        let stopped = clock.now
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(clock.now, stopped)
    }
}
