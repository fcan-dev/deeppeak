# DeepSeekCard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS menu bar app that shows whether DeepSeek API pricing is currently PEAK or OFFPEAK, color-coded by reason (weekday / weekend / Chinese public holiday), with a hover card showing when it switches and why.

**Architecture:** Swift Package with two targets. `DeepSeekCardCore` is pure, AppKit-free logic: a `Phase` model, a per-year `HolidayTable` backed by an embedded default, a `DaySchedule` that turns a UTC day into phase segments, a `DisplayFormat` text helper, and a `@MainActor @Observable PeakClock` that ticks once a second. `DeepSeekCard` is the AppKit/SwiftUI menu bar app, adapting the hover-popover pattern from `fcan-dev/gpu_stat_card`. No network, no third-party dependencies.

**Tech Stack:** Swift 6.3 toolchain / `swift-tools-version: 5.10`, SwiftUI + AppKit (`NSStatusItem` + `NSPopover`), Swift Observation, XCTest (`swift test`), `codesign` ad-hoc packaging.

**Spec:** `docs/superpowers/specs/2026-10-02-deepseek-peak-card-design.md`

## Global Constraints

- `platforms: [.macOS(.v14)]`, `swift-tools-version: 5.10`; no third-party dependencies.
- **No network access anywhere.** The only I/O is reading/writing `~/.config/deepseek-card/holidays-<year>.json`.
- All rules math in UTC, always: the default calendar is `TimeZone(identifier: "UTC")!`. Local time is used only for display text.
- Peak = 01:00–04:00 and 06:00–10:00 UTC, Mon–Fri, excluding Chinese public holidays. Start-inclusive, end-exclusive (01:00:00 peak, 03:59:59.999 peak, 04:00:00 off-peak).
- Off-peak reason precedence: `chineseHoliday` > `weekend` > `weekday`.
- Menu bar copy is exactly `PEAK` / `OFFPEAK`. Colors: peak = amber (`Color.orange`), off-peak weekday = green, off-peak weekend = blue, off-peak holiday = purple.
- Config dir `~/.config/deepseek-card/`; holiday files `holidays-<year>.json` as `[{"date":"2026-10-01","name":"National Day"}]`.
- App/product name `DeepSeekCard`; bundle id `com.fcan-dev.deepseekcard`; `LSUIElement` true (accessory app, no Dock icon).
- Weekday test fixture: UTC, 2026-10-08 = Thursday, 2026-10-09 = Friday, 2026-10-10 = Saturday, 2026-10-11 = Sunday, 2026-10-12 = Monday. National Day covers 2026-10-01 – 2026-10-07 inclusive.

## Review Focus

Inputs/conditions the spec implies but no task's tests cover by default — each has its test in the owning task, added below:

1. **Boundary time shown in the user's zone, not raw UTC** — 01:00 UTC must display as `04:00` in UTC+3, never `01:00`. → Task 4 `testLocalTimeConvertsFromUTC`.
2. **Phase changing while the app runs** — the label and color must flip at the boundary with no restart. → Task 5 `testTickAdvancesPhaseAcrossBoundary`.
3. **Holiday file edited or broken mid-run** — a rewritten file must be picked up, a corrupt one must degrade to embedded data plus a note, never crash. → Task 2 `testInvalidJSONFallsBackWithNote`, Task 5 `testReloadsHolidayFileOnDayChange`.
4. **Machine not in UTC / DST** — a UTC+13 machine must produce identical phases; no local calendar sneaks into the math. → Task 3 `testDefaultCalendarIsUTC` plus every boundary test running on the default calendar.
5. **First run with no `~/.config/deepseek-card/`** — directory and file are created, the note is shown, and phases are still correct. → Task 2 `testMissingFileIsCreatedAndNoted`.

---

### Task 1: Package skeleton + Phase model

**Files:**
- Create: `Package.swift`
- Create: `Sources/DeepSeekCardCore/Phase.swift`
- Test: `Tests/DeepSeekCardCoreTests/PhaseTests.swift`
- Test: `Tests/DeepSeekCardCoreTests/TestSupport.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `OffPeakReason` (`.weekday`, `.weekend`, `.chineseHoliday(String)`), `Phase` (`.peak`, `.offPeak(OffPeakReason)`), `Phase.label: String`, `Phase.isPeak: Bool`; test helper `TestSupport.date(_:) -> Date` (UTC), `TestSupport.tempDir() -> URL`, `TestSupport.utc`.

- [ ] **Step 1: Write the failing test**

`Tests/DeepSeekCardCoreTests/TestSupport.swift` (helper used by every later task):

```swift
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
}
```

`Tests/DeepSeekCardCoreTests/PhaseTests.swift`:

```swift
import XCTest
@testable import DeepSeekCardCore

