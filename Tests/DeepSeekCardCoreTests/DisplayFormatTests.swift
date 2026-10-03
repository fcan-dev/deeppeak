import XCTest
@testable import DeepSeekCardCore

final class DisplayFormatTests: XCTestCase {
    private let plus3 = TimeZone(identifier: "Europe/Istanbul")!   // UTC+3, no DST
    private let posix = Locale(identifier: "en_US_POSIX")

    func testCountdownBuckets() {
        XCTAssertEqual(DisplayFormat.countdown(30), "<1m")
        XCTAssertEqual(DisplayFormat.countdown(59.9), "<1m")
        XCTAssertEqual(DisplayFormat.countdown(60), "1m")
        XCTAssertEqual(DisplayFormat.countdown(59 * 60), "59m")
        XCTAssertEqual(DisplayFormat.countdown(3600), "1h 0m")
        XCTAssertEqual(DisplayFormat.countdown(10 * 3600 + 52 * 60), "10h 52m")
        XCTAssertEqual(DisplayFormat.countdown(23 * 3600 + 59 * 60), "23h 59m")
        XCTAssertEqual(DisplayFormat.countdown(24 * 3600), "1d 0h")
        XCTAssertEqual(DisplayFormat.countdown(52 * 3600 + 1800), "2d 4h")
        XCTAssertEqual(DisplayFormat.countdown(-5), "<1m")   // never negative text
    }

    func testLocalTimeConvertsFromUTC() {
        // 01:00 UTC is 04:00 in UTC+3 — never the raw UTC value.
        XCTAssertEqual(DisplayFormat.localTime(TestSupport.date("2026-10-08 01:00:00"), timeZone: plus3, locale: posix), "04:00")
        XCTAssertEqual(DisplayFormat.localTime(TestSupport.date("2026-10-08 06:00:00"), timeZone: plus3, locale: posix), "09:00")
        XCTAssertEqual(DisplayFormat.localTime(TestSupport.date("2026-10-08 01:00:00"), timeZone: TestSupport.utc, locale: posix), "01:00")
    }

    func testLocalStampAndDateRollover() {
        XCTAssertEqual(DisplayFormat.localStamp(TestSupport.date("2026-10-08 01:00:00"), timeZone: plus3, locale: posix),
                       "Thu 08 Oct · 04:00")
        // 23:00 UTC on the 7th is 02:00 on the 8th in UTC+3.
        XCTAssertEqual(DisplayFormat.localTime(TestSupport.date("2026-10-07 23:00:00"), timeZone: plus3, locale: posix), "02:00")
    }
}
