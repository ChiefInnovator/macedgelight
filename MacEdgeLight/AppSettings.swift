import Foundation

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let brightness = "brightness"
        static let colorTemperature = "colorTemperature"
        static let isLightOn = "isLightOn"
        static let showControlPanel = "showControlPanel"
        static let currentMonitorIndex = "currentMonitorIndex"
        static let showOnAllMonitors = "showOnAllMonitors"
        static let launchAtLogin = "launchAtLogin"
        static let menuBarMode = "menuBarMode"
        static let cursorRevealEnabled = "cursorRevealEnabled"
        static let desktopIconsHidden = "desktopIconsHidden"
        static let visibleInCapture = "visibleInCapture"
        static let borderWidth = "borderWidth"
        static let magnifierEnabled = "magnifierEnabled"
    }

    @Published var brightness: Double {
        didSet { defaults.set(brightness, forKey: Keys.brightness) }
    }

    @Published var colorTemperature: Double {
        didSet { defaults.set(colorTemperature, forKey: Keys.colorTemperature) }
    }

    @Published var isLightOn: Bool {
        didSet { defaults.set(isLightOn, forKey: Keys.isLightOn) }
    }

    @Published var showControlPanel: Bool {
        didSet { defaults.set(showControlPanel, forKey: Keys.showControlPanel) }
    }

    @Published var currentMonitorIndex: Int {
        didSet { defaults.set(currentMonitorIndex, forKey: Keys.currentMonitorIndex) }
    }

    @Published var showOnAllMonitors: Bool {
        didSet { defaults.set(showOnAllMonitors, forKey: Keys.showOnAllMonitors) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    // 0 = below menu bar, 1 = extend over, 2 = auto (reveal on hover)
    @Published var menuBarMode: Int {
        didSet { defaults.set(menuBarMode, forKey: Keys.menuBarMode) }
    }

    @Published var cursorRevealEnabled: Bool {
        didSet { defaults.set(cursorRevealEnabled, forKey: Keys.cursorRevealEnabled) }
    }

    @Published var desktopIconsHidden: Bool {
        didSet { defaults.set(desktopIconsHidden, forKey: Keys.desktopIconsHidden) }
    }

    @Published var visibleInCapture: Bool {
        didSet { defaults.set(visibleInCapture, forKey: Keys.visibleInCapture) }
    }

    @Published var borderWidth: Double {
        didSet { defaults.set(borderWidth, forKey: Keys.borderWidth) }
    }

    @Published var magnifierEnabled: Bool {
        didSet { defaults.set(magnifierEnabled, forKey: Keys.magnifierEnabled) }
    }

    func resetToDefaults() {
        brightness = 1.0
        colorTemperature = 0.5
        isLightOn = true
        menuBarMode = 2
        cursorRevealEnabled = false
        desktopIconsHidden = false
        visibleInCapture = false
        borderWidth = 60.0
        magnifierEnabled = false
    }

    private init() {
        // Register defaults
        defaults.register(defaults: [
            Keys.brightness: 1.0,
            Keys.colorTemperature: 0.5,
            Keys.isLightOn: true,
            Keys.showControlPanel: true,
            Keys.currentMonitorIndex: 0,
            Keys.showOnAllMonitors: false,
            Keys.launchAtLogin: false,
            Keys.menuBarMode: 2,
            Keys.cursorRevealEnabled: false,
            Keys.desktopIconsHidden: false,
            Keys.visibleInCapture: false,
            Keys.borderWidth: 60.0,
            Keys.magnifierEnabled: false,
        ])

        self.brightness = defaults.double(forKey: Keys.brightness)
        self.colorTemperature = defaults.double(forKey: Keys.colorTemperature)
        self.isLightOn = defaults.bool(forKey: Keys.isLightOn)
        self.showControlPanel = defaults.bool(forKey: Keys.showControlPanel)
        self.currentMonitorIndex = defaults.integer(forKey: Keys.currentMonitorIndex)
        self.showOnAllMonitors = defaults.bool(forKey: Keys.showOnAllMonitors)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        // Migration: old bool key -> new int key
        if defaults.object(forKey: Keys.menuBarMode) != nil {
            self.menuBarMode = defaults.integer(forKey: Keys.menuBarMode)
        } else if defaults.bool(forKey: "extendOverMenuBar") {
            self.menuBarMode = 1
            defaults.set(1, forKey: Keys.menuBarMode)
        } else {
            self.menuBarMode = 2
        }
        self.cursorRevealEnabled = defaults.bool(forKey: Keys.cursorRevealEnabled)
        self.desktopIconsHidden = defaults.bool(forKey: Keys.desktopIconsHidden)
        self.visibleInCapture = defaults.bool(forKey: Keys.visibleInCapture)
        self.borderWidth = defaults.double(forKey: Keys.borderWidth)
        self.magnifierEnabled = defaults.bool(forKey: Keys.magnifierEnabled)
    }
}
