import Foundation

enum TestSupport {
    static let utc = TimeZone(identifier: "UTC")!

    /// "2026-10-08 03:59:59" in UTC.
    static func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = utc
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let d = f.date(from: s) else { fatalError("bad test date: \(s)") }
        return d
    }

    static func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dsc-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A path guaranteed not to exist, for "no user override" cases.
    static func absentURL() -> URL {
        tempDir().appendingPathComponent("absent.json")
    }
}
