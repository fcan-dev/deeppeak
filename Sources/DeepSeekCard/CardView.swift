import SwiftUI
import AppKit
import DeepSeekCardCore

struct CardView: View {
    var clock: PeakClock
    var interaction: MenuBarInteraction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            HairlineDivider()
            content
            if let note = clock.holidayNote {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HairlineDivider()
            footer
        }
        .padding(14)
        .frame(width: 260)
        .onHover { inside in
            interaction.insidePopover = inside
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(clock.phase.displayColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text("DeepSeek")
                    .font(.system(size: 13, weight: .semibold))
                Text(DisplayFormat.localStamp(clock.now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    /// What the countdown is counting down to.
    private var nextLabel: String {
        clock.phase.isPeak ? "OFFPEAK" : "PEAK"
    }

    /// The chip explaining an off-peak moment, when there is something to explain.
    private var reasonChipText: String? {
        switch clock.phase.reason {
        case nil, .weekday:            return nil
        case .weekend:                 return "WEEKEND"
        case .chineseHoliday(let name): return name
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 6) {
            Text(clock.phase.label)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(clock.phase.displayColor)
                .frame(maxWidth: .infinity)

            Text("switches to \(nextLabel) in \(DisplayFormat.countdown(clock.timeRemaining)) · \(DisplayFormat.localTime(clock.nextSwitch))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if let chip = reasonChipText {
                Text(chip)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(clock.phase.displayColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(clock.phase.displayColor.opacity(0.15)))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var footer: some View {
        HStack {
            MenuItemButton("Edit Holidays") {
                // Create the user file on first use so there is always something to edit.
                HolidayTable.ensureUserFile()
                NSWorkspace.shared.open(HolidaySource.userFileURL)
            }
            Spacer()
            MenuItemButton("Quit") { NSApp.terminate(nil) }
        }
    }
}

/// A 1pt separator hairline, inset from the edges like a native menu divider.
struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1)
            .padding(.horizontal, 12)
    }
}

/// A borderless button mimicking an NSMenu item: 13pt text, 22pt row,
/// system accent highlight with white text on hover.
struct MenuItemButton: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .frame(height: 22)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(hovering ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(hovering ? Color.accentColor : .clear)
        )
        .onHover { hovering = $0 }
    }
}