final class PhaseTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(Phase.peak.label, "PEAK")
        XCTAssertEqual(Phase.offPeak(.weekday).label, "OFFPEAK")
        XCTAssertEqual(Phase.offPeak(.weekend).label, "OFFPEAK")
        XCTAssertEqual(Phase.offPeak(.chineseHoliday("National Day")).label, "OFFPEAK")
        XCTAssertTrue(Phase.peak.isPeak)
        XCTAssertFalse(Phase.offPeak(.weekend).isPeak)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test`
Expected: FAIL — `no such module 'DeepSeekCardCore'` (package does not exist yet).

- [ ] **Step 3: Implement**

`Package.swift` (the `DeepSeekCard` executable target is added in Task 6):

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DeepSeekCard",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "DeepSeekCardCore",
            path: "Sources/DeepSeekCardCore"
        ),
        .testTarget(
            name: "DeepSeekCardCoreTests",
            dependencies: ["DeepSeekCardCore"],
            path: "Tests/DeepSeekCardCoreTests"
        ),
    ]
)
```

`Sources/DeepSeekCardCore/Phase.swift` — public enums with `Sendable`, `Equatable`, `Hashable`; `label` returns `"PEAK"` for `.peak` and `"OFFPEAK"` for any `.offPeak`. Also add `public var reason: OffPeakReason?` returning `nil` for `.peak` and a `public var isPeak: Bool`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS (`PhaseTests.testLabels`, 1 test).

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/DeepSeekCardCore/Phase.swift Tests/DeepSeekCardCoreTests/
git commit -m "feat(core): package skeleton and Phase model"
```

---

### Task 2: Holiday data (EmbeddedHolidays + HolidayTable)

**Files:**
- Create: `Sources/DeepSeekCardCore/EmbeddedHolidays.swift`
- Create: `Sources/DeepSeekCardCore/HolidayTable.swift`
- Test: `Tests/DeepSeekCardCoreTests/HolidayTableTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `EmbeddedHolidays.names(forYear:) -> [String: String]?`; `HolidayTable` with `init(year:names:note:)`, `let year: Int`, `let names: [String: String]` (keys `"yyyy-MM-dd"`), `let note: String?`, `static let defaultDirectory: URL`, `static func fileURL(forYear:directory:) -> URL`, `static func load(year:directory:) -> HolidayTable`, `static func embedded(year:) -> HolidayTable?`, `func name(on:calendar:) -> String?`, `static func key(for:calendar:) -> String`.

- [ ] **Step 1: Write the failing tests**

`Tests/DeepSeekCardCoreTests/HolidayTableTests.swift`:

