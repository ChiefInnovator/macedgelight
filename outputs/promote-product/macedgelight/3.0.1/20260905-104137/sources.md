# Sources and provenance

Checked September 5, 2026.

- [Public 3.0.1 release](https://github.com/ChiefInnovator/macedgelight/releases/tag/v3.0.1): verified with GitHub CLI; source for recovery deadline, cancellation, initial activation and limitations. Local mirror: docs/RELEASE_NOTES_3.0.1.md.
- [Previous 3.0.0 release](https://github.com/ChiefInnovator/macedgelight/releases/tag/v3.0.0): comparison baseline. Local docs/RELEASE_NOTES_3.0.md. Ring light, independent boost and lifecycle persistence predate the patch. The new patch adds the rapid-toggle recovery workaround, not a new brightness engine.
- [README](https://github.com/ChiefInnovator/macedgelight/blob/main/README.md) and local AGENTS.md: ring light adjustments, EDR compatibility, native macOS support and independent controls.
- [Marketing/download destination](https://chiefinnovator.github.io/macedgelight/): live cache-busted GET returned HTTP 200 and contained 3.0.1. Site source docs/index.html. No App Store listing is claimed.
- Local LICENSE: PolyForm Strict 1.0.0. No claim of OSI open source or unrestricted free commercial use.
- Creator quote: Richard Crane's supplied conversation statement, “I am vision impaired and this helps me see my screen.” Used exactly and attributed; no third-party testimonial or measured outcome implied.

## Image provenance and design

- assets/product-photo.jpg is copied from docs/images/og-card.jpg, the existing product marketing photograph. Only aspect-preserving resize is used. It illustrates ring light on multiple displays, not an EDR luminance measurement.
- assets/brand.png is the supplied Inventing Fire with AI logo from the sibling inventingfirewithai_skills/assets/branding/primary square for white bg.png. The verified lockup appears on the contact sheet; slides use a consistent typographic brand treatment.
- assets/app-icon.png is copied from docs/images/app-icon.png and retained for editing; it is not used in this layout.
- Dark navy, warm gold and pale blue are campaign design choices, not an assertion of a formal brand style guide. Typography is system Arial. No fabricated UI, generated product screenshot or AI image was used. Recovery cards are a conceptual sequence.

## Instagram specification check

Intended eventual route: six-image Instagram carousel, using conservative API-compatible JPEG exports. No account selected or authenticated; no publication authorized.

[Meta-owned Instagram API Postman documentation](https://www.postman.com/meta/instagram/documentation/6yqw8pt/instagram-api?entity=request-23987686-ab559ffb-8e2c-4b0a-b43a-5737b6d2f672): indexed official content confirmed JPEG only and up to 10 carousel children; all images share the first image's crop. The rendered page returned a different section, so the indexed excerpt is the evidence for those two constraints.

[Meta media reference](https://developers.facebook.com/docs/instagram-platform/instagram-graph-api/reference/ig-user/media/): attempted current primary-source validation, but HTTP 429 prevented full dimension, aspect-ratio and file-size confirmation. Do not treat that portion as verified. Recheck before upload. Local design target is 1080 × 1350 (4:5), sRGB JPEG, less than 8 MB each, six slides. No credentials or account identifiers were used.
