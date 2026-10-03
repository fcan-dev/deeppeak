import Foundation

/// Where holiday data comes from on disk.
///
/// - The **shipped** `holidays.json` at the repo root, copied into
///   `DeepSeekCard.app/Contents/Resources/` by `scripts/build.sh`. When running
///   from source (`swift run`, `swift test`) there is no bundle resource, so the
///   repo copy is located relative to this source file.
/// - The **user** file `~/.config/deepseek-card/holidays.json`, optional, edited
///   by the card's *Edit Holidays* button. Entries there win over the shipped
///   ones on a date collision.
public enum HolidaySource {
    /// The shipped `holidays.json`.
    public static var bundledURL: URL {
        if let resource = Bundle.main.resourceURL?.appendingPathComponent("holidays.json"),
           FileManager.default.fileExists(atPath: resource.path) {
            return resource
        }
        // .../Sources/DeepSeekCardCore/HolidaySource.swift → repo root.
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // DeepSeekCardCore
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("holidays.json")
    }

    /// The user's optional additions and overrides.
    public static let userFileURL: URL =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/deepseek-card/holidays.json")

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