```swift
import XCTest
@testable import DeepSeekCardCore

final class HolidayTableTests: XCTestCase {
    private let utc = TestSupport.utc

    func testEmbedded2026Has33Days() {
        let t = HolidayTable.embedded(year: 2026)
        XCTAssertEqual(t?.names.count, 33)
        XCTAssertEqual(t?.names["2026-10-01"], "National Day")
        XCTAssertEqual(t?.names["2026-05-03"], "Labor Day")
        XCTAssertEqual(t?.names["2026-09-27"], "Mid-Autumn Festival")
        XCTAssertNil(t?.names["2026-10-08"])   // first normal day after the holiday
        XCTAssertNil(t?.names["2026-01-04"])   // makeup workday, deliberately absent
        XCTAssertNil(HolidayTable.embedded(year: 2027))
    }

    func testMissingFileIsCreatedAndNoted() throws {
        let dir = TestSupport.tempDir()
        let t = HolidayTable.load(year: 2026, directory: dir)
        XCTAssertEqual(t.names.count, 33)
        XCTAssertEqual(t.note?.contains("Created default holiday data"), true, "note was \(t.note ?? "nil")")
        let url = HolidayTable.fileURL(forYear: 2026, directory: dir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let again = HolidayTable.load(year: 2026, directory: dir)
        XCTAssertNil(again.note)               // second load: file is valid, no note
        XCTAssertEqual(again.names.count, 33)
    }

    func testInvalidJSONFallsBackWithNote() throws {
        let dir = TestSupport.tempDir()
        let url = HolidayTable.fileURL(forYear: 2026, directory: dir)
        try "{ not json".write(to: url, atomically: true, encoding: .utf8)
        let t = HolidayTable.load(year: 2026, directory: dir)
        XCTAssertEqual(t.names.count, 33)
        XCTAssertEqual(t.note?.contains("invalid"), true, "note was \(t.note ?? "nil")")
    }

    func testValidFileIsUsedWithoutNote() throws {
        let dir = TestSupport.tempDir()
        let url = HolidayTable.fileURL(forYear: 2027, directory: dir)
        let json = #"[{"date":"2027-01-01","name":"New Year's Day"}]"#
        try json.write(to: url, atomically: true, encoding: .utf8)
        let t = HolidayTable.load(year: 2027, directory: dir)
        XCTAssertEqual(t.names, ["2027-01-01": "New Year's Day"])
        XCTAssertNil(t.note)
    }

    func testYearWithoutDataNotesIt() {
        let t = HolidayTable.load(year: 2027, directory: TestSupport.tempDir())
        XCTAssertTrue(t.names.isEmpty)
        XCTAssertEqual(t.note?.contains("No holiday data for 2027"), true, "note was \(t.note ?? "nil")")
    }

    func testEmptyFileNotesNoData() throws {
        let dir = TestSupport.tempDir()
        let url = HolidayTable.fileURL(forYear: 2028, directory: dir)
        try "[]".write(to: url, atomically: true, encoding: .utf8)
        let t = HolidayTable.load(year: 2028, directory: dir)
        XCTAssertTrue(t.names.isEmpty)
        XCTAssertEqual(t.note?.contains("No holiday data for 2028"), true, "note was \(t.note ?? "nil")")
    }

    func testNameLookupUsesCalendarZone() {
        let t = HolidayTable(year: 2026, names: ["2026-10-01": "National Day"])
        XCTAssertEqual(t.name(on: TestSupport.date("2026-10-01 00:30:00"), calendar: utcCalendarFor(utc)), "National Day")
        let minus3 = utcCalendarFor(TimeZone(identifier: "America/Sao_Paulo")!)  // UTC-3
        XCTAssertNil(t.name(on: TestSupport.date("2026-10-01 00:30:00"), calendar: minus3))  // still 2026-09-30 there
    }

    private func utcCalendarFor(_ zone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = zone; return c
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter HolidayTableTests`
Expected: FAIL — `cannot find 'HolidayTable' in scope`.

- [ ] **Step 3: Implement**

`EmbeddedHolidays.swift` — a `[Int: [String: String]]` literal containing the 33 days of 2026 with these English names, plus `public static func names(forYear year: Int) -> [String: String]?`:

| Date keys | Name |
|---|---|
| 2026-01-01, 2026-01-02, 2026-01-03 | `New Year's Day` |
| 2026-02-15 … 2026-02-23 (9 days) | `Spring Festival` |
| 2026-04-04, 2026-04-05, 2026-04-06 | `Qingming Festival` |
| 2026-05-01 … 2026-05-05 (5 days) | `Labor Day` |
| 2026-06-19, 2026-06-20, 2026-06-21 | `Dragon Boat Festival` |
| 2026-09-25, 2026-09-26, 2026-09-27 | `Mid-Autumn Festival` |
| 2026-10-01 … 2026-10-07 (7 days) | `National Day` |

`HolidayTable.swift` — `defaultDirectory` is `~/.config/deepseek-card`; `fileURL(forYear:directory:)` appends `holidays-<year>.json`. `load(year:directory:)` implements exactly:

- file missing → `write` the embedded names for that year (or `[]` when embedded is `nil`), then load the written file; note = `"Created default holiday data at <path>."` when names are non-empty, else `"No holiday data for <year>; add <path>."`
- file present but unreadable / not a JSON array of `{"date": String, "name": String}` → names = embedded names for that year (or `[:]`), note = `"Holiday file at <path> is invalid; using built-in data."` (or `"…; using no holidays."` when there is no embedded data)
- file present and valid → parsed names, note = `nil` when non-empty, else `"No holiday data for <year>; add <path>."`

