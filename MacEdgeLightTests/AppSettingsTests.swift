import XCTest
@testable import MacEdgeLight

final class AppSettingsTests: XCTestCase {
    // AppSettings is a UserDefaults-backed singleton; snapshot state before
    // each test and restore after so tests don't contaminate the real app.
    private var snapshot: SettingsSnapshot!

    override func setUp() {
        super.setUp()
        snapshot = SettingsSnapshot.capture()
    }

    override func tearDown() {
        snapshot.restore()
        super.tearDown()
    }

    func testResetToDefaultsRestoresKnownValues() {
        let s = AppSettings.shared

        // Mutate every resettable field away from its default
        s.brightness = 0.25
        s.colorTemperature = 0.9
        s.isLightOn = false
        s.menuBarMode = 0
        s.cursorRevealEnabled = true
        s.desktopIconsHidden = true
        s.visibleInCapture = true
        s.borderWidth = 125.0
        s.magnifierEnabled = true
        s.edrBoosted = true

        s.resetToDefaults()

        XCTAssertEqual(s.brightness, 1.0)
        XCTAssertEqual(s.colorTemperature, 0.5)
        XCTAssertTrue(s.isLightOn)
        XCTAssertEqual(s.menuBarMode, 2)
        XCTAssertFalse(s.cursorRevealEnabled)
        XCTAssertFalse(s.desktopIconsHidden)
        XCTAssertFalse(s.visibleInCapture)
        XCTAssertEqual(s.borderWidth, 60.0)
        XCTAssertFalse(s.magnifierEnabled)
        XCTAssertFalse(s.edrBoosted)
    }

    func testBrightnessPersistsToUserDefaults() {
        let s = AppSettings.shared
        s.brightness = 1.73
        XCTAssertEqual(UserDefaults.standard.double(forKey: "brightness"), 1.73, accuracy: 0.0001)
    }

    func testEdrBoostedPersistsToUserDefaults() {
        let s = AppSettings.shared
        s.edrBoosted = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "edrBoosted"))
        s.edrBoosted = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "edrBoosted"))
    }

    func testMenuBarModePersistsToUserDefaults() {
        let s = AppSettings.shared
        s.menuBarMode = 1
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "menuBarMode"), 1)
    }
}

/// Captures the full AppSettings state so tests can restore it after mutating.
private struct SettingsSnapshot {
    let brightness: Double
    let colorTemperature: Double
    let isLightOn: Bool
    let showControlPanel: Bool
    let currentMonitorIndex: Int
    let showOnAllMonitors: Bool
    let menuBarMode: Int
    let cursorRevealEnabled: Bool
    let desktopIconsHidden: Bool
    let visibleInCapture: Bool
    let borderWidth: Double
    let magnifierEnabled: Bool
    let edrBoosted: Bool

    static func capture() -> SettingsSnapshot {
        let s = AppSettings.shared
        return SettingsSnapshot(
            brightness: s.brightness,
            colorTemperature: s.colorTemperature,
            isLightOn: s.isLightOn,
            showControlPanel: s.showControlPanel,
            currentMonitorIndex: s.currentMonitorIndex,
            showOnAllMonitors: s.showOnAllMonitors,
            menuBarMode: s.menuBarMode,
            cursorRevealEnabled: s.cursorRevealEnabled,
            desktopIconsHidden: s.desktopIconsHidden,
            visibleInCapture: s.visibleInCapture,
            borderWidth: s.borderWidth,
            magnifierEnabled: s.magnifierEnabled,
            edrBoosted: s.edrBoosted
        )
    }

    func restore() {
        let s = AppSettings.shared
        s.brightness = brightness
        s.colorTemperature = colorTemperature
        s.isLightOn = isLightOn
        s.showControlPanel = showControlPanel
        s.currentMonitorIndex = currentMonitorIndex
        s.showOnAllMonitors = showOnAllMonitors
        s.menuBarMode = menuBarMode
        s.cursorRevealEnabled = cursorRevealEnabled
        s.desktopIconsHidden = desktopIconsHidden
        s.visibleInCapture = visibleInCapture
        s.borderWidth = borderWidth
        s.magnifierEnabled = magnifierEnabled
        s.edrBoosted = edrBoosted
    }
}
