import XCTest
@testable import MacEdgeLight

final class SafeGammaScaleTests: XCTestCase {
    private let desired: Float = 1.55
    private let safety: Float = 0.90

    func testInvalidConfigurationCannotProduceAnUnsafeRamp() {
        for invalid: Float in [.nan, .infinity, -.infinity, -1, 0, 0.5] {
            XCTAssertEqual(DisplayBrightnessManager.safeGammaScale(
                desired: invalid, liveHeadrooms: [16], safety: safety
            ), 1)
        }
        for invalid: Float in [.nan, .infinity, -.infinity, -1, 0, 1.01] {
            XCTAssertEqual(DisplayBrightnessManager.safeGammaScale(
                desired: desired, liveHeadrooms: [16], safety: invalid
            ), 1)
        }
    }

    func testRampSafetyAcrossFallingAndRisingHeadroom() {
        // A continuous sweep catches discontinuities at the neutral floor and
        // desired ceiling, including on the way back down after a boost.
        let headrooms = (0...1600).map { Float($0) / 100 }
        for headroom in headrooms + headrooms.reversed() {
            let scale = DisplayBrightnessManager.safeGammaScale(
                desired: desired, liveHeadrooms: [headroom], safety: safety
            )
            XCTAssertGreaterThanOrEqual(scale, 1)
            XCTAssertLessThanOrEqual(scale, desired)
            XCTAssertLessThanOrEqual(scale, max(1, headroom * safety))
            let ramp = DisplayBrightnessManager.buildBoostedRamp(scale: scale, count: 256)
            XCTAssertEqual(ramp.first, 0)
            XCTAssertEqual(ramp.last, scale)
            XCTAssertTrue(zip(ramp, ramp.dropFirst()).allSatisfy { $0 <= $1 })
        }
    }

    func testInvalidHeadroomFallsBackToNeutral() {
        for headroom: Float in [.nan, .infinity, -.infinity, 0, -1] {
            XCTAssertEqual(DisplayBrightnessManager.safeGammaScale(
                desired: desired, liveHeadrooms: [headroom], safety: safety
            ), 1.0)
        }
    }

