# MacEdgeLight 3.0.3

A modest increase to display brightness boost on compatible EDR displays.

- Raises the maximum linear gamma scale from 1.45 to 1.55.
- Allows gamma scaling up to 90% of each display’s current EDR headroom, previously 85%, while retaining the neutral floor of 1.0.
- Updates gamma clamp tests, the hardware readback harness, and documentation to match the new tuning.

The available boost depends on each display and macOS conditions. Gamma-scale values are not measured percentage increases in physical brightness. The smaller headroom margin may allow more boost when headroom is limited, but cannot prevent every transient clipping event. Turning boost off restores the display’s ColorSync profile.

Persistent recovery, the 30-second rapid-toggle waiting interval, and independent ring-light controls remain unchanged.

Requires macOS 13 or later, on Apple silicon or Intel. Brightness boost additionally requires an EDR-capable display.

Validation: all 45 unit tests and the debug build passed. Site version consistency checks passed. Physical luminance and real sleep/logout behavior were not re-tested for this release.
