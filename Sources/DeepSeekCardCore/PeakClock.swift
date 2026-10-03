import Foundation
import Observation

/// The live peak/off-peak state, recomputed on a timer.
///
/// Holds no UI and touches nothing but the holiday files: the phase is a pure
/// function of `now` and `holidayTable`. All rule math is UTC.
@MainActor
@Observable
public final class PeakClock {
    public private(set) var now: Date
    public private(set) var holidayTable: HolidayTable

    private let bundledURL: URL
    private let userURL: URL
    private let nowProvider: @Sendable () -> Date
    private let tickInterval: Duration
    private var lastStamp: String
    private var lastDayKey: String
    private var task: Task<Void, Never>?

    public init(now: Date = Date(),
                bundledURL: URL = HolidaySource.bundledURL,
                userURL: URL = HolidaySource.userFileURL,
                nowProvider: @escaping @Sendable () -> Date = { Date() },
                tickInterval: Duration = .seconds(1)) {
        self.now = now
        self.bundledURL = bundledURL
        self.userURL = userURL
        self.nowProvider = nowProvider
        self.tickInterval = tickInterval
        self.holidayTable = HolidayTable.load(year: PeakClock.utcYear(of: now),
                                              bundledURL: bundledURL, userURL: userURL)
        self.lastStamp = HolidaySource.stamp(bundledURL: bundledURL, userURL: userURL)
        self.lastDayKey = HolidayTable.key(for: now, calendar: DaySchedule.utcCalendar)
    }

    // MARK: - Derived state

    public var phase: Phase {
        DaySchedule.phase(at: now, holidays: holidayTable)
    }

    /// The next peak ↔ offpeak label change, possibly several days out.
    public var nextSwitch: Date {
        DaySchedule.nextSwitch(after: now, holidays: holidayTable)
    }

    public var timeRemaining: TimeInterval {
        nextSwitch.timeIntervalSince(now)
    }

    /// Something worth telling the user about the holiday data, if anything.
    public var holidayNote: String? {
        holidayTable.note
    }

    /// A reminder while a year's arrangement is still an estimate. The State
    /// Council publishes next year's calendar in the autumn, so from October the
    /// widget starts nudging about the year ahead.
    public var provisionalNote: String? {
        let calendar = DaySchedule.utcCalendar
        let year = calendar.component(.year, from: now)
        if HolidayTable.provisionalYears.contains(year) {
            return "\(year) holidays are provisional; update holidays.json once the official notice lands."
        }
        if calendar.component(.month, from: now) >= 10,
           HolidayTable.provisionalYears.contains(year + 1) {
            return "\(year + 1) holidays are provisional — the State Council notice is due around now."
        }
        return nil
    }

    // MARK: - Ticking

    /// Starts the ticking loop (idempotent).
    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                try? await Task.sleep(for: self.tickInterval)
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    /// Advances `now`, and re-reads the holiday files when they changed on disk
    /// (so an *Edit Holidays* save takes effect immediately) or when the UTC day
    /// changed (which also refreshes the per-year note).
    public func tick() {
        now = nowProvider()

        let dayKey = HolidayTable.key(for: now, calendar: DaySchedule.utcCalendar)
        let stamp = HolidaySource.stamp(bundledURL: bundledURL, userURL: userURL)
        guard stamp != lastStamp || dayKey != lastDayKey else { return }
        lastStamp = stamp
        lastDayKey = dayKey
        holidayTable = HolidayTable.load(year: PeakClock.utcYear(of: now),
                                         bundledURL: bundledURL, userURL: userURL)
    }

    private static func utcYear(of date: Date) -> Int {
        DaySchedule.utcCalendar.component(.year, from: date)
    }
}
