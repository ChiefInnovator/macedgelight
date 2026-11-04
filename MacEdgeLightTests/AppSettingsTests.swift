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

    @MainActor
    func testMenuBarBandUsesOnlyOwnScreenAndHalfOpenBounds() {
        let frame = NSRect(x: -1440, y: -900, width: 1440, height: 900)
        let visible = NSRect(x: -1440, y: -850, width: 1440, height: 825)
        for point in [NSPoint(x: -1440, y: -25), NSPoint(x: -1, y: -1)] {
            XCTAssertTrue(isPointInScreenMenuBar(point, frame: frame, visibleFrame: visible))
        }
        for point in [NSPoint(x: -1, y: 0), NSPoint(x: -1, y: 300),
                      NSPoint(x: 0, y: -1), NSPoint(x: -1441, y: -1),
                      NSPoint(x: -1, y: -26), NSPoint(x: -1, y: -901)] {
            XCTAssertFalse(isPointInScreenMenuBar(point, frame: frame, visibleFrame: visible))
        }
        XCTAssertFalse(isPointInScreenMenuBar(NSPoint(x: -1, y: -1), frame: frame, visibleFrame: frame))
        let upper = NSRect(x: -1440, y: 0, width: 1440, height: 900)
        let upperVisible = NSRect(x: -1440, y: 0, width: 1440, height: 875)
        XCTAssertTrue(isPointInScreenMenuBar(NSPoint(x: -1, y: 875), frame: upper, visibleFrame: upperVisible))
        XCTAssertFalse(isPointInScreenMenuBar(NSPoint(x: -1, y: 900), frame: upper, visibleFrame: upperVisible))
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
        s.boostLevel = 0.4

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
        XCTAssertEqual(s.boostLevel, 1.0)
    }

    func testBoostLevelValidationAndPersistence() {
        XCTAssertEqual(AppSettings.validatedBoostLevel(nil), 1.0)
        XCTAssertEqual(AppSettings.validatedBoostLevel(.nan), 1.0)
        XCTAssertEqual(AppSettings.validatedBoostLevel(0.05), 1.0)
        XCTAssertEqual(AppSettings.validatedBoostLevel(1.5), 1.0)
        XCTAssertEqual(AppSettings.validatedBoostLevel(0.1), 0.1)
        XCTAssertEqual(AppSettings.validatedBoostLevel(0.5), 0.5)
        let s = AppSettings.shared
        s.boostLevel = 0.25
        XCTAssertEqual(UserDefaults.standard.double(forKey: "boostLevel"), 0.25)
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

    @MainActor
    func testToolbarRepeatActionsUseCoarseThenFineStepsAndClamps() throws {
        let manager = EdgeLightManager() // Never start: no overlays or physical boost.
        let panel = ControlPanelWindow(manager: manager)
        defer { panel.cancelRepeatingAdjustments(); panel.close() }
        AppSettings.shared.isLightOn = true
        panel.updateToggleStates()
        panel.orderFront(nil)
        let controls = toolbarButtons(in: try XCTUnwrap(panel.contentView))
        let cases: [(String, ReferenceWritableKeyPath<AppSettings, Double>, Double, Double, Double, Double)] = [
            ("sun.min", \.brightness, 1, -0.15, -0.025, 0.2),
            ("sun.max", \.brightness, 1, 0.15, 0.025, 2),
            ("flame", \.colorTemperature, 0.5, 0.1, 0.015, 1),
            ("snowflake", \.colorTemperature, 0.5, -0.1, -0.015, 0),
            ("rectangle.compress.vertical", \.borderWidth, 60, -10, -2, 10),
            ("rectangle.expand.vertical", \.borderWidth, 60, 10, 2, 150)
        ]
        for (identifier, path, initial, coarse, fine, limit) in cases {
            let button = try XCTUnwrap(controls.first { $0.accessibilityIdentifier() == identifier } as? RepeatButton)
            AppSettings.shared[keyPath: path] = initial
            button.performClick(nil) // Keyboard / accessibility activation stays a single coarse action.
            XCTAssertEqual(AppSettings.shared[keyPath: path], initial + coarse, accuracy: 0.0001)
            XCTAssertNil(button.repeatTimer)
            AppSettings.shared[keyPath: path] = initial
            button.beginRepeating()
            XCTAssertEqual(AppSettings.shared[keyPath: path], initial + coarse, accuracy: 0.0001)
            let timer = try XCTUnwrap(button.repeatTimer)
            XCTAssertEqual(timer.timeInterval, 0.035, accuracy: 0.0001)
            XCTAssertEqual(timer.fireDate.timeIntervalSinceNow, 0.25, accuracy: 0.05)
            button.repeatTick()
            XCTAssertEqual(AppSettings.shared[keyPath: path], initial + coarse + fine, accuracy: 0.0001)
            AppSettings.shared[keyPath: path] = limit
            button.repeatTick()
            XCTAssertEqual(AppSettings.shared[keyPath: path], limit, accuracy: 0.0001)
            button.cancelRepeating()
            button.cancelRepeating()
            let saved = AppSettings.shared[keyPath: path]
            timer.fire() // Previously scheduled production callback after cancellation.
            button.repeatTick()
            XCTAssertEqual(AppSettings.shared[keyPath: path], saved)
        }
        XCTAssertEqual(controls.compactMap { $0 as? RepeatButton }.count, 6)
    }

    @MainActor
    func testRepeatCancellationRoutesRejectPendingTicksAndReentry() throws {
        let routes = ["release", "exit", "disable", "hide", "detach", "ancestor hide", "orderOut", "close", "autoHide"]
        for route in routes {
            let manager = EdgeLightManager()
            let panel = ControlPanelWindow(manager: manager)
            defer { panel.cancelRepeatingAdjustments(); panel.close() }
            AppSettings.shared.isLightOn = true
            AppSettings.shared.brightness = 1
            panel.updateToggleStates()
            panel.orderFront(nil)
            let button = try XCTUnwrap(toolbarButtons(in: try XCTUnwrap(panel.contentView))
                .first { $0.accessibilityIdentifier() == "sun.max" } as? RepeatButton)
            button.beginRepeating()
            let timer = try XCTUnwrap(button.repeatTimer)
            XCTAssertEqual(AppSettings.shared.brightness, 1.15, accuracy: 0.0001)
            switch route {
            case "release":
                button.cell?.stopTracking(last: .zero, current: .zero, in: button, mouseIsUp: true)
            case "exit":
                let cell = try XCTUnwrap(button.cell)
                let start = NSPoint(x: 10, y: 10)
                let middle = NSPoint(x: 15, y: 15)
                let inside = NSPoint(x: 20, y: 20)
                let outside = NSPoint(x: -1, y: -1)
                XCTAssertTrue(cell.startTracking(at: start, in: button), "Native cell must opt into drag tracking")
                XCTAssertTrue(cell.continueTracking(last: start, current: middle, in: button), "First drag must keep tracking")
                XCTAssertTrue(cell.continueTracking(last: middle, current: inside, in: button), "Second drag must keep tracking")
                XCTAssertNotNil(button.repeatTimer, "In-bounds movement must preserve the hold")
                XCTAssertTrue(cell.continueTracking(last: inside, current: outside, in: button), "Exit cancels repetition while native tracking consumes release")
                XCTAssertNil(button.repeatTimer, "Exit must cancel immediately")
                XCTAssertTrue(cell.continueTracking(last: outside, current: inside, in: button))
                button.highlight(true) // Reentry cannot restart this press.
            case "disable":
                AppSettings.shared.isLightOn = false
                panel.updateToggleStates()
            case "hide": button.isHidden = true
            case "detach": button.removeFromSuperview()
            case "ancestor hide": button.superview?.isHidden = true
            case "orderOut": panel.orderOut(nil)
            case "close": panel.close()
            default: panel.autoHide()
            }
            timer.fire()
            button.repeatTick()
            XCTAssertEqual(AppSettings.shared.brightness, 1.15, accuracy: 0.0001, route)
            XCTAssertNil(button.repeatTimer, route)
        }
    }

    @MainActor
    func testToolbarActionsHaveStableAccessibleNamesAndModeValues() throws {
        let manager = EdgeLightManager()
        let panel = ControlPanelWindow(manager: manager)
        defer { panel.close() }
        let controls = toolbarButtons(in: try XCTUnwrap(panel.contentView))
        XCTAssertEqual(controls.count, 17)
        let repeatIdentifiers: Set<String> = ["sun.min", "sun.max", "flame", "snowflake",
                                               "rectangle.compress.vertical", "rectangle.expand.vertical"]
        for button in controls {
            XCTAssertFalse((button.accessibilityLabel() ?? "").isEmpty)
            let repeats = repeatIdentifiers.contains(button.accessibilityIdentifier() ?? "")
            if repeats {
                XCTAssertEqual(button.accessibilityHelp(), "Click to adjust; hold for fine steps. Move away to stop.")
                XCTAssertTrue(button.toolTip?.contains("hold for fine steps") == true)
                XCTAssertFalse(button.accessibilityLabel()?.contains("hold") == true)
            } else {
                XCTAssertFalse(button.accessibilityHelp()?.contains("hold for fine steps") == true)
                XCTAssertFalse(button.toolTip?.contains("hold for fine steps") == true)
            }
        }
        XCTAssertEqual(controls.filter { repeatIdentifiers.contains($0.accessibilityIdentifier() ?? "") }.count, 6)
        let mode = try XCTUnwrap(controls.first { $0.accessibilityIdentifier() == "menubar.rectangle" })
        for (index, value) in ["Below", "Extend", "Auto"].enumerated() {
            AppSettings.shared.menuBarMode = index
            panel.updateToggleStates()
            XCTAssertEqual(mode.accessibilityLabel(), "Menu Bar Mode")
            XCTAssertEqual(mode.accessibilityValue() as? String, value)
        }
    }

    @MainActor
    private func toolbarButtons(in view: NSView) -> [NSButton] {
        (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { toolbarButtons(in: $0) }
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
    let boostLevel: Double
    let launchAtLogin: Bool
    let domainName: String
    let persistentDomain: [String: Any]?

    static func capture() -> SettingsSnapshot {
        let domainName = Bundle.main.bundleIdentifier!
        let persistentDomain = UserDefaults.standard.persistentDomain(forName: domainName)
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
            edrBoosted: s.edrBoosted,
            boostLevel: s.boostLevel,
            launchAtLogin: s.launchAtLogin,
            domainName: domainName,
            persistentDomain: persistentDomain
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
        s.boostLevel = boostLevel
        s.launchAtLogin = launchAtLogin
        // Setters restore the singleton; restore exact disk state last, including missing keys.
        if let persistentDomain {
            UserDefaults.standard.setPersistentDomain(persistentDomain, forName: domainName)
        } else {
            UserDefaults.standard.removePersistentDomain(forName: domainName)
        }
    }
}
