import Foundation

/// The Chinese public-holiday calendar for one year, loaded from
/// `~/.config/deepseek-card/holidays-<year>.json` with the built-in table as a
/// fallback. Loading never throws: every failure degrades to data plus a `note`
/// the card can show.
public struct HolidayTable: Equatable, Sendable {
    public let year: Int
    /// Keys are `"yyyy-MM-dd"`, interpreted in the calendar used for lookup.
    public let names: [String: String]
    /// Non-nil when the file was auto-created, was invalid, or holds no data.
    public let note: String?

    public init(year: Int, names: [String: String], note: String? = nil) {
        self.year = year
        self.names = names
        self.note = note
    }

    public static let defaultDirectory: URL =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/deepseek-card")

    public static func fileURL(forYear year: Int, directory: URL = defaultDirectory) -> URL {
        directory.appendingPathComponent("holidays-\(year).json")
    }

    /// The built-in table for `year`, or `nil` when none ships yet.
    public static func embedded(year: Int) -> HolidayTable? {
        guard let names = EmbeddedHolidays.names(forYear: year) else { return nil }
        return HolidayTable(year: year, names: names)
    }

    public func name(on date: Date, calendar: Calendar) -> String? {
        names[HolidayTable.key(for: date, calendar: calendar)]
    }

    /// `"yyyy-MM-dd"` for `date` in `calendar`'s time zone.
    public static func key(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: - Loading

    public static func load(year: Int, directory: URL = defaultDirectory) -> HolidayTable {
        let url = fileURL(forYear: year, directory: directory)
        let embeddedNames = EmbeddedHolidays.names(forYear: year)

        guard FileManager.default.fileExists(atPath: url.path) else {
            let names = embeddedNames ?? [:]
            write(names: names, year: year, to: url)
            return HolidayTable(year: year, names: names, note: noDataNote(year: year, url: url, hasNames: !names.isEmpty, created: true))
        }

        guard let data = try? Data(contentsOf: url), let parsed = parse(data) else {
            let names = embeddedNames ?? [:]
            let note = names.isEmpty
                ? "Holiday file at \(url.path) is invalid; using no holidays."
                : "Holiday file at \(url.path) is invalid; using built-in data."
            return HolidayTable(year: year, names: names, note: note)
        }

        let note = parsed.isEmpty ? noDataNote(year: year, url: url, hasNames: false, created: false) : nil
        return HolidayTable(year: year, names: parsed, note: note)
    }

    private static func noDataNote(year: Int, url: URL, hasNames: Bool, created: Bool) -> String {
        guard hasNames, created else { return "No holiday data for \(year); add \(url.path)." }
        return "Created default holiday data at \(url.path)."
    }

    /// `[{"date": "2026-10-01", "name": "National Day"}]` → table, `nil` when malformed.
    private static func parse(_ data: Data) -> [String: String]? {
        guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        var names: [String: String] = [:]
        for entry in entries {
            guard let date = entry["date"] as? String, let name = entry["name"] as? String else { return nil }
            names[date] = name
        }
        return names
    }

    /// Writes the file in the documented shape, sorted by date.
    public static func write(names: [String: String], year: Int, to url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let entries: [[String: String]] = names.keys.sorted().map {
            ["date": $0, "name": names[$0] ?? ""]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: entries,
                                                     options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: url)
    }
}
