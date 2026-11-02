---
name: MacEdgeLight
description: Source-derived native AppKit HUD, menu, and magnifier; separate website tokens are explicitly scoped.
colors:
  native-icon: "#ffffff"
  native-icon-disabled: "rgba(255,255,255,0.4)"
  native-hud-rest: "rgba(10%,10%,10%,0.95)"
  native-hud-overlap-ink: "rgb(5%,5%,5%)"
  native-divider: "rgba(255,255,255,0.3)"
  native-grip: "rgba(255,255,255,0.35)"
  native-tooltip: "rgba(0,0,0,0.85)"
  native-loupe-empty: "rgba(10%,10%,10%,0.9)"
  native-loupe-outline: "rgba(255,255,255,0.5)"
  native-loupe-crosshair: "rgba(255,255,255,0.7)"
  site-bg: "#101419"
  site-surface: "#191f27"
  site-raised: "#202936"
  site-text: "#f5f7fa"
  site-muted: "#c0cad7"
  site-blue: "#a4d9ff"
  site-gold: "#ffd58e"
  site-line: "#48576b"
  site-focus: "#ffe39e"
typography:
  native-tooltip:
    fontFamily: "system-ui"
    fontSize: "11pt"
  site-body:
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
    fontSize: "1.125rem"
    lineHeight: 1.65
rounded:
  native-panel: "12pt"
  site-card: "1rem"
  site-button: ".55rem"
spacing:
  native-control-gap: "4pt"
  native-panel-horizontal: "8pt"
  native-panel-vertical: "4pt"
components:
  native-hud:
    backgroundColor: "{colors.native-hud-rest}"
    rounded: "{rounded.native-panel}"
    padding: "4pt 8pt"
    height: "52pt"
  native-icon-button:
    textColor: "{colors.native-icon}"
    width: "44pt"
    height: "44pt"
  native-icon-button-disabled:
    textColor: "{colors.native-icon-disabled}"
    width: "44pt"
    height: "44pt"
  native-tooltip:
    backgroundColor: "{colors.native-tooltip}"
    textColor: "{colors.native-icon}"
    typography: "{typography.native-tooltip}"
  native-magnifier:
    rounded: "{rounded.native-panel}"
    height: "280pt"
---

# Design System: MacEdgeLight

## Overview

**Creative North Star: "Native floating light controls"**

This is a descriptive name for the existing implementation, not a newly selected visual direction. Compact SF Symbol controls sit in a dark AppKit HUD over the user's desktop. Native menu conventions and a separate click-through magnifier support short, direct tasks while the ring light occupies the display edge.

Recorded from Swift and the static website on 2026-11-02 and reconciled after the accepted focused repairs; palette, material and geometry remain unchanged. The attempted baseline capture did not expose the saved-hidden controls: accessibility inspection saw the capture-excluded overlay and the screenshot was white. There is no usable rendered HUD, contrast, or VoiceOver acceptance evidence. Source-derived values describe implementation, not measured appearance.

**Key Characteristics:**
- Native AppKit material and system-managed menu appearance.
- Compact icon controls with separate ring-dependent and independent groups.
- State conveyed through symbols, enabled state, tooltips, labels, and values.
- A separate website palette that does not redefine native controls.

## Colors

### Primary

Native controls use the white icon token, with filled or alternative SF Symbols for toggle state. There is no extracted chromatic AppKit action accent. Ring-light temperature is user-controlled output, not an interface accent palette.

The website uses `site-blue` for links/ring-light emphasis and `site-gold` for downloads/boost emphasis. These roles belong only to `docs/index.html`.

### Neutral

The native tokens transcribe `NSColor` components from `ControlPanelWindow.swift` and `MagnifierWindow.swift`; percentage gray avoids rounding the source's fractional white values. HUD rest, grip, divider, tooltip, loupe outline, and crosshair have distinct opacity roles. Disabled buttons use the dim icon token and are disabled behaviorally as well.

The HUD also uses active `.hudWindow` material with `.behindWindow` blending. While the ring is on, `updateBackgroundForGlow` replaces the rest-layer fill with the overlap-ink token at an alpha calculated from border width and brightness, capped at 0.85 and permitted to reach zero. This layer is only part of the material composition; do not infer contrast from its alpha alone. Preserve that formula pending rendered assessment.

Website background/surface/raised/text/muted/line/focus tokens are scoped by their `site-` prefix. `site-raised` is declared in the page's root palette; do not infer a native raised-surface role.

## Typography

The HUD is icon-led, using `NSImage(systemSymbolName:)` and native proportional scaling. It does not set a custom display face or a separate label hierarchy. Tooltip type comes from `NSFont.systemFont(ofSize:)`; the frontmatter's `system-ui` is a portable semantic representation, not a web-font dependency. Native `NSMenu` typography remains AppKit-managed.

Local macOS routing lives in `.agents/skills/impeccable/reference/macos.md`; upstream platform dispatch and browser previews do not validate AppKit.

