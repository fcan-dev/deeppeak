/// The indicator color a phase uses, as policy rather than paint.
///
/// Core decides *which* color a state gets, keeping that decision testable; the
/// app layer maps each case to a SwiftUI `Color`.
public enum IndicatorColor: Equatable, Hashable, Sendable {
    /// Off-peak, ordinary weekday hours.
    case green
    /// Off-peak, weekend.
    case darkGreen
    /// Off-peak, Chinese public holiday.
    case blue
    /// Peak.
    case red
}

extension Phase {
    public var indicatorColor: IndicatorColor {
        switch self {
        case .peak:                     return .red
        case .offPeak(.weekday):        return .green
        case .offPeak(.weekend):        return .darkGreen
        case .offPeak(.chineseHoliday): return .blue
        }
    }
}
