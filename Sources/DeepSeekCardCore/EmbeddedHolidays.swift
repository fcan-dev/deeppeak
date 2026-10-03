import Foundation

/// Built-in Chinese public-holiday data, so the app works with no config file.
///
/// Only the official *off days* (`isOffDay: true` in the State Council notice)
/// appear here. Makeup workdays on weekends are deliberately omitted: DeepSeek's
/// rule is "Mon–Fri excluding public holidays", so a declared workday Saturday
/// is still off-peak.
///
/// 2026 source: State Council notice 2025-11 (gov.cn `content_7047091`),
/// cross-checked against `NateScarlet/holiday-cn` `2026.json`.
public enum EmbeddedHolidays {
    private static let tables: [Int: [String: String]] = [
        2026: [
            // New Year's Day
            "2026-01-01": "New Year's Day",
            "2026-01-02": "New Year's Day",
            "2026-01-03": "New Year's Day",
            // Spring Festival
            "2026-02-15": "Spring Festival",
            "2026-02-16": "Spring Festival",
            "2026-02-17": "Spring Festival",
            "2026-02-18": "Spring Festival",
            "2026-02-19": "Spring Festival",
            "2026-02-20": "Spring Festival",
            "2026-02-21": "Spring Festival",
            "2026-02-22": "Spring Festival",
            "2026-02-23": "Spring Festival",
            // Qingming Festival
            "2026-04-04": "Qingming Festival",
            "2026-04-05": "Qingming Festival",
            "2026-04-06": "Qingming Festival",
            // Labor Day
            "2026-05-01": "Labor Day",
            "2026-05-02": "Labor Day",
            "2026-05-03": "Labor Day",
            "2026-05-04": "Labor Day",
            "2026-05-05": "Labor Day",
            // Dragon Boat Festival
            "2026-06-19": "Dragon Boat Festival",
            "2026-06-20": "Dragon Boat Festival",
            "2026-06-21": "Dragon Boat Festival",
            // Mid-Autumn Festival
            "2026-09-25": "Mid-Autumn Festival",
            "2026-09-26": "Mid-Autumn Festival",
            "2026-09-27": "Mid-Autumn Festival",
            // National Day
            "2026-10-01": "National Day",
            "2026-10-02": "National Day",
            "2026-10-03": "National Day",
            "2026-10-04": "National Day",
            "2026-10-05": "National Day",
            "2026-10-06": "National Day",
            "2026-10-07": "National Day",
        ],
    ]

    /// `"yyyy-MM-dd"` → holiday name, or `nil` when this year has no built-in data.
    public static func names(forYear year: Int) -> [String: String]? {
        tables[year]
    }
}
