import XCTest
@testable import DeepSeekCardCore

final class DayScheduleTests: XCTestCase {
    private let holidays = HolidayTable.load(year: 2026, userURL: TestSupport.absentURL())

    private func phase(_ s: String) -> Phase {
        DaySchedule.phase(at: TestSupport.date(s), holidays: holidays)
    }

    func testDefaultCalendarIsUTC() {
        XCTAssertEqual(DaySchedule.utcCalendar.timeZone, TimeZone(identifier: "UTC"))
    }

    func testNormalWeekdayBands() {                       // 2026-10-08 is a Thursday
        XCTAssertEqual(phase("2026-10-08 00:30:00"), .offPeak(.weekday))
        XCTAssertEqual(phase("2026-10-08 01:00:00"), .peak)
        XCTAssertEqual(phase("2026-10-08 03:59:59"), .peak)
        XCTAssertEqual(phase("2026-10-08 04:00:00"), .offPeak(.weekday))
        XCTAssertEqual(phase("2026-10-08 05:59:59"), .offPeak(.weekday))
        XCTAssertEqual(phase("2026-10-08 06:00:00"), .peak)
        XCTAssertEqual(phase("2026-10-08 09:59:59"), .peak)
        XCTAssertEqual(phase("2026-10-08 10:00:00"), .offPeak(.weekday))
        XCTAssertEqual(phase("2026-10-08 23:59:59"), .offPeak(.weekday))
    }

    func testWeekendIsOffPeakAllDay() {                   // 2026-10-10 is a Saturday
        XCTAssertEqual(phase("2026-10-10 00:00:00"), .offPeak(.weekend))
        XCTAssertEqual(phase("2026-10-10 02:00:00"), .offPeak(.weekend))
        XCTAssertEqual(phase("2026-10-10 07:00:00"), .offPeak(.weekend))
        XCTAssertEqual(phase("2026-10-11 23:59:59"), .offPeak(.weekend))   // Sunday
    }

    func testHolidayOnAWeekdayIsOffPeakAllDay() {         // 2026-10-05 is a Monday
        XCTAssertEqual(phase("2026-10-05 00:00:00"), .offPeak(.chineseHoliday("National Day")))
        XCTAssertEqual(phase("2026-10-05 02:00:00"), .offPeak(.chineseHoliday("National Day")))
        XCTAssertEqual(phase("2026-10-05 07:30:00"), .offPeak(.chineseHoliday("National Day")))
    }

    func testHolidayBeatsWeekend() {                      // 2026-10-03 is a Saturday in National Day
        XCTAssertEqual(phase("2026-10-03 12:00:00"), .offPeak(.chineseHoliday("National Day")))
    }

    func testSegmentsForNormalWeekday() {
        let segs = DaySchedule.segments(forUTCDay: TestSupport.date("2026-10-08 15:00:00"), holidays: holidays)
        XCTAssertEqual(segs.count, 5)
        XCTAssertEqual(segs.map(\.phase), [.offPeak(.weekday), .peak, .offPeak(.weekday), .peak, .offPeak(.weekday)])
        XCTAssertEqual(segs.first?.start, TestSupport.date("2026-10-08 00:00:00"))
        XCTAssertEqual(segs.last?.end, TestSupport.date("2026-10-09 00:00:00"))
        XCTAssertEqual(segs[1].start, TestSupport.date("2026-10-08 01:00:00"))
        XCTAssertEqual(segs[1].end, TestSupport.date("2026-10-08 04:00:00"))
        XCTAssertEqual(segs[3].start, TestSupport.date("2026-10-08 06:00:00"))
        XCTAssertEqual(segs[3].end, TestSupport.date("2026-10-08 10:00:00"))
    }

    func testSegmentsForWeekendAndHolidayAreOneFullDay() {
        for s in ["2026-10-10 12:00:00", "2026-10-05 12:00:00"] {
            let day = TestSupport.date(s)
            let segs = DaySchedule.segments(forUTCDay: day, holidays: holidays)
            XCTAssertEqual(segs.count, 1)
            XCTAssertEqual(segs[0].end.timeIntervalSince(segs[0].start), 24 * 3600)
        }
    }

    func testNextSwitchWithinTheDay() {
        func next(_ s: String) -> Date { DaySchedule.nextSwitch(after: TestSupport.date(s), holidays: holidays) }
        XCTAssertEqual(next("2026-10-08 00:30:00"), TestSupport.date("2026-10-08 01:00:00"))
        XCTAssertEqual(next("2026-10-08 03:00:00"), TestSupport.date("2026-10-08 04:00:00"))
        XCTAssertEqual(next("2026-10-08 05:00:00"), TestSupport.date("2026-10-08 06:00:00"))
        XCTAssertEqual(next("2026-10-08 09:00:00"), TestSupport.date("2026-10-08 10:00:00"))
        XCTAssertEqual(next("2026-10-08 23:00:00"), TestSupport.date("2026-10-09 01:00:00"))   // crosses midnight
        XCTAssertEqual(next("2026-10-09 02:00:00"), TestSupport.date("2026-10-09 04:00:00"))
        XCTAssertEqual(next("2026-10-09 05:00:00"), TestSupport.date("2026-10-09 06:00:00"))
    }

    func testNextSwitchSkipsReasonOnlyChanges() {
        // Friday 23:30 off-peak(weekday) → Sat/Sun off-peak(weekend): no label change until Monday.
        XCTAssertEqual(DaySchedule.nextSwitch(after: TestSupport.date("2026-10-09 23:30:00"), holidays: holidays),
                       TestSupport.date("2026-10-12 01:00:00"))
        // Wednesday 2026-09-30: National Day starts next day → the next peak is a week out.
        XCTAssertEqual(DaySchedule.nextSwitch(after: TestSupport.date("2026-09-30 12:00:00"), holidays: holidays),
                       TestSupport.date("2026-10-08 01:00:00"))
        // Saturday 2026-10-03 (holiday) → same next peak.
        XCTAssertEqual(DaySchedule.nextSwitch(after: TestSupport.date("2026-10-03 12:00:00"), holidays: holidays),
                       TestSupport.date("2026-10-08 01:00:00"))
    }
}
