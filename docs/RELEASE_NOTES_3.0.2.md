# MacEdgeLight 3.0.2

Consistent state indicators across the menu bar and floating controls.

- Menu toggles now show explicit ON/OFF labels and checkmarks, including ring light, all monitors, cursor reveal, magnifier, screen capture, desktop icons, controls visibility, and Launch at Login.
- Menu state refreshes after settings changes and when opening the menu, keeping toolbar actions, keyboard shortcuts, and resets synchronized.
- The status bar lightbulb reflects the ring light setting. Toolbar toggles expose state through tooltips and accessibility values.
- Light-dependent menu commands now match the toolbar's enabled state.
- Display Brightness Boost clearly distinguishes ON, OFF, unsupported, and WAITING, while queued recovery remains cancellable.
- Launch at Login reads back macOS registration state after requests and when opening the menu.
- Reset to Defaults now hides the magnifier window as well as clearing its setting.

The 30-second rapid-toggle boost recovery workaround from 3.0.1 remains unchanged. Available physical brightness still depends on the display and macOS.

Validation: 45 unit tests passed, including menu/toolbar state, external settings changes, reset state, and cancellable boost waiting. Signed and notarized release for macOS 13 or later, on Apple silicon and Intel.
