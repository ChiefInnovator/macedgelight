# MacEdgeLight 3.0.1

A recovery workaround for rapid Display Brightness Boost toggles.

- Turning boost off restores ColorSync immediately.
- Turning it back on within 30 seconds queues automatic recovery until that off interval ends.
- The menu shows Waiting; the toolbar shows an hourglass with a countdown tooltip.
- Turning off a queued request cancels recovery without extending the interval.
- Initial activation remains immediate. Sleep, lock, and session checks still apply.

The 30-second interval is based on reported hardware behavior, not an Apple timing guarantee. It does not establish the underlying cause or guarantee a fixed physical brightness.

Validation: 42 unit tests passed, covering the deadline, cancellation, repeated toggles, and lock recovery. The live harness also passed 20 immediate renderer off/on cycles and gamma readback checks; those readings do not measure physical screen brightness. The queued recovery behavior still needs confirmation on the affected display.
