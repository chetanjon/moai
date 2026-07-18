import SwiftUI

@main
struct MoaiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The island itself
        let controller = NotchWindowController()
        controller.show()
        notchController = controller

        // Tiny menu bar item so the agent app can be quit
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: "Moai"
        )
        icon?.isTemplate = true
        item.button?.image = icon
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Quit Moai",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        item.menu = menu
        statusItem = item
    }
}
