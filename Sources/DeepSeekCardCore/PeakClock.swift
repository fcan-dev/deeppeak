import Foundation
import Observation

/// The live peak/off-peak state, recomputed on a timer.
///
/// Holds no UI and touches nothing but the holiday file: the phase is a pure
/// function of `now` and `holidayTable`. All rule math is UTC.
@MainActor
@Observable
public final class PeakClock {
    public private(set) var now: Date
    public private(set) var holidayTable: HolidayTable

    private let holidayDirectory: URL
    private let nowProvider: @Sendable () -> Date
    private let tickInterval: Duration
    private var lastDayKey: String
    private var task: Task<Void, Never>?

    public init(now: Date = Date(),
                holidayDirectory: URL = HolidayTable.defaultDirectory,
                nowProvider: @escaping @Sendable () -> Date = { Date() },
                tickInterval: Duration = .seconds(1)) {
        self.now = now
        self.holidayDirectory = holidayDirectory
        self.nowProvider = nowProvider
        self.tickInterval = tickInterval
        self.holidayTable = HolidayTable.load(year: PeakClock.utcYear(of: now), directory: holidayDirectory)
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

    /// The holiday file's status note, if any (auto-created, invalid, or missing data).
    public var holidayNote: String? {
        holidayTable.note
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

    /// Advances `now` and reloads holiday data when the UTC day changes.
    public func tick() {
        now = nowProvider()

        let dayKey = HolidayTable.key(for: now, calendar: DaySchedule.utcCalendar)
        guard dayKey != lastDayKey else { return }
        lastDayKey = dayKey
        holidayTable = HolidayTable.load(year: PeakClock.utcYear(of: now), directory: holidayDirectory)
    }

    private static func utcYear(of date: Date) -> Int {
        DaySchedule.utcCalendar.component(.year, from: date)
    }
}
