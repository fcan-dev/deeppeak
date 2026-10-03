import Foundation

/// The Chinese public-holiday calendar: the shipped `holidays.json` merged with
/// the user's optional `~/.config/deepseek-card/holidays.json`.
///
/// Loading never throws: every failure degrades to data plus a `note` the card
/// can show. Only official *off days* belong in the files — makeup workdays are
/// deliberately absent, because DeepSeek's rule is "Mon–Fri excluding holidays",
/// so a Saturday declared a workday is still off-peak.
public struct HolidayTable: Equatable, Sendable {
    /// Keys are `"yyyy-MM-dd"`, interpreted in the calendar used for lookup.
    public let names: [String: String]
    /// Non-nil when something about the data needs saying.
    public let note: String?

    public init(names: [String: String], note: String? = nil) {
        self.names = names
        self.note = note
    }

    public func name(on date: Date, calendar: Calendar) -> String? {
        names[HolidayTable.key(for: date, calendar: calendar)]
    }

    /// The entries for one year, keyed by `"yyyy-MM-dd"`.
    public func names(forYear year: Int) -> [String: String] {
        let prefix = String(format: "%04d-", year)
        return names.filter { $0.key.hasPrefix(prefix) }
    }

    /// `"yyyy-MM-dd"` for `date` in `calendar`'s time zone.
    public static func key(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: - Loading

    /// Reads both files, merges them (user entries win), and summarises what
    /// happened in `note`. `year` only affects the note: a year with no data at
    /// all is worth telling the user about.
    public static func load(year: Int,
                            bundledURL: URL = HolidaySource.bundledURL,
                            userURL: URL = HolidaySource.userFileURL) -> HolidayTable {
        var bundledNote: String?
        var names: [String: String] = [:]
        if let data = try? Data(contentsOf: bundledURL), let parsed = parse(data) {
            names = parsed
        } else {
            bundledNote = "Built-in holiday data at \(bundledURL.path) could not be read."
        }

        var userNote: String?
        if FileManager.default.fileExists(atPath: userURL.path) {
            if let data = try? Data(contentsOf: userURL), let parsed = parse(data) {
                // Identical copies are not overrides: a seeded user file must not
                // shadow later additions to the shipped data.
                let changed = parsed.filter { names[$0.key] != $0.value }.count
                if changed > 0 {
                    names.merge(parsed) { _, fromUser in fromUser }
                    userNote = "Using \(changed) \(changed == 1 ? "date" : "dates") from \(userURL.path)."
                }
            } else {
                userNote = "Ignoring unreadable \(userURL.path)."
            }
        }

        let table = HolidayTable(names: names)
        let noDataNote = table.names(forYear: year).isEmpty
            ? "No holiday data for \(year); add it to holidays.json."
            : nil

        return HolidayTable(names: names, note: bundledNote ?? noDataNote ?? userNote)
    }

    /// Years whose data is an estimate, pending the State Council's arrangement.
    /// Remove a year here once its official calendar is in `holidays.json`.
    public static let provisionalYears: Set<Int> = [2027]

    /// `[{"date": "2026-10-01", "name": "National Day"}]` → table, `nil` when malformed.
    public static func parse(_ data: Data) -> [String: String]? {
        guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        var names: [String: String] = [:]
        for entry in entries {
            guard let date = entry["date"] as? String, let name = entry["name"] as? String else { return nil }
            names[date] = name
        }
        return names
    }

    // MARK: - Writing

    /// Creates the user file from the shipped list when it is missing or empty,
    /// so *Edit Holidays* opens everything visible and editable. Never overwrites
    /// real content, and never touches a malformed file (the card already says it
    /// is unreadable — the user gets to fix it rather than lose it).
    public static func ensureUserFile(at url: URL = HolidaySource.userFileURL,
                                      bundledURL: URL = HolidaySource.bundledURL) {
        if let data = try? Data(contentsOf: url) {
            guard let existing = parse(data) else { return }   // malformed: leave it be
            guard existing.isEmpty else { return }             // real content: leave it be
        }
        let shipped = (try? Data(contentsOf: bundledURL)).flatMap(parse) ?? [:]
        guard !shipped.isEmpty else { return }
        write(shipped, to: url)
    }

    /// Writes entries in the documented shape, sorted by date.
    public static func write(_ entries: [String: String], to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let objects: [[String: String]] = entries.keys.sorted().map { key in
            ["date": key, "name": entries[key] ?? ""]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: objects,
                                                     options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: url)
    }
}
