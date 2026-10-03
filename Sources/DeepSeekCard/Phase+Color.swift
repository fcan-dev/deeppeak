import SwiftUI
import AppKit
import DeepSeekCardCore

extension Phase {
    /// The concrete color for this phase, used by the menu bar label and by the
    /// card's dot, headline and chip. Which state gets which color is Core's
    /// `indicatorColor`.
    var displayColor: Color {
        switch indicatorColor {
        case .green:     return .green
        case .darkGreen: return .weekendGreen
        case .blue:      return .blue
        case .red:       return .red
        }
    }
}

extension Color {
    /// Dark green for weekends. Deliberately darker than `.green` in light mode,
    /// and lifted a little in dark mode so it stays legible on a dark menu bar.
    /// (SwiftUI has no `.darkGreen`; a dynamic NSColor is the macOS-native way.)
    static let weekendGreen = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0.13, green: 0.55, blue: 0.29, alpha: 1)
            : NSColor(srgbRed: 0.06, green: 0.42, blue: 0.18, alpha: 1)
    })
}
