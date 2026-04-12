import XCTest
@testable import MacEdgeLight

final class PanicTapDetectorTests: XCTestCase {
    func testDoesNotFireBelowThreshold() {
        var d = PanicTapDetector(threshold: 5, window: 2.0)
        XCTAssertFalse(d.register(at: 0.0))
        XCTAssertFalse(d.register(at: 0.1))
        XCTAssertFalse(d.register(at: 0.2))
        XCTAssertFalse(d.register(at: 0.3))
        XCTAssertEqual(d.taps.count, 4)
    }

    func testFiresOnFifthTapInsideWindow() {
        var d = PanicTapDetector(threshold: 5, window: 2.0)
        for t in stride(from: 0.0, through: 0.4, by: 0.1) {
            let fired = d.register(at: t)
            if t < 0.4 {
                XCTAssertFalse(fired, "should not fire until the 5th tap")
            } else {
                XCTAssertTrue(fired, "should fire on the 5th tap")
            }
        }
    }

    func testResetsAfterFiring() {
        var d = PanicTapDetector(threshold: 5, window: 2.0)
        for t in 0..<5 { _ = d.register(at: TimeInterval(t) * 0.1) }
        XCTAssertEqual(d.taps.count, 0, "state should reset after firing")
    }

    func testOldTapsOutsideWindowAreDropped() {
        var d = PanicTapDetector(threshold: 5, window: 2.0)
        // 4 taps, then wait past the window, then 1 more — should NOT fire
        _ = d.register(at: 0.0)
        _ = d.register(at: 0.1)
        _ = d.register(at: 0.2)
        _ = d.register(at: 0.3)
        let fired = d.register(at: 10.0)
        XCTAssertFalse(fired, "taps outside the window should not count")
        XCTAssertEqual(d.taps.count, 1, "only the latest tap should remain")
    }

    func testExactlyAtWindowBoundaryIsKept() {
        var d = PanicTapDetector(threshold: 5, window: 2.0)
        _ = d.register(at: 0.0)
        // A tap exactly `window` seconds later — boundary case, kept
        _ = d.register(at: 2.0)
        XCTAssertEqual(d.taps.count, 2)
    }

    func testRapidFireFollowingReset() {
        var d = PanicTapDetector(threshold: 5, window: 2.0)
        // Fire once
        for t in 0..<5 { _ = d.register(at: TimeInterval(t) * 0.1) }
        // Fire again with a fresh burst
        var fired = false
        for t in 0..<5 {
            fired = d.register(at: 1.0 + TimeInterval(t) * 0.1)
        }
        XCTAssertTrue(fired, "detector should be usable after firing")
    }
}
