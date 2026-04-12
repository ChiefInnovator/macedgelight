import XCTest
@testable import MacEdgeLight

final class SafeGammaScaleTests: XCTestCase {
    private let desired: Float = 1.45
    private let safety: Float = 0.85

    func testReturnsNeutralWhenNoEDRScreens() {
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: desired, liveHeadrooms: [], safety: safety
        )
        XCTAssertEqual(result, 1.0, accuracy: 0.0001)
    }

    func testClampsToSafetyFractionOfHeadroom() {
        // 1.2 * 0.85 = 1.02 — below desired 1.45, should clamp to 1.02
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: desired, liveHeadrooms: [1.2], safety: safety
        )
        XCTAssertEqual(result, 1.02, accuracy: 0.0001)
    }

    func testReturnsDesiredWhenHeadroomIsAmple() {
        // 2.667 * 0.85 = 2.267, min(1.45, 2.267) = 1.45
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
        // 1.5 * 0.85 = 1.275, min(1.45, 1.275) = 1.275
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: desired, liveHeadrooms: [4.0, 1.5], safety: safety
        )
        XCTAssertEqual(result, 1.275, accuracy: 0.0001)
    }

    func testDesiredActsAsCeiling() {
        // Headroom 16x * 0.85 = 13.6 — still capped at desired 1.45
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: desired, liveHeadrooms: [16.0], safety: safety
        )
        XCTAssertEqual(result, desired, accuracy: 0.0001)
    }

    func testSafetyFractionIsHonored() {
        // Verify the 0.85 coefficient is applied, not something else
        let result = DisplayBrightnessManager.safeGammaScale(
            desired: 10.0, liveHeadrooms: [2.0], safety: 0.85
        )
        XCTAssertEqual(result, 1.7, accuracy: 0.0001)
    }
}
