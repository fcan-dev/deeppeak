import SwiftUI
import Observation
import DeepPeakCore

/// Shared hover state driving the popover's show/hide.
@MainActor
@Observable
final class MenuBarInteraction {
    var insideStatus = false
    var insidePopover = false
}

/// The content shown in the menu bar itself: `PEAK` / `OFFPEAK`, colored by
/// reason. Rendered to an `NSImage` by `StatusItemController`.
struct StatusBarLabel: View {
    var clock: PeakClock

    var body: some View {
        Text(clock.phase.label)
            .font(.system(size: 11, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(clock.phase.displayColor)
            .padding(.horizontal, 2)
    }
}
