import SwiftUI
import DeepSeekCardCore

extension Phase {
    /// Menu bar / card color for this phase. The reason, not just peak vs.
    /// off-peak, is what the color encodes.
    var displayColor: Color {
        switch self {
        case .peak:                     return .orange
        case .offPeak(.weekday):        return .green
        case .offPeak(.weekend):        return .blue
        case .offPeak(.chineseHoliday): return .purple
        }
    }
}