    func testReturnsNeutralWhenNoEDRScreens() {
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: desired, liveHeadrooms: [], safety: safety
        )
        XCTAssertEqual(result, 1.0, accuracy: 0.0001)
    }

    func testClampsToSafetyFractionOfHeadroom() {
        // 1.2 * 0.90 = 1.08 — below desired 1.55, should clamp to 1.08
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: desired, liveHeadrooms: [1.2], safety: safety
        )
        XCTAssertEqual(result, 1.08, accuracy: 0.0001)
    }

    func testReturnsDesiredWhenHeadroomIsAmple() {
        // 2.667 * 0.90 = 2.4003, min(1.55, 2.4003) = 1.55
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: desired, liveHeadrooms: [2.667], safety: safety
        )
        XCTAssertEqual(result, desired, accuracy: 0.0001)
    }

    func testNeverReturnsBelowNeutral() {
        // Even with very low headroom, never below 1.0 (no "inverse" gamma)
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: desired, liveHeadrooms: [1.0], safety: safety
        )
        XCTAssertEqual(result, 1.0, accuracy: 0.0001)
    }

    func testUsesMinHeadroomAcrossMultipleScreens() {
        // Two screens — 1.5 and 4.0 — should pick the worst (1.5)
        // 1.5 * 0.90 = 1.35, min(1.55, 1.35) = 1.35
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: desired, liveHeadrooms: [4.0, 1.5], safety: safety
        )
        XCTAssertEqual(result, 1.35, accuracy: 0.0001)
    }

    func testDesiredActsAsCeiling() {
        // Headroom 16x * 0.90 = 14.4 — still capped at desired 1.55
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: desired, liveHeadrooms: [16.0], safety: safety
        )
        XCTAssertEqual(result, desired, accuracy: 0.0001)
    }

    func testSafetyFractionIsHonored() {
        // Verify the 0.90 coefficient is applied, not something else
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: 10.0, liveHeadrooms: [2.0], safety: 0.90
        )
        XCTAssertEqual(result, 1.8, accuracy: 0.0001)
    }

    // MARK: - buildBoostedRamp

    func testBuildBoostedRampStartsAtZero() {
        let ramp = DisplayBrightnessManager.buildBoostedRamp(scale: 1.55, count: 256)
        XCTAssertEqual(ramp.first, 0.0)
    }

    func testBuildBoostedRampEndsAtScale() {
        let ramp = DisplayBrightnessManager.buildBoostedRamp(scale: 1.55, count: 256)
        XCTAssertEqual(ramp.last!, 1.55, accuracy: 0.0001)
    }

    func testBuildBoostedRampIdentityAtScaleOne() {
        let ramp = DisplayBrightnessManager.buildBoostedRamp(scale: 1.0, count: 256)
        XCTAssertEqual(ramp.count, 256)
        XCTAssertEqual(ramp.first, 0.0)
        XCTAssertEqual(ramp.last!, 1.0, accuracy: 0.0001)
        XCTAssertEqual(ramp[127], 127.0 / 255.0, accuracy: 0.0001)
    }

    func testBuildBoostedRampIsMonotonic() {
        let ramp = DisplayBrightnessManager.buildBoostedRamp(scale: 1.55, count: 256)
        for i in 1..<ramp.count {
            XCTAssertGreaterThan(ramp[i], ramp[i - 1])
        }
    }

    // A freshly built ramp never depends on prior LUT state — guards the
    // double-scale regression where saveAndBoostGamma read back an already
    // scaled table and multiplied again, clipping midtones to white.
    func testBuildBoostedRampIsDeterministic() {
        let a = DisplayBrightnessManager.buildBoostedRamp(scale: 1.55, count: 256)
        let b = DisplayBrightnessManager.buildBoostedRamp(scale: 1.55, count: 256)
        XCTAssertEqual(a, b)
    }

    func testBuildBoostedRampCountZero() {
        XCTAssertTrue(
            DisplayBrightnessManager.buildBoostedRamp(scale: 1.55, count: 0).isEmpty
        )
    }
}

final class BoostStrengthTests: XCTestCase {
    func testFullLevelMatchesSafeCeiling() {
        XCTAssertEqual(DisplayBrightnessManager.strengthScale(level: 1.0, safeCeiling: 1.55), 1.55, accuracy: 1e-6)
        XCTAssertEqual(DisplayBrightnessManager.strengthScale(level: 1.0, safeCeiling: 1.17), 1.17, accuracy: 1e-6)
    }

    func testRangeIsUsableOnLowHeadroom() {
        let low = DisplayBrightnessManager.strengthScale(level: 0.1, safeCeiling: 1.17)
        let mid = DisplayBrightnessManager.strengthScale(level: 0.5, safeCeiling: 1.17)
        XCTAssertEqual(low, 1.017, accuracy: 1e-5)
        XCTAssertGreaterThan(mid, low)
        XCTAssertLessThan(mid, 1.17)
    }

    func testNeverBelowNeutralOrAboveCeiling() {
        XCTAssertEqual(DisplayBrightnessManager.strengthScale(level: 1.0, safeCeiling: 1.0), 1.0)
        XCTAssertEqual(DisplayBrightnessManager.strengthScale(level: 1.0, safeCeiling: .nan), 1.0)
        XCTAssertEqual(DisplayBrightnessManager.strengthScale(level: 5.0, safeCeiling: 1.5), 1.5, accuracy: 1e-6)
        XCTAssertEqual(DisplayBrightnessManager.strengthScale(level: -1, safeCeiling: 1.5), 1.05, accuracy: 1e-6)
        XCTAssertEqual(DisplayBrightnessManager.clampedBoostLevel(.infinity), 1.0)
    }
}

