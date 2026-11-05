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
        guard let tables = DisplayBrightnessManager.readGamma(displayID: screen.displayID) else {
            throw Failure.message("Gamma readback unavailable")
        }
        return tables
    }

    static func checkRamp(on screen: NSScreen) throws {
        let expectedScale = DisplayBrightnessManager.gammaScale
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

    /// Child mode: rewrite the gamma table once a second from a separate process.
    static func runExternalWriter(seconds: Int) -> Never {
        // Behave like a competing tool: set an explicit neutral table on every display.
        let identity = DisplayBrightnessManager.buildBoostedRamp(scale: 1.0, count: 256)
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(16, &ids, &count)
        for _ in 0..<seconds {
            for id in ids.prefix(Int(count)) {
                CGSetDisplayTransferByTable(id, 256, identity, identity, identity)
            }
            Thread.sleep(forTimeInterval: 1)
        }
        exit(0)
    }

    static func waitFor(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if condition() { return true }
            pump(for: 0.25)
        }
        return condition()
    }

    static func main() {
        if let index = CommandLine.arguments.firstIndex(of: "--external-writer"),
           let seconds = CommandLine.arguments.dropFirst(index + 1).first.flatMap({ Int($0) }) {
            runExternalWriter(seconds: seconds)
        }
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

            // No run-loop turn between off and on: exercise outstanding Metal
            // work and compositor teardown from the previous activation.
            for cycle in 1...20 {
                manager.setEnabled(false)
                guard !manager.isBoosted else { throw Failure.message("Off failed in rapid cycle \(cycle)") }
                manager.setEnabled(true)
                guard manager.isBoosted else { throw Failure.message("Reactivation failed in rapid cycle \(cycle)") }
                pump(for: 0.75)
                for screen in screens { try checkRamp(on: screen) }
            }
            print("PASS: 20 immediate off/on cycles restore gamma (physical brightness not measured)")

            try resetGammaAndVerifyChange(on: screens)
            pump(for: 1.5)
            for screen in screens { try checkRamp(on: screen) }
            print("PASS: gamma repaired after external ColorSync reset")

            // Exercise the same common run-loop mode used by menu tracking.
            try resetGammaAndVerifyChange(on: screens)
            pump(for: 1.5, mode: .eventTracking)
            for screen in screens { try checkRamp(on: screen) }
            print("PASS: gamma maintenance during event tracking")

            // The in-process resets above register as external writes; wait for
            // the conflict state to clear, which also verifies recovery.
            guard waitFor(15, { !manager.hasGammaConflict }) else {
                throw Failure.message("Conflict state did not clear after in-process resets")
            }
            print("PASS: conflict state clears within 15 seconds of the last external reset")

            var minimumHeadroom = Double.infinity
            var maximumHeadroom = 1.0
            for _ in 0..<30 {
                pump(for: 1)
                guard !manager.hasGammaConflict else { throw Failure.message("False conflict during normal boost") }
                for screen in screens {
                    try checkRamp(on: screen)
                    let headroom = screen.maximumExtendedDynamicRangeColorComponentValue
                    minimumHeadroom = min(minimumHeadroom, headroom)
                    maximumHeadroom = max(maximumHeadroom, headroom)
                }
            }
            print("PASS: 30-second sustained gamma check; headroom range \(minimumHeadroom)...\(maximumHeadroom)")

            // A separate process rewrites the table every second.
            let writer = Process()
            writer.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            writer.arguments = ["--external-writer", "12"]
            try writer.run()
            defer { if writer.isRunning { writer.terminate() } }
            guard waitFor(10, { manager.hasGammaConflict }) else {
                throw Failure.message("External writer not detected within 10 seconds")
            }
            print("PASS: separate-process writer reported as conflict within 10 seconds")
            writer.waitUntilExit()
            guard waitFor(12, { !manager.hasGammaConflict }) else {
                throw Failure.message("Conflict did not clear within 12 seconds of the writer stopping")
            }
            for screen in screens { try checkRamp(on: screen) }
            print("PASS: conflict clears after the external writer stops")

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
