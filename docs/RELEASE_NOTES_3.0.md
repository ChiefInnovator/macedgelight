# MacEdgeLight 3.0.0

**Light for your calls. Brightness for your screen.**

MacEdgeLight brings an adjustable screen ring light and an independent display brightness boost to macOS. Version 3.0 focuses on keeping the brightness preference consistent through everyday interruptions, alongside the ring-light and presentation tools.

## What’s changed

- Keep the enabled boost preference through system sleep, display sleep, lock, and user-session changes.
- Continue recovery checks until the session and display are ready, including late display reconnection.
- Adapt gamma independently to each display’s available EDR headroom.
- Repair gamma resets every 0.5 seconds and check for stalled rendering.
- Stop recovery before shutdown and restore ColorSync when boost is disabled.
- Use display IDs to manage render state and prevent stale callbacks from updating replacement layers.
- Centralize lifecycle events in the production recovery-state handler.
- Use Xcode automatic signing and account-based notarization with bounded processing retries and verified exports.
- Update the website and documentation with equal emphasis on ring lighting and brightness boost, including the creator’s low-vision experience and clear compatibility guidance.

## Install and use

macOS 13 Ventura or later; Apple silicon or Intel. Download the DMG or ZIP, move MacEdgeLight to Applications, and open it.

- `Command–Shift–L`: toggle the ring light.
- `Command–Shift–B`: toggle display brightness boost.
- Enable **Launch at Login** for restoration after logout or restart.
- Five rapid unmodified `Q` taps within two seconds quit the app.

Brightness boost requires an EDR-capable display. macOS controls available headroom and thermal limits; the app cannot promise constant physical brightness or run after logout terminates it. Night Shift, True Tone, and hardware calibration are bypassed while boost is active and restored through ColorSync when it is disabled.

## Validation

The changes passed 38 unit tests, including all 24 wake/unlock event orders and 1,000 simulated sleep cycles. Live display checks verified gamma readback, ColorSync-reset repair, event-tracking maintenance, 30-second stability, and cleanup. Thread Sanitizer reported no races on the exercised live rendering paths.

These checks do not replace physical sleep/logout/reconnection testing or a longer stability run. Gamma readback is not a measurement of physical luminance.
