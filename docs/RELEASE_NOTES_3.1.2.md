# MacEdgeLight 3.1.2

Fixes a resource leak during brightness boost.

- While boost was on, each rendered frame left one macOS graphics synchronization object (`IOSurfaceSharedEvent`) unreleased. At 120 Hz this reached the system-wide limit of 65,535 in about 9 minutes, after which other apps' Metal shared events and Apple Vision accurate text recognition failed until MacEdgeLight quit or boost was turned off.
- The display-link render callback now drains an autorelease pool every frame. Shared-event counts stay flat while boost runs.

Brightness is unchanged: the 2.4 gamma maximum, Boost Strength, frame rate, ColorSync restoration, recovery timing, and the 30-second rapid-toggle waiting interval are the same as 3.1.1.
