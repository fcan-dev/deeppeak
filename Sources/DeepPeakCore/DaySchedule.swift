import Foundation

/// One contiguous stretch of a UTC day with a single pricing phase.
public struct Segment: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let phase: Phase

    public init(start: Date, end: Date, phase: Phase) {
        self.start = start
        self.end = end
        self.phase = phase
    }
}

/// DeepSeek's peak/off-peak rules expressed as UTC day segments.
///
/// Peak is 01:00–04:00 and 06:00–10:00 UTC, Monday–Friday, excluding Chinese
/// public holidays; everything else is off-peak. Boundaries are
/// inclusive-start / exclusive-end.
public enum DaySchedule {
    /// The calendar every rule is evaluated in. Never the user's local zone.
    public static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Weekday band starts (hour offset from midnight) and their phases.
    private static let weekdayBands: [(hour: Int, phase: Phase)] = [
        (0, .offPeak(.weekday)),
        (1, .peak),
        (4, .offPeak(.weekday)),
        (6, .peak),
        (10, .offPeak(.weekday)),
    ]

    /// The UTC day containing `day`, split into phase segments.
    public static func segments(forUTCDay day: Date,
                                calendar: Calendar = utcCalendar,
                                holidays: HolidayTable) -> [Segment] {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        // A Chinese public holiday is off-peak all day, whatever the weekday.
        if let name = holidays.name(on: dayStart, calendar: calendar) {
            return [Segment(start: dayStart, end: dayEnd, phase: .offPeak(.chineseHoliday(name)))]
        }
        // Weekends are off-peak all day.
        let weekday = calendar.component(.weekday, from: dayStart)   // 1 = Sunday, 7 = Saturday
        if weekday == 1 || weekday == 7 {
            return [Segment(start: dayStart, end: dayEnd, phase: .offPeak(.weekend))]
        }

        return weekdayBands.enumerated().map { index, band in
            let start = calendar.date(byAdding: .hour, value: band.hour, to: dayStart)!
            let end = index + 1 < weekdayBands.count
                ? calendar.date(byAdding: .hour, value: weekdayBands[index + 1].hour, to: dayStart)!
                : dayEnd
            return Segment(start: start, end: end, phase: band.phase)
        }
    }

    /// The phase in effect at `date`.
    public static func phase(at date: Date,
                             calendar: Calendar = utcCalendar,
                             holidays: HolidayTable) -> Phase {
        let segments = segments(forUTCDay: date, calendar: calendar, holidays: holidays)
        for segment in segments where date >= segment.start && date < segment.end {
            return segment.phase
        }
        // Only reachable when `calendar` is not UTC-aligned and the instant falls
        // outside the day's segments.
        return segments.last?.phase ?? .offPeak(.weekday)
    }

    /// The next moment the phase **label** changes (peak ↔ offpeak), which may be
    /// several days out across a weekend or holiday. Reason-only changes — the
    /// start of a weekend, or a holiday — are not switches.
    public static func nextSwitch(after date: Date,
                                  calendar: Calendar = utcCalendar,
                                  holidays: HolidayTable) -> Date {
        let currentLabel = phase(at: date, calendar: calendar, holidays: holidays).label
        var day = date
        for _ in 0..<14 {
            for segment in segments(forUTCDay: day, calendar: calendar, holidays: holidays)
            where segment.start > date && segment.phase.label != currentLabel {
                return segment.start
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        // Unreachable for the real rules (the longest gap is well under two weeks).
        return calendar.date(byAdding: .day, value: 14, to: calendar.startOfDay(for: date))!
    }
}
