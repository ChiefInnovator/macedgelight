import XCTest
@testable import MacEdgeLight

final class BoostRecoveryTests: XCTestCase {
    private var ready: BoostRecoveryState {
        var state = BoostRecoveryState()
        state.isRunning = true
        state.isSessionActive = true
        state.sessionIsUsable = true
        return state
    }

    func testAllWakeAndUnlockOrderingsRecover() {
        // System wake, display wake, unlock, and session activation can arrive
        // in any order. Every partial sequence must remain suspended.
        func permutations(_ events: [BoostRecoveryState.Event]) -> [[BoostRecoveryState.Event]] {
            guard !events.isEmpty else { return [[]] }
            return events.flatMap { event in
                permutations(events.filter { $0 != event }).map { [event] + $0 }
            }
        }
        for events in permutations([.systemWake, .displayWake, .unlock, .sessionActive]) {
            var state = ready
            state.isSleeping = true
            state.isDisplaySleeping = true
            state.isScreenLocked = true
            state.isSessionActive = false
            for (index, event) in events.enumerated() {
                let now = 10.0 + Double(index) * 3
                state.handle(event, now: now)
                XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: now), "\(events)")
                XCTAssertEqual(state.shouldEnable(desired: true, available: true, now: now + 2.5),
                               index == events.count - 1, "\(events)")
            }
        }
    }

    func testRepeatedSleepCyclesDoNotRetainOldSuspension() {
        var state = ready
        for cycle in 0..<1_000 {
            let now = Double(cycle) * 10
            state.handle(.systemSleep, now: now)
            XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: now))
            state.handle(.systemWake, now: now + 1)
            XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: now + 2))
            XCTAssertFalse(state.shouldEnable(desired: true, available: false, now: now + 3))
            XCTAssertTrue(state.shouldEnable(desired: true, available: true, now: now + 4))
        }
    }

    func testEverySystemSuspensionBlocksUntilItsMatchingResume() {
        let pairs: [(BoostRecoveryState.Event, BoostRecoveryState.Event, TimeInterval)] = [
            (.systemSleep, .systemWake, 2), (.displaySleep, .displayWake, 2),
            (.lock, .unlock, 0.75), (.sessionInactive, .sessionActive, 0.75)
        ]
        for (suspend, resume, delay) in pairs {
            var state = ready
            state.handle(suspend, now: 10)
            XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 100))
            state.handle(resume, now: 100)
            XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 100 + delay - 0.01))
            XCTAssertTrue(state.shouldEnable(desired: true, available: true, now: 100 + delay))
        }
    }

    func testLaggingSessionSnapshotCannotUndoLockOrUserSwitch() {
        var state = ready
        state.isScreenLocked = true
        // Dictionary still says usable just after a lock notification.
        XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 100))
        state.isScreenLocked = false
        state.isSessionActive = false
        XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 100))
    }

    func testUnlockWaitsForLiveSessionToBecomeUsable() {
        var state = ready
        state.sessionIsUsable = false
        state.settle(after: 0.75, now: 10)
        XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 100))
        state.sessionIsUsable = true
        XCTAssertTrue(state.shouldEnable(desired: true, available: true, now: 101))
    }

    func testWakeWaitsForBothSystemAndDisplay() {
        var state = ready
        state.isSleeping = true
        state.isDisplaySleeping = true
        XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 10))
        state.isSleeping = false
        state.settle(after: 2, now: 10)
        XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 20))
        state.isDisplaySleeping = false
        state.settle(after: 2, now: 20)
        XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 21.9))
        XCTAssertTrue(state.shouldEnable(desired: true, available: true, now: 22))
    }

    func testUnlockCannotShortenWakeSettle() {
        var state = ready
        state.settle(after: 2, now: 10)
        state.settle(after: 0.75, now: 10.1)
        XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 11))
        XCTAssertTrue(state.shouldEnable(desired: true, available: true, now: 12))
    }

    func testLateUnlockDoesNotExhaustRecovery() {
        var state = ready
        state.isScreenLocked = true
        state.settle(after: 2, now: 10)
        for time in stride(from: 10.0, through: 120.0, by: 0.5) {
            XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: time))
        }
        state.isScreenLocked = false
        XCTAssertTrue(state.shouldEnable(desired: true, available: true, now: 121))
    }

    func testDisplayReturningLongAfterWakeStillRecovers() {
        var state = ready
        state.settle(after: 2, now: 10)
        XCTAssertFalse(state.shouldEnable(desired: true, available: false, now: 300))
        XCTAssertTrue(state.shouldEnable(desired: true, available: true, now: 301))
    }

    func testTurningOffWhileSuspendedCancelsRecovery() {
        var state = ready
        state.isScreenLocked = true
        state.settle(after: 0.75, now: 10)
        XCTAssertFalse(state.shouldEnable(desired: false, available: true, now: 10))
        state.isScreenLocked = false
        XCTAssertFalse(state.shouldEnable(desired: false, available: true, now: 20))
    }

    func testInactiveUserSessionCannotBoost() {
        var state = ready
        state.isSessionActive = false
        XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 100))
        state.isSessionActive = true
        state.settle(after: 0.75, now: 100)
        XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 100))
        XCTAssertTrue(state.shouldEnable(desired: true, available: true, now: 101))
    }

    func testStopAndNewSleepBlockPendingRecovery() {
        var state = ready
        state.settle(after: 2, now: 10)
        state.isSleeping = true
        XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 20))
        state.isSleeping = false
        state.isRunning = false
        XCTAssertFalse(state.shouldEnable(desired: true, available: true, now: 20))
    }
}