`write` uses `JSONSerialization` with `.prettyPrinted, .sortedKeys` over `[{"date": k, "name": v}]` sorted by date, creating the directory with `withIntermediateDirectories: true`. `key(for:calendar:)` formats `calendar.dateComponents([.year, .month, .day], from:)` as `%04d-%02d-%02d`. `name(on:calendar:)` is `names[key(for: date, calendar: calendar)]`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter HolidayTableTests`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DeepSeekCardCore/EmbeddedHolidays.swift Sources/DeepSeekCardCore/HolidayTable.swift Tests/DeepSeekCardCoreTests/HolidayTableTests.swift
git commit -m "feat(core): embedded 2026 holidays and per-year HolidayTable"
```

---

### Task 3: DaySchedule

**Files:**
- Create: `Sources/DeepSeekCardCore/DaySchedule.swift`
- Test: `Tests/DeepSeekCardCoreTests/DayScheduleTests.swift`

**Interfaces:**
- Consumes: `Phase`, `OffPeakReason` (Task 1); `HolidayTable.name(on:calendar:)`, `HolidayTable.key(for:calendar:)` (Task 2).
- Produces: `Segment` (`let start: Date`, `let end: Date`, `let phase: Phase`, `Equatable`, `Sendable`); `DaySchedule.utcCalendar: Calendar`; `DaySchedule.segments(forUTCDay:calendar:holidays:) -> [Segment]`; `DaySchedule.phase(at:calendar:holidays:) -> Phase`; `DaySchedule.nextSwitch(after:calendar:holidays:) -> Date`.

- [ ] **Step 1: Write the failing tests**

`Tests/DeepSeekCardCoreTests/DayScheduleTests.swift` (uses the embedded 2026 table via a local helper):

```swift
import XCTest
@testable import DeepSeekCardCore

final class DayScheduleTests: XCTestCase {
    private let holidays = HolidayTable.embedded(year: 2026)!

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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter DayScheduleTests`
Expected: FAIL — `cannot find 'DaySchedule' in scope`.

- [ ] **Step 3: Implement**

`DaySchedule.utcCalendar` is a `Gregorian` calendar with `timeZone = TimeZone(identifier: "UTC")!`, and every public entry point defaults `calendar` to it.

`segments(forUTCDay:calendar:holidays:)`: take `calendar.startOfDay(for:)` as `dayStart` and `calendar.date(byAdding: .day, value: 1, to: dayStart)!` as `dayEnd`; if `holidays.name(on: dayStart, calendar: calendar) != nil` → one segment `[dayStart, dayEnd)` with `.offPeak(.chineseHoliday(name))`; else if the day is Sat/Sun (`calendar.component(.weekday, from: dayStart)` in `1...2`, i.e. Sunday/Saturday) → one segment `.offPeak(.weekend)`; else five weekday segments at the fixed UTC offsets 0, 1, 4, 6, 10 with phases `.offPeak(.weekday), .peak, .offPeak(.weekday), .peak, .offPeak(.weekday)`.

`phase(at:calendar:holidays:)`: scan today's segments and return the phase of the segment containing `date` (half-open `[start, end)`); if none matches (only possible if `calendar` is not UTC-aligned), return the last segment's phase.

`nextSwitch(after:calendar:holidays:)`: walk forward from the current instant's day, at most 14 days; return the first segment boundary `> date` whose phase `label` differs from `phase(at: date)`. Scan day by day using each day's `segments`, comparing `segment.phase.label != currentLabel` for the segment's `start`; skip boundaries whose label matches.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DayScheduleTests`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DeepSeekCardCore/DaySchedule.swift Tests/DeepSeekCardCoreTests/DayScheduleTests.swift
git commit -m "feat(core): UTC day segments, phase lookup and next label switch"
```

---

### Task 4: DisplayFormat

**Files:**
- Create: `Sources/DeepSeekCardCore/DisplayFormat.swift`
- Test: `Tests/DeepSeekCardCoreTests/DisplayFormatTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `DisplayFormat.countdown(_ interval: TimeInterval) -> String`; `DisplayFormat.localTime(_ date: Date, timeZone: TimeZone, locale: Locale) -> String`; `DisplayFormat.localStamp(_ date: Date, timeZone: TimeZone, locale: Locale) -> String`. The `timeZone`/`locale` parameters default to `.current`; the UI passes the defaults so tests pass them explicitly.

