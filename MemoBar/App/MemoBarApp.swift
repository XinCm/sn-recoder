import AppKit
import SwiftUI

@main
struct MemoBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = MemoStore()
    @StateObject private var panel = PanelModel()

    var body: some Scene {
        MenuBarExtra {
            RootPanelView()
                .environmentObject(store)
                .environmentObject(panel)
        } label: {
            Image(systemName: "calendar")
                .accessibilityLabel("备忘录")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement already hides the Dock icon; setting the policy keeps the
        // behaviour right when the executable is run outside its bundle.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
