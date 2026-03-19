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
        static let extendOverMenuBar = "extendOverMenuBar"
        static let cursorRevealEnabled = "cursorRevealEnabled"
        static let desktopIconsHidden = "desktopIconsHidden"
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

    @Published var extendOverMenuBar: Bool {
        didSet { defaults.set(extendOverMenuBar, forKey: Keys.extendOverMenuBar) }
    }

    @Published var cursorRevealEnabled: Bool {
        didSet { defaults.set(cursorRevealEnabled, forKey: Keys.cursorRevealEnabled) }
    }

    @Published var desktopIconsHidden: Bool {
        didSet { defaults.set(desktopIconsHidden, forKey: Keys.desktopIconsHidden) }
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
            Keys.extendOverMenuBar: false,
            Keys.cursorRevealEnabled: false,
            Keys.desktopIconsHidden: false,
        ])

        self.brightness = defaults.double(forKey: Keys.brightness)
        self.colorTemperature = defaults.double(forKey: Keys.colorTemperature)
        self.isLightOn = defaults.bool(forKey: Keys.isLightOn)
        self.showControlPanel = defaults.bool(forKey: Keys.showControlPanel)
        self.currentMonitorIndex = defaults.integer(forKey: Keys.currentMonitorIndex)
        self.showOnAllMonitors = defaults.bool(forKey: Keys.showOnAllMonitors)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.extendOverMenuBar = defaults.bool(forKey: Keys.extendOverMenuBar)
        self.cursorRevealEnabled = defaults.bool(forKey: Keys.cursorRevealEnabled)
        self.desktopIconsHidden = defaults.bool(forKey: Keys.desktopIconsHidden)
    }
}