- [ ] **Step 1: Write the failing tests**

`Tests/DeepSeekCardCoreTests/DisplayFormatTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter DisplayFormatTests`
Expected: FAIL — `cannot find 'DisplayFormat' in scope`.

- [ ] **Step 3: Implement**

`DisplayFormat` is a `public enum` with static methods. `countdown`: clamp `max(0, interval)`; under 60s → `"<1m"`; under an hour → `"<minutes>m"`; under 24h → `"<h>h <m>m"` (minutes floored); otherwise → `"<d>d <h>h"` (`hours = Int(interval)/3600 % 24`). `localTime` uses a `DateFormatter` with `timeZone`/`locale` set and `dateFormat = "HH:mm"`. `localStamp` uses `dateFormat = "EEE dd MMM · HH:mm"`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DisplayFormatTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DeepSeekCardCore/DisplayFormat.swift Tests/DeepSeekCardCoreTests/DisplayFormatTests.swift
git commit -m "feat(core): countdown and local-time display formatting"
```

---

### Task 5: PeakClock

**Files:**
- Create: `Sources/DeepSeekCardCore/PeakClock.swift`
- Test: `Tests/DeepSeekCardCoreTests/PeakClockTests.swift`

**Interfaces:**
- Consumes: `Phase` (Task 1); `HolidayTable.load(year:directory:)`, `defaultDirectory` (Task 2); `DaySchedule.phase(at:holidays:)`, `DaySchedule.nextSwitch(after:holidays:)` (Task 3).
- Produces: `@MainActor @Observable final class PeakClock` with `init(now:holidayDirectory:nowProvider:tickInterval:)`, `private(set) var now: Date`, `private(set) var holidayTable: HolidayTable`, `var holidayNote: String?` (the table's note), `var phase: Phase`, `var nextSwitch: Date`, `var timeRemaining: TimeInterval`, `func start()`, `func stop()`, `func tick()`.

- [ ] **Step 1: Write the failing tests**

`Tests/DeepSeekCardCoreTests/PeakClockTests.swift`:

```swift
import XCTest
@testable import DeepSeekCardCore

@MainActor
final class PeakClockTests: XCTestCase {
    func testPhaseAndNextSwitchAtFixedTime() {
        var current = TestSupport.date("2026-10-02 12:00:00")   // National Day, Friday
        let clock = PeakClock(now: current, holidayDirectory: TestSupport.tempDir(),
                              nowProvider: { current }, tickInterval: .seconds(3600))
        clock.tick()
        XCTAssertEqual(clock.now, current)
        XCTAssertEqual(clock.phase, .offPeak(.chineseHoliday("National Day")))
        XCTAssertEqual(clock.nextSwitch, TestSupport.date("2026-10-08 01:00:00"))
        XCTAssertEqual(clock.timeRemaining, TestSupport.date("2026-10-08 01:00:00").timeIntervalSince(current))
    }

    func testTickAdvancesPhaseAcrossBoundary() {
        var current = TestSupport.date("2026-10-08 00:59:58")
        let clock = PeakClock(now: current, holidayDirectory: TestSupport.tempDir(),
                              nowProvider: { current }, tickInterval: .seconds(1))
        clock.tick()
        XCTAssertEqual(clock.phase, .offPeak(.weekday))
        current = TestSupport.date("2026-10-08 00:59:59")
        clock.tick()
        XCTAssertEqual(clock.phase, .offPeak(.weekday))
        current = TestSupport.date("2026-10-08 01:00:00")
        clock.tick()
        XCTAssertEqual(clock.phase, .peak)                    // flips with no restart
        XCTAssertEqual(clock.nextSwitch, TestSupport.date("2026-10-08 04:00:00"))
    }

