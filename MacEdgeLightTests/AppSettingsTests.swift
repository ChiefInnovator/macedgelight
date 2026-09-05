import XCTest
import Cocoa
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
    @MainActor
    func testMenuTogglesReflectSettingsAndReset() throws {
        let settings = AppSettings.shared
        let savedLogin = settings.launchAtLogin
        defer { settings.launchAtLogin = savedLogin }
        let manager = EdgeLightManager()
        let controller = StatusBarController(manager: manager)
        let menu = try XCTUnwrap(controller.menu)
        let values: [(String, ReferenceWritableKeyPath<AppSettings, Bool>)] = [
            ("Toggle Light", \.isLightOn), ("All Monitors", \.showOnAllMonitors),
            ("Cursor Reveal", \.cursorRevealEnabled), ("Magnifier", \.magnifierEnabled),
            ("Show in Screen Capture", \.visibleInCapture), ("Hide Desktop Icons", \.desktopIconsHidden),
            ("Show Controls", \.showControlPanel), ("Launch at Login", \.launchAtLogin)
        ]
        for enabled in [false, true, false] {
            for (_, path) in values { settings[keyPath: path] = enabled }
            controller.refreshMenuState()
            for (label, _) in values {
                let item = try XCTUnwrap(menu.items.first { $0.title.hasPrefix(label) })
                XCTAssertEqual(item.state, enabled ? .on : .off, label)
                XCTAssertTrue(item.title.contains(enabled ? "ON" : "OFF"), label)
            }
            for label in ["Brightness Up", "Warmer Light", "Thicker Border", "Switch Monitor", "Cursor Reveal"] {
                XCTAssertEqual(menu.items.first { $0.title.hasPrefix(label) }?.isEnabled, enabled, label)
            }
            XCTAssertEqual(menu.items.first { $0.title.hasPrefix("Magnifier") }?.isEnabled, true)
        }
        settings.resetToDefaults()
        controller.refreshMenuState()
        XCTAssertEqual(menu.items.first { $0.title.hasPrefix("Toggle Light") }?.state, .on)
        XCTAssertEqual(menu.items.first { $0.title.hasPrefix("Magnifier") }?.state, .off)
        XCTAssertEqual(menu.items.first { $0.title.hasPrefix("Menu Bar:") }?.title, "Menu Bar: Auto")
    }

    @MainActor
    func testMenuTracksExternalSettingChangesAfterSetter() async throws {
        let manager = EdgeLightManager()
        let controller = StatusBarController(manager: manager)
        AppSettings.shared.menuBarMode = 1
        AppSettings.shared.cursorRevealEnabled = true
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        let menu = try XCTUnwrap(controller.menu)
        XCTAssertEqual(menu.items.first { $0.title.hasPrefix("Menu Bar:") }?.title, "Menu Bar: Extend")
        XCTAssertEqual(menu.items.first { $0.title.hasPrefix("Cursor Reveal") }?.state, .on)
        AppSettings.shared.menuBarMode = 0
        controller.refreshMenuState()
        XCTAssertEqual(menu.items.first { $0.title.hasPrefix("Menu Bar:") }?.state, .off)
    }

    @MainActor
    func testToolbarToggleStatesAndBoostWaitingRemainCancellable() throws {
        let settings = AppSettings.shared
        let manager = EdgeLightManager()
        let panel = ControlPanelWindow(manager: manager)
        defer { panel.close() }
        func buttons(in view: NSView) -> [NSButton] {
            (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
        }
        let controls = buttons(in: try XCTUnwrap(panel.contentView))
        for enabled in [true, false] {
            settings.isLightOn = enabled
            settings.showOnAllMonitors = enabled
            settings.cursorRevealEnabled = enabled
            settings.visibleInCapture = enabled
            settings.magnifierEnabled = enabled
            settings.desktopIconsHidden = enabled
            panel.updateToggleStates()
            for label in ["Toggle Light", "All Monitors", "Cursor Reveal", "Show in Screen Capture", "Magnifier", "Hide Desktop Icons"] {
                let button = try XCTUnwrap(controls.first { $0.toolTip?.hasPrefix(label) == true })
                XCTAssertEqual(button.state, enabled ? .on : .off, label)
                XCTAssertTrue(button.toolTip?.contains(enabled ? "ON" : "OFF") == true, label)
            }
        }
        settings.edrBoosted = true
        let controller = StatusBarController(manager: manager)
        let item = try XCTUnwrap(controller.menu?.items.first { $0.title.hasPrefix("Display Brightness Boost") })
        XCTAssertEqual(item.state, .on)
        XCTAssertTrue(item.isEnabled, "A pending boost must remain cancellable")
        if !DisplayBrightnessManager.shared.isBoosted {
            XCTAssertTrue(item.title.contains("WAITING"))
            panel.updateToggleStates()
            let boostButton = try XCTUnwrap(controls.first { $0.toolTip?.hasPrefix("Display Brightness Boost") == true })
            XCTAssertTrue(boostButton.isEnabled)
            XCTAssertTrue(boostButton.toolTip?.localizedCaseInsensitiveContains("waiting") == true)
        }
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
