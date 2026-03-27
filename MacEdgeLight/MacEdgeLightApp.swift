import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var edgeLightManager: EdgeLightManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure we don't show in the Dock (LSUIElement in Info.plist handles this,
        // but belt-and-suspenders)
        NSApp.setActivationPolicy(.accessory)

        edgeLightManager = EdgeLightManager()
        edgeLightManager?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DisplayBrightnessManager.shared.restore()
        edgeLightManager?.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}

@main
enum MacEdgeLightApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