Website body type is the extracted system stack. Its headings use a separate web hierarchy and fluid sizing; do not apply website rem sizes, heading weights, or tracking to native controls.

## Layout

The native panel fits one horizontal stack: ring-dependent brightness, warmth, width, display, menu-bar, cursor-reveal and capture controls; then a divider; then bulb, boost, magnifier, desktop icons, reset and hide. A drag grip follows. Button dimensions, stack spacing, panel padding and height are the frontmatter's native tokens, measured in AppKit points. Divider is 1 pt wide and 24 pt high; grip is 16 pt wide. Preserve order and grouping.

The existing window is sized to content and has no responsive wrapping or narrow-screen redesign. The focused repairs do not change this. Window positioning belongs to the manager; the magnifier follows the cursor, preserves screen aspect ratio, and constrains its origin to the current display.

Website layout is independently responsive: a 72 rem maximum container, desktop columns, and 850/560 px media queries in `docs/index.html`. Those are not native display breakpoints.

## Elevation & Depth

AppKit supplies real window shadows for HUD, tooltip and magnifier; no numeric CSS shadow is a native source token. The HUD sits at `mainMenu + 2`, tooltips one level above it, and magnifier at `mainMenu + 3`. Overlay levels depend on menu-bar mode. Preserve this layering so controls remain reachable above the ring.

HUD material, layer alpha and native shadows compose against the desktop. Website depth comes from its own surface tones and borders. Do not replace native material with an invented website shadow or flatten a click-through overlay into a normal window.

## Shapes

HUD and loupe share the native panel radius. HUD clipping is enabled. The loupe clips the captured image inside a rounded path, with a 2 pt outline and small central crosshair. HUD buttons are borderless `.accessoryBarAction` controls with SF Symbols, not custom rounded cards. The two-column dot grip communicates dragging.

Website cards and download buttons use their separately named radius tokens. Ring-light curves and animated borders are rendered output, not button shapes.

## Components

### HUD adjustment buttons

Six `RepeatButton` icon buttons adjust brightness, warmth, and border thickness. The implemented interaction sends one existing coarse action on press, then fine actions after 250 ms and every 35 ms. Exit permanently cancels until a new press; release, disable, hiding, auto-hide, order-out and close cancel through the production lifecycle. AppKit cell tracking remains native, with a common-mode timer for fine steps. Keyboard/accessibility activation remains a single action. The complete interaction checkpoint passed 49 tests and a Debug build; actual mouseDown tracking remains a live acceptance requirement.

### HUD toggles and actions

Keep existing SF Symbol vocabulary, white/dim state, tooltips and dynamic values. Filled/alternate symbols convey toggles; menu-bar coverage cycles Below/Extend/Auto. Ring-dependent controls disable when the ring is off. Independent tools remain usable, including switching off a waiting boost preference. Waiting uses an hourglass and explanatory state rather than claiming active rendering. Explicit action labels and a stable menu-mode label are implemented and covered by source/automated checks.

### Panel interaction and tooltip

The panel is nonactivating, draggable by its grip, and joins Spaces. Baseline opacity starts at 0.6, rises to 1 on hover, returns to 0.6 on exit, and fades to 0.01 after the 3-second idle delay. Tooltip presentation follows a 0.5-second delay. These are source behaviors, not contrast recommendations. Motion timings live in the sidecar; source is authoritative for lifecycle details.

### Native status menu

Use `NSStatusItem` with a template bulb icon and `NSMenu` separators, checkmarks, enabled states and ON/OFF text. Menu appearance follows macOS; no fixed menu palette is extracted. Shortcut help now includes boost and the five-tap panic quit alongside ring-light shortcuts. A full menu replacement is outside this work.

### Magnifier

A separate nonactivating, mouse-ignoring panel shows captured content at 2×, follows at 30 Hz, and sits above the HUD. Its frame height comes from the native token; width follows the current screen's aspect ratio. No fabricated sample content is evidence of a working capture.

### Website components

`docs/index.html` owns navigation, download links, two feature pillars, quotation, feature grid, installation content and FAQ disclosures. Its links have focus outlines and the stylesheet includes reduced-motion and forced-colors handling. This extraction does not certify browser accessibility or authorize marketing changes.

## Do's and Don'ts

### Do:
- Do preserve AppKit, SF Symbols, the HUD dimensions, native window levels, and the two control groups.
- Do distinguish saved boost intent, waiting, active rendering, and unsupported availability.
- Do retain native menu and keyboard paths alongside the icon HUD.
- Do verify contrast, pointer tracking, focus and VoiceOver on the rendered native app before claiming acceptance.

### Don't:
- Don't apply website colors, web typography, or mobile platform guidance to native AppKit controls.
- Don't change HUD opacity or introduce a new palette from source-only contrast speculation.
- Don't describe automated checks, illustrative previews, or marketing imagery as verified live native behavior.
- Don't change gamma, recovery, capture or other display-pipeline behavior as a visual refinement.
