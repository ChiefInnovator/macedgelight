# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS (native AppKit desktop application).

Impeccable 4.8.0 documents only `web`, `ios`, `android`, and `adaptive` as platform values. None describes this app. This record deliberately preserves the actual platform. The project-local `.agents/skills/impeccable/reference/macos.md` adds source-only desktop routing; the upstream enum/engine and native live preview still do not support AppKit. Do not substitute iOS or adaptive guidance. The separate static marketing website is web.

## Users

People using their Mac for calls, recordings, and presentations, and people who benefit from additional screen brightness or magnification. README includes creator Richard Crane's first-person experience of vision impairment. This is product context, not a clinical efficacy claim or a verified demographic study.

## Product Purpose

“Light for your calls. Brightness for your screen.” Two independent tools provide an adjustable screen ring light and brightness boost on compatible EDR displays. Success means users can operate either tool independently through the menu, floating controls, and keyboard shortcuts.

## Positioning

The implemented mechanism combines an adjustable screen-edge overlay with optional EDR signaling and a synthetic gamma ramp. No comparative superiority, measured luminance improvement, or medical benefit has been established.

## Operating Context

- macOS 13 Ventura or later, Apple silicon or Intel; Swift/AppKit, no SwiftUI or third-party runtime dependencies.
- Accessory/menu-bar application with a floating nonactivating HUD; no account or subscription is required by the documented product.
- Users can adjust ring brightness, color temperature, width, monitor selection, menu-bar coverage, cursor reveal, and capture visibility. Separate tools include magnifier and desktop-icon visibility.
- Cmd+Shift+L toggles ring light; Cmd+Shift+Up/Down adjusts ring brightness; Cmd+Shift+B toggles boost. Five rapid unmodified Q taps within two seconds panic-quit.
- Launch at Login permits restart after login. Logout terminates the application.

## Capabilities and Constraints

- Ring lighting works without EDR. Boost requires macOS-reported EDR capability and follows each display's current headroom.
- Boost preference is persisted separately from active rendering. Waiting is distinct from active boost and remains cancellable. Sleep, lock, and inactive sessions suspend rendering.
- Gamma scaling is capped at 1.55 and 90% of current headroom, with a neutral floor of 1.0. These values are not measured physical brightness gains. macOS power/thermal limits remain authoritative.
- Active boost bypasses Night Shift, True Tone, and hardware calibration through the synthetic ramp. Turning it off restores ColorSync.
- Ring overlay capture inclusion depends on macOS and the recording application. Magnifier uses screen capture; permissions and multi-display behavior require live validation.
- Double-click bulb resets ring settings while preserving independent tools; Reset to Defaults is broader. Keep these actions distinct.
- Application is intentionally not sandboxed. Distribution uses Developer ID signing, notarization, and Hardened Runtime; current signing/release state is not established by these documents.
- Source is licensed under PolyForm Strict 1.0.0; do not describe it as OSI-approved open source.
- Implemented focused repairs: documented hold-to-repeat is restored, Auto menu-bar reveal is bounded to its own display, HUD actions have explicit accessibility names, shortcut help is complete, and stale SPEC descriptions are corrected. Geometry checkpoint passed 46 tests and a Debug build; the complete interaction checkpoint passed 49 tests and a Debug build. These checks establish automated/source behavior, not real pointer tracking, VoiceOver or hardware acceptance.

## Brand Commitments

Preserve the MacEdgeLight name, existing app icon, supplied tagline, and the distinction between screen ring lighting and display brightness boost. Existing identity is documented rather than redesigned.

## Evidence on Hand

- `README.md`: product claims, compatibility, creator quotation, usage, licensing and release workflow.
- `docs/SPEC.md`: technical behavior and manual acceptance checklist, reconciled with the focused repairs.
- `MacEdgeLight/*.swift`: current native implementation; Xcode MARKETING_VERSION is release-version authority.
- `docs/design/design_draft.md` and `docs/design/consolidated_review_report.md`: focused repair design and completed fresh Goldfish review, with stage reports alongside.
- `MacEdgeLight/Assets.xcassets/AppIcon.appiconset`, `docs/images/`: existing icons and product imagery. Marketing images are not current interactive acceptance captures.
- `docs/index.html`: separate static marketing surface, not an AppKit appearance specification.

## Product Principles

- Preserve independent control of ring light and boost, including cancellation of waiting boost.
- Restore the user's normal display profile on boost deactivation and termination.
- Respect system display/session availability without discarding saved intent.
- Preserve native AppKit interaction and the existing bounded feature set.
- Separate source and automated evidence from actual hardware and assistive-technology acceptance.

## Accessibility & Inclusion

Additional brightness and the separate magnifier support the creator's stated readability needs. HUD actions require meaningful accessible names and toggle values; native menu and keyboard paths remain important. Source inspection does not establish VoiceOver quality, keyboard focus behavior, backdrop contrast, or accessibility compliance.

## Open Decisions and Evidence Limits

No formal accessibility conformance target, audience research, adoption metrics, competitive benchmark, or clinical outcome has been supplied. No new positioning, pricing, visual identity, or platform expansion is authorized by this record. Physical brightness, real sleep/logout recovery, capture behavior, and sustained operation require the SPEC's manual checks.
