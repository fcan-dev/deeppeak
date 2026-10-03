import Foundation

/// Text formatting for the menu bar and the card. Local-time output uses the
/// caller's zone; the rules themselves are always UTC.
public enum DisplayFormat {
    /// `"<1m"`, `"12m"`, `"10h 52m"`, `"2d 4h"`. Never negative.
    public static func countdown(_ interval: TimeInterval) -> String {
        let seconds = max(0, interval)
        if seconds < 60 { return "<1m" }
        if seconds < 3_600 { return "\(Int(seconds) / 60)m" }
        if seconds < 86_400 { return "\(Int(seconds) / 3_600)h \(Int(seconds) / 60 % 60)m" }
        return "\(Int(seconds) / 86_400)d \(Int(seconds) / 3_600 % 24)h"
    }

    /// `"04:00"` in the given zone.
    public static func localTime(_ date: Date, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        formatter("HH:mm", timeZone, locale).string(from: date)
    }

    /// A switch moment as a local clock reading: `"04:00"` when it still happens
    /// later today, otherwise day-qualified (`"Thu 04:00"`).
    ///
    /// Without the qualifier the card can be misread: the next peak is up to three
    /// days out, and west of UTC a switch can fall on the *previous* local day
    /// (`01:00` UTC is `20:00` yesterday in New York).
    public static func switchTime(_ date: Date,
                                 relativeTo now: Date,
                                 timeZone: TimeZone = .current,
                                 locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let sameDay = calendar.isDate(date, inSameDayAs: now)
        return formatter(sameDay ? "HH:mm" : "EEE HH:mm", timeZone, locale).string(from: date)
    }

    /// `"Thu 08 Oct · 04:00"` in the given zone.
    public static func localStamp(_ date: Date, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        formatter("EEE dd MMM · HH:mm", timeZone, locale).string(from: date)
    }

    private static func formatter(_ format: String, _ timeZone: TimeZone, _ locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = timeZone
        formatter.locale = locale
        return formatter
    }
}
