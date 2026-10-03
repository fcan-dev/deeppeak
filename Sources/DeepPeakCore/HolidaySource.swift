import Foundation

/// Where holiday data comes from on disk.
///
/// - The **shipped** `holidays.json` at the repo root, copied into
///   `DeepPeak.app/Contents/Resources/` by `scripts/build.sh`. When running
///   from source (`swift run`, `swift test`) there is no bundle resource, so the
///   repo copy is located relative to this source file.
/// - The **user** file `~/.config/deeppeak/holidays.json`, optional, edited
///   by the card's *Edit Holidays* button. Entries there win over the shipped
///   ones on a date collision.
public enum HolidaySource {
    /// Where the user file lives: `~/.config/deeppeak/`.
    public static let configDirectory: URL =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/deeppeak")

    /// The shipped `holidays.json`.
    public static var bundledURL: URL {
        if let resource = Bundle.main.resourceURL?.appendingPathComponent("holidays.json"),
           FileManager.default.fileExists(atPath: resource.path) {
            return resource
        }
        // .../Sources/DeepPeakCore/HolidaySource.swift → repo root.
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // DeepPeakCore
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("holidays.json")
    }

    /// The user's optional additions and overrides.
    public static let userFileURL: URL =
        configDirectory.appendingPathComponent("holidays.json")

    /// Where the user file lived before the app was renamed, migrated on launch.
    public static let legacyDirectory: URL =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/deepseek-card")

    public static let legacyUserFileURL: URL =
        legacyDirectory.appendingPathComponent("holidays.json")

    /// Moves a pre-rename user file to its current location. Never overwrites:
    /// if the destination exists, the legacy file is left exactly where it is
    /// (the app reads only the new path, so a leftover cannot affect anything).
    @discardableResult
    public static func migrateLegacyUserFile(from: URL = legacyUserFileURL,
                                            to: URL = userFileURL) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: from.path),
              !fileManager.fileExists(atPath: to.path) else { return false }
        try? fileManager.createDirectory(at: to.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
        do {
            try fileManager.moveItem(at: from, to: to)
            return true
        } catch {
            return false
        }
    }

    /// A cheap fingerprint of both files, so the clock can notice an edit
    /// without re-reading them every second.
    public static func stamp(bundledURL: URL = bundledURL, userURL: URL = userFileURL) -> String {
        [bundledURL, userURL].map { url in
            let modified = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
            return "\(url.path):\(modified?.timeIntervalSince1970 ?? -1)"
        }
        .joined(separator: "|")
    }
}