final class GammaConflictTests: XCTestCase {
    func testPersistentAfterThreeMismatchesInWindowEvenIfInterleaved() {
        var t = GammaConflictTracker()
        t.record(mismatch: true, now: 0)
        t.record(mismatch: false, now: 0.5)
        t.record(mismatch: true, now: 1)
        t.record(mismatch: false, now: 1.5)
        XCTAssertFalse(t.isPersistent)
        t.record(mismatch: true, now: 2)
        XCTAssertTrue(t.isPersistent)
    }

    func testSpreadOutMismatchesNeverPersist() {
        var t = GammaConflictTracker()
        for i in 0..<5 { t.record(mismatch: true, now: Double(i) * 7) }
        XCTAssertFalse(t.isPersistent)
    }

    func testClearsOnlyAfterTenQuietSeconds() {
        var t = GammaConflictTracker()
        for i in 0..<3 { t.record(mismatch: true, now: Double(i)) }
        t.record(mismatch: false, now: 11.9)
        XCTAssertTrue(t.isPersistent)
        t.record(mismatch: false, now: 12.0)
        XCTAssertFalse(t.isPersistent)
    }

    func testDiffersUsesToleranceAndInterpolatesCounts() {
        let expected: [Float] = [0, 0.5, 1]
        XCTAssertFalse(GammaConflictTracker.differs(expected: expected, live: [expected, expected, expected]))
        XCTAssertFalse(GammaConflictTracker.differs(expected: expected, live: [[0, 0.501, 1], expected, expected]))
        XCTAssertTrue(GammaConflictTracker.differs(expected: expected, live: [expected, expected, [0, 0.51, 1]]))
        // Different live sample counts are compared by interpolation.
        XCTAssertFalse(GammaConflictTracker.differs(expected: expected, live: [[0, 1], [0, 1], [0, 1]]))
        XCTAssertTrue(GammaConflictTracker.differs(expected: expected, live: [[0, 0.8], [0, 1], [0, 1]]))
        let fine = (0..<1024).map { Float($0) / 1023 }
        XCTAssertFalse(GammaConflictTracker.differs(expected: (0..<256).map { Float($0) / 255 }, live: [fine, fine, fine]))
    }

    func testStatusPrecedence() {
        XCTAssertEqual(BoostStatus.resolve(waitingMessage: nil, conflict: false), .normal)
        XCTAssertEqual(BoostStatus.resolve(waitingMessage: nil, conflict: true), .conflict)
        XCTAssertEqual(BoostStatus.resolve(waitingMessage: "w", conflict: true), .waiting("w"))
    }
}

final class BoostStrengthMenuTests: XCTestCase {
    func testLevelsAndTitles() {
        XCTAssertEqual(StatusBarController.boostLevels, [0.1, 0.25, 0.5, 0.75, 1.0])
        XCTAssertEqual(StatusBarController.boostLevels.map(StatusBarController.boostLevelTitle),
                       ["10%", "25%", "50%", "75%", "100%"])
    }

    func testSelectionFollowsCurrentLevel() {
        let selected = StatusBarController.boostLevels.filter {
            StatusBarController.isSelectedBoostLevel($0, current: 0.5)
        }
        XCTAssertEqual(selected, [0.5])
        XCTAssertTrue(StatusBarController.boostLevels.allSatisfy {
            !StatusBarController.isSelectedBoostLevel($0, current: 0.33)
        })
    }

    func testEnablementMirrorsBoostToggle() {
        XCTAssertTrue(StatusBarController.boostStrengthEnabled(supported: true, desired: false))
        XCTAssertTrue(StatusBarController.boostStrengthEnabled(supported: false, desired: true))
        XCTAssertFalse(StatusBarController.boostStrengthEnabled(supported: false, desired: false))
    }
}
