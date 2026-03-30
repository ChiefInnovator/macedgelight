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
        if AppSettings.shared.desktopIconsHidden {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            task.arguments = ["write", "com.apple.finder", "CreateDesktop", "-bool", "true"]
            try? task.run()
            task.waitUntilExit()
            let killall = Process()
            killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killall.arguments = ["Finder"]
            try? killall.run()
            AppSettings.shared.desktopIconsHidden = false
        }
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
