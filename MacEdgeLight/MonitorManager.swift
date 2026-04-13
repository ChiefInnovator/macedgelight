import Cocoa

class MonitorManager {
    private(set) var overlayWindows: [EdgeLightOverlayWindow] = []
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    var screens: [NSScreen] {
        NSScreen.screens
    }

    var hasMultipleMonitors: Bool {
        screens.count > 1
    }

    func createOverlays() {
        removeAllOverlays()

        if settings.showOnAllMonitors {
            for screen in screens {
                let window = createOverlay(for: screen)
                overlayWindows.append(window)
                window.orderFrontRegardless()
            }
        } else {
            let index = min(settings.currentMonitorIndex, screens.count - 1)
            let validIndex = max(0, index)
            if validIndex < screens.count {
                let screen = screens[validIndex]
                let window = createOverlay(for: screen)
                overlayWindows.append(window)
                window.orderFrontRegardless()
            }
        }

        applySettingsToAll()
    }

    private func createOverlay(for screen: NSScreen) -> EdgeLightOverlayWindow {
        let window = EdgeLightOverlayWindow(for: screen)
        window.applySettings(settings)
        window.edgeLightView.snapToCurrentValues()
        return window
    }

    func removeAllOverlays() {
        for window in overlayWindows {
            window.close()
        }
        overlayWindows.removeAll()
    }

    func applySettingsToAll() {
        for window in overlayWindows {
            window.applySettings(settings)
        }
    }

    func moveToNextMonitor() {
        guard hasMultipleMonitors else { return }
        settings.showOnAllMonitors = false
        settings.currentMonitorIndex = (settings.currentMonitorIndex + 1) % screens.count
        createOverlays()
    }

    func toggleAllMonitors() {
        settings.showOnAllMonitors.toggle()
        createOverlays()
    }

    func refreshForScreenChanges() {
        // Validate current monitor index
        if settings.currentMonitorIndex >= screens.count {
            settings.currentMonitorIndex = 0
        }

        // didChangeScreenParameters also fires for gamma / color profile
        // tweaks. If the actual set of displays hasn't changed, just resize
        // existing overlays instead of tearing everything down — recreating
        // on every notification leaks NSWindows into the window server.
        let currentIDs = overlayWindows.compactMap { $0.screen?.displayID }
        let expectedIDs: [CGDirectDisplayID] = settings.showOnAllMonitors
            ? screens.map { $0.displayID }
            : {
                let idx = max(0, min(settings.currentMonitorIndex, screens.count - 1))
                return screens.indices.contains(idx) ? [screens[idx].displayID] : []
            }()

        if currentIDs == expectedIDs && !currentIDs.isEmpty {
            for window in overlayWindows {
                if let screen = window.screen {
                    window.updateForScreen(screen)
                }
            }
            return
        }

        createOverlays()
    }
}