    func testReloadsHolidayFileOnDayChange() throws {
        let dir = TestSupport.tempDir()
        let url = HolidayTable.fileURL(forYear: 2026, directory: dir)
        try #"[{"date":"2026-01-01","name":"New Year's Day"}]"#
            .write(to: url, atomically: true, encoding: .utf8)
        var current = TestSupport.date("2026-10-08 23:59:00")
        let clock = PeakClock(now: current, holidayDirectory: dir,
                              nowProvider: { current }, tickInterval: .seconds(1))
        XCTAssertEqual(clock.holidayTable.names.count, 1)
        XCTAssertNil(clock.holidayNote)

        try #"[{"date":"2026-01-01","name":"New Year's Day"},{"date":"2026-10-09","name":"Bridge Day"}]"#
            .write(to: url, atomically: true, encoding: .utf8)
        current = TestSupport.date("2026-10-09 00:00:30")     // next UTC day
        clock.tick()
        XCTAssertEqual(clock.holidayTable.names.count, 2)     // reloaded
        XCTAssertEqual(clock.phase, .offPeak(.chineseHoliday("Bridge Day")))
    }

    func testStartAndStopTicking() async throws {
        let clock = PeakClock(now: TestSupport.date("2026-10-08 12:00:00"),
                              holidayDirectory: TestSupport.tempDir(),
                              tickInterval: .milliseconds(20))
        clock.start()
        clock.start()                                          // idempotent
        try await Task.sleep(for: .milliseconds(60))
        clock.stop()
        let stopped = clock.now
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(clock.now, stopped)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PeakClockTests`
Expected: FAIL — `cannot find 'PeakClock' in scope`.

- [ ] **Step 3: Implement**

`PeakClock` is `@MainActor @Observable public final class` (same shape as the reference app's `GPUPoller`). `init` stores `now`, `nowProvider`, `tickInterval`, and loads `holidayTable = HolidayTable.load(year: calendarYear(of: now), directory: holidayDirectory)`. Derived properties: `phase` → `DaySchedule.phase(at: now, holidays: holidayTable)`; `nextSwitch` → `DaySchedule.nextSwitch(after: now, holidays: holidayTable)`; `timeRemaining` → `nextSwitch.timeIntervalSince(now)`; `holidayNote` → `holidayTable.note`.

`start()` guards against a second task, then runs `while !Task.isCancelled { tick(); try? await Task.sleep(for: tickInterval) }`. `stop()` cancels and nils the task. `tick()` sets `now = nowProvider()`, and reloads the table when the UTC day changed since the last tick (compare `HolidayTable.key(for: now, calendar: DaySchedule.utcCalendar)` against the stored key; on a day change also reload when the year changes). Never touch `holidayDirectory` from the ticker other than this reload.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS — all suites (PhaseTests, HolidayTableTests, DayScheduleTests, DisplayFormatTests, PeakClockTests); 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/DeepSeekCardCore/PeakClock.swift Tests/DeepSeekCardCoreTests/PeakClockTests.swift
git commit -m "feat(core): PeakClock with 1s ticker and daily holiday reload"
```

---

### Task 6: Menu bar app shell

**Files:**
- Modify: `Package.swift` (add the executable target)
- Create: `Sources/DeepSeekCard/DeepSeekCardApp.swift`
- Create: `Sources/DeepSeekCard/Phase+Color.swift`
- Create: `Sources/DeepSeekCard/StatusBarLabel.swift`
- Create: `Sources/DeepSeekCard/StatusItemController.swift`

**Interfaces:**
- Consumes: `PeakClock`, `Phase`, `DisplayFormat` (Tasks 1, 4, 5).
- Produces: `Phase.displayColor: Color`; `StatusBarLabel(clock: PeakClock)`; `MenuBarInteraction` (`@MainActor @Observable final class` with `var insideStatus: Bool`, `var insidePopover: Bool`); `StatusItemController(clock: PeakClock)`; `AppDelegate`.

- [ ] **Step 1: Get the reference implementation**

```bash
git clone --depth 1 https://github.com/fcan-dev/gpu_stat_card /tmp/gpu_stat_card
```

- [ ] **Step 2: Adapt the reference files**

Copy these reference files as the starting point and apply exactly the listed changes — the hover/popover mechanics (0.1s update timer, signature-gated `ImageRenderer`, `StatusHoverView` tracking area with `hitTest → nil`, `popover.behavior = .semitransient`, `makeKey()` after `show`) are kept verbatim:

- `Sources/GPUStatCard/StatusItemController.swift` → `Sources/DeepSeekCard/StatusItemController.swift`
  - `poller: GPUPoller` → `clock: PeakClock`; `init(clock:)`; drop `import GPUStatCardCore`'s poller bits for `DeepSeekCardCore`.
  - `statusItem.button?.setAccessibilityLabel("DeepSeek pricing status")`.
  - `dataSignature` becomes `"\(clock.phase.label)|\(signatureReason)"` where `signatureReason` is `"peak"`, `"weekday"`, `"weekend"`, or `"holiday:<name>"` — so the label re-renders only when the text or color changes, never once per second.
  - `StatusBarLabel(poller:)` → `StatusBarLabel(clock:)`; the popover hosts `CardView(clock:interaction:)` (Task 7).
- `Sources/GPUStatCard/GPUStatCardApp.swift` → `Sources/DeepSeekCard/DeepSeekCardApp.swift`
  - Same `@main` `App` + `AppDelegate`, `NSApp.setActivationPolicy(.accessory)`, `Settings { EmptyView() }`.
  - Creates `let clock = PeakClock()`, `clock.start()`, then `StatusItemController(clock: clock)`.
- New file `Sources/DeepSeekCard/Phase+Color.swift`:

```swift
import SwiftUI
import DeepSeekCardCore

extension Phase {
    var displayColor: Color {
        switch self {
        case .peak:                     return .orange
        case .offPeak(.weekday):        return .green
        case .offPeak(.weekend):        return .blue
        case .offPeak(.chineseHoliday): return .purple
        }
    }
}
```

- New file `Sources/DeepSeekCard/StatusBarLabel.swift`, whole view body:

```swift
Text(clock.phase.label)
    .font(.system(size: 11, weight: .bold))
    .monospacedDigit()
    .foregroundStyle(clock.phase.displayColor)
    .padding(.horizontal, 2)
```

- `Package.swift`: add the executable target **before** the core `.target` entry (order is irrelevant to SwiftPM, keep it first for readability):

```swift
        .executableTarget(
            name: "DeepSeekCard",
            dependencies: ["DeepSeekCardCore"],
            path: "Sources/DeepSeekCard"
        ),
```

For this step, `CardView` does not exist yet — create a temporary `Sources/DeepSeekCard/CardView.swift` with the minimal `struct CardView: View { var clock: PeakClock; var interaction: MenuBarInteraction; var body: some View { Text(clock.phase.label).padding(14).frame(width: 260) } }` so the target compiles; Task 7 replaces it.

- [ ] **Step 3: Build and run**

Run: `swift build 2>&1 | tail -20`
Expected: `Build complete!` with no errors or warnings about unused results.

Run: `swift run DeepSeekCard`
Expected: a menu bar item appears reading `OFFPEAK` in **purple** (today, 2026-10-02, is National Day); no Dock icon; hovering shows a small placeholder card and moving away hides it; ⌃C stops it.

- [ ] **Step 4: Commit**

```bash
git add Package.swift Sources/DeepSeekCard/
git commit -m "feat(app): menu bar item showing PEAK/OFFPEAK with reason colors"
```

---

### Task 7: Hover card

**Files:**
- Create/Replace: `Sources/DeepSeekCard/CardView.swift`

**Interfaces:**
- Consumes: `PeakClock` (`phase`, `nextSwitch`, `timeRemaining`, `holidayNote`, `now`), `DisplayFormat` (Tasks 4, 5), `Phase.displayColor`, `MenuBarInteraction` (Task 6).
- Produces: `CardView(clock:interaction:)`, plus the `HairlineDivider` and `MenuItemButton` helper views (copied from the reference `CardView.swift` in `/tmp/gpu_stat_card`).

- [ ] **Step 1: Implement the card**

Adapt the reference `CardView.swift` structure (same `VStack(alignment: .leading, spacing: 12)`, `.padding(14)`, `.frame(width: 260)`, `.onHover { interaction.insidePopover = $0 }`, hairline dividers, and the `MenuItemButton` footer style) with this content:

- Header: `Circle().fill(clock.phase.displayColor).frame(width: 8, height: 8)` · `Text("DeepSeek")` (13pt semibold) · subtitle `Text(DisplayFormat.localStamp(clock.now))` (caption, secondary).
- `HairlineDivider()`
- Main: `Text(clock.phase.label)` — 20pt bold, `clock.phase.displayColor`, `.frame(maxWidth: .infinity)`, centered.
- Switch line (caption, secondary, centered): `"switches to \(nextLabel) in \(DisplayFormat.countdown(clock.timeRemaining)) · \(DisplayFormat.localTime(clock.nextSwitch))"` where `let nextLabel = clock.phase.isPeak ? "OFFPEAK" : "PEAK"`.
- Reason chip: only when `clock.phase` is `.offPeak` with reason `.weekend` or `.chineseHoliday(name)` — a `Capsule` (`.opacity(0.15)` fill in `displayColor`) containing 11pt bold text in `displayColor`: `"WEEKEND"` or the holiday name. Nothing for `.weekday` or `.peak`.
- Note line: when `let note = clock.holidayNote`, `Text(note).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)`.
- `HairlineDivider()`
- Footer: `MenuItemButton("Edit Holidays")` opening `HolidayTable.fileURL(forYear: DaySchedule.utcCalendar.component(.year, from: clock.now))` via `NSWorkspace.shared.open(url)` (create the file first with `HolidayTable.load(year:directory:)` if it does not exist), `Spacer()`, `MenuItemButton("Quit") { NSApp.terminate(nil) }`.

- [ ] **Step 2: Build and verify**

Run: `swift build 2>&1 | tail -20`
Expected: `Build complete!`.

Run: `swift run DeepSeekCard`
Expected, with today = 2026-10-02 (National Day, a Friday):
- Menu bar: purple `OFFPEAK`; card: purple dot, big purple `OFFPEAK`, chip reading `National Day`, switch line `switches to PEAK in 5d 13h · 04:00` (next peak is 2026-10-08 01:00 UTC = 04:00 in UTC+3), and no note line (the file was created on first run, so `note` is nil after the auto-create).
- Hover shows the card, moving away hides it; `Edit Holidays` opens today's holiday JSON.

- [ ] **Step 3: Commit**

```bash
git add Sources/DeepSeekCard/CardView.swift
git commit -m "feat(app): hover card with countdown, reason chip and holiday note"
```

---

### Task 8: Packaging and README

**Files:**
- Create: `scripts/build.sh`
- Create: `packaging/Info.plist`
- Create: `README.md`

**Interfaces:**
- Consumes: the `DeepSeekCard` executable target (Task 6).
- Produces: `dist/DeepSeekCard.app`.

- [ ] **Step 1: Add the packaging files**

`scripts/build.sh` — the reference script from `/tmp/gpu_stat_card/scripts/build.sh` with `APP_NAME="DeepSeekCard"`, otherwise byte-identical (shebang, `set -euo pipefail`, `cd "$(dirname "$0")/.."`, `rm -rf dist`, `mkdir -p Contents/MacOS Contents/Resources`, `swift build -c release`, copy the binary and `packaging/Info.plist`, `codesign --force --sign - "$DIST"`, echo the path).

`packaging/Info.plist` — the reference plist with these values: `CFBundleExecutable` = `DeepSeekCard`, `CFBundleIdentifier` = `com.fcan-dev.deepseekcard`, `CFBundleName` = `DeepSeekCard`, keep `CFBundlePackageType` `APPL`, `CFBundleShortVersionString` `1.0`, `CFBundleVersion` `1`, `LSMinimumSystemVersion` `14.0`, `LSUIElement` true, `NSHighResolutionCapable` true, `NSHumanReadableCopyright` `© 2026`.

`README.md` — same section structure as the reference (`# DeepSeekCard`, screenshot placeholder, How it works, The rules with the peak-hours table, Requirements: macOS 14+, Download note about ad-hoc signing + right-click Open, Build: `scripts/build.sh` / `swift run DeepSeekCard`, Config: where the holiday JSON lives and the note that it is re-read on the first tick of each new UTC day, Quit, Notes: no network, holidays updated annually each October).

- [ ] **Step 2: Build the app bundle and launch it**

Run: `chmod +x scripts/build.sh && scripts/build.sh`
Expected: `Built dist/DeepSeekCard.app`, and `codesign -dv dist/DeepSeekCard.app 2>&1 | head -3` shows `Signature=adhoc`.

Run: `open dist/DeepSeekCard.app`
Expected: purple `OFFPEAK` in the menu bar, hover card works, no Dock icon.

- [ ] **Step 3: Commit**

```bash
git add scripts/build.sh packaging/Info.plist README.md
git commit -m "chore: app bundle packaging and README"
```
