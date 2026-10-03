/// Why a moment is off-peak. `chineseHoliday` carries the holiday's name so the
/// card can show it.
public enum OffPeakReason: Equatable, Hashable, Sendable {
    case weekday
    case weekend
    case chineseHoliday(String)
}

/// DeepSeek's pricing phase at a moment in time.
public enum Phase: Equatable, Hashable, Sendable {
    case peak
    case offPeak(OffPeakReason)

    /// Menu bar copy: exactly `PEAK` or `OFFPEAK`.
    public var label: String {
        switch self {
        case .peak: return "PEAK"
        case .offPeak: return "OFFPEAK"
        }
    }

    public var isPeak: Bool {
        if case .peak = self { return true }
        return false
    }

    /// `nil` when peak, otherwise the reason this moment is off-peak.
    public var reason: OffPeakReason? {
        if case .offPeak(let reason) = self { return reason }
        return nil
    }
}
