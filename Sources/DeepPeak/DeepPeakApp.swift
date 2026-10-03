import SwiftUI
import AppKit
import DeepPeakCore

@main
struct DeepPeakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No windows; the status item + popover are created by the AppDelegate.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var clock: PeakClock?
    private var controller: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon / app menu
        HolidaySource.migrateLegacyUserFile()   // one-time move from the old name
        let c = PeakClock()
        c.start()                               // tick continuously
        clock = c
        controller = StatusItemController(clock: c)
    }
}
