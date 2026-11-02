# MacEdgeLight 3.0.4

Fine adjustment and native control fixes.

- Restores hold-to-repeat for ring-light brightness, warmth, and border width: one coarse step on press, then fine steps after a 250 ms hold at 35 ms intervals.
- Stops repeating on release, pointer exit, disable, hide, or close. Moving back over a button does not resume the cancelled press.
- Fixes Auto menu-bar reveal reacting to a cursor on a vertically stacked display above its own screen.
- Adds explicit accessible names, menu-bar mode values, and click/hold/exit help for adjustment controls.
- Completes shortcut help with Cmd+Shift+B for display brightness boost and the five unmodified Q taps within two seconds for panic quit.
- Preserves original preference values and missing-key state in the expanded regression tests.

Ring lighting, magnifier, desktop controls, and display brightness boost remain independent. Display boost gamma tuning, ColorSync restoration, recovery timing, and the 30-second rapid-toggle waiting interval are unchanged.

Requires macOS 13 or later on Apple silicon or Intel. Brightness boost additionally requires an EDR-capable display. No constant physical luminance is promised.

Validation: 49 unit tests and the debug build passed for these fixes. Native physical mouse tracking, VoiceOver, desktop contrast, physical luminance, and real sleep/logout behavior were not re-tested for this release.
