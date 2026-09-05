import Cocoa

// Standalone harness: compiles the production manager without starting the
// normal app, registering hotkeys, or reading/writing its saved preferences.
@main
enum BoostHardwareCheck {
    static func pump(for duration: TimeInterval, mode: RunLoop.Mode = .default) {
        let deadline = ProcessInfo.processInfo.systemUptime + duration
        while ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.main.run(mode: mode, before: Date(timeIntervalSinceNow: 0.05))
        }
    }

    static func gamma(for screen: NSScreen) throws -> [[Float]] {
        let capacity = CGDisplayGammaTableCapacity(screen.displayID)
        guard capacity > 1 else { throw Failure.message("Gamma readback unavailable") }
        var red = [Float](repeating: 0, count: Int(capacity))
        var green = red
        var blue = red
        var count: UInt32 = 0
        let result = CGGetDisplayTransferByTable(screen.displayID, capacity, &red, &green, &blue, &count)
        guard result == .success, count > 1 else {
            throw Failure.message("Gamma readback failed: \(result.rawValue)")
        }
        return [Array(red.prefix(Int(count))), Array(green.prefix(Int(count))), Array(blue.prefix(Int(count)))]
    }

    static func checkRamp(on screen: NSScreen) throws {
        let expectedScale = DisplayBrightnessManager.safeGammaScale(
            desired: 1.45,
            liveHeadrooms: [Float(screen.maximumExtendedDynamicRangeColorComponentValue)],
            safety: 0.85
        )
        for channel in try gamma(for: screen) {
            let expected = DisplayBrightnessManager.buildBoostedRamp(scale: expectedScale, count: channel.count)
            let error = zip(channel, expected).map { abs($0 - $1) }.max() ?? .infinity
            guard error.isFinite, error < 0.002 else {
                throw Failure.message("\(screen.localizedName): gamma differs from expected scale \(expectedScale), max error \(error)")
            }
        }
    }

    enum Failure: Error {
        case message(String)
    }

    static func resetGammaAndVerifyChange(on screens: [NSScreen]) throws {
        let boosted = try screens.map { try gamma(for: $0) }
        DisplayBrightnessManager.resetGammaToProfile()
        let reset = try screens.map { try gamma(for: $0) }
        guard zip(boosted, reset).contains(where: { $0 != $1 }) else {
            throw Failure.message("ColorSync reset did not change the LUT; repair test is inconclusive")
        }
    }

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let manager = DisplayBrightnessManager.shared
        // Handle ordinary cancellation on the main thread, where AppKit and
        // gamma teardown belong. SIGKILL cannot be handled by any process.
        let cancellationSignals = [SIGINT, SIGTERM].map { signalNumber in
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler {
                manager.restore()
                exit(128 + signalNumber)
            }
            source.resume()
            return source
        }
        defer { cancellationSignals.forEach { $0.cancel() } }
        guard manager.isAvailable else {
            print("SKIP: no EDR-capable display/Metal device")
            exit(77)
        }
        let screens = NSScreen.screens.filter { $0.maximumPotentialExtendedDynamicRangeColorComponentValue > 1 }
        var failure: Error?
        do {
            // Verify readback support before changing the display.
            for screen in screens { _ = try gamma(for: screen) }
            manager.setEnabled(true)
            defer { manager.restore() }
            guard manager.isBoosted else { throw Failure.message("Activation failed") }
            pump(for: 3)
            for screen in screens { try checkRamp(on: screen) }
            print("PASS: activation and gamma readback")

            try resetGammaAndVerifyChange(on: screens)
            pump(for: 1.5)
            for screen in screens { try checkRamp(on: screen) }
            print("PASS: gamma repaired after external ColorSync reset")

            // Exercise the same common run-loop mode used by menu tracking.
            try resetGammaAndVerifyChange(on: screens)
            pump(for: 1.5, mode: .eventTracking)
            for screen in screens { try checkRamp(on: screen) }
            print("PASS: gamma maintenance during event tracking")

            var minimumHeadroom = Double.infinity
            var maximumHeadroom = 1.0
            for _ in 0..<30 {
                pump(for: 1)
                for screen in screens {
                    try checkRamp(on: screen)
                    let headroom = screen.maximumExtendedDynamicRangeColorComponentValue
                    minimumHeadroom = min(minimumHeadroom, headroom)
                    maximumHeadroom = max(maximumHeadroom, headroom)
                }
            }
            print("PASS: 30-second sustained gamma check; headroom range \(minimumHeadroom)...\(maximumHeadroom)")

            manager.setEnabled(false)
            let restored = try screens.map { try gamma(for: $0) }
            pump(for: 2)
            guard !manager.isBoosted else { throw Failure.message("Boost reactivated after off") }
            for (screen, baseline) in zip(screens, restored) {
                let current = try gamma(for: screen)
                guard current == baseline else { throw Failure.message("Gamma changed after shutdown") }
            }
            print("PASS: shutdown leaves gamma restored without late writes")
        } catch {
            failure = error
        }
        manager.restore()
        if let failure {
            print("FAIL: \(failure)")
            exit(1)
        }
    }
}
