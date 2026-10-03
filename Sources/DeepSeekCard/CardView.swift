import SwiftUI
import DeepSeekCardCore

/// Placeholder card; replaced by the real hover card in the next task.
struct CardView: View {
    var clock: PeakClock
    var interaction: MenuBarInteraction

    var body: some View {
        Text(clock.phase.label)
            .padding(14)
            .frame(width: 260)
    }
}
