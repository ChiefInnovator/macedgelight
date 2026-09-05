# MacEdgeLight 3.0 — Marketing Guide

## Positioning

**Tagline:** Light for your calls. Brightness for your screen.

**One-liner:** MacEdgeLight combines an adjustable screen ring light and a display brightness boost in one native macOS menu bar app. Use either independently, or both.

Give the two features equal prominence. Ring lighting serves calls, recordings, presentations, and personal setups. Brightness boost serves people who benefit from a brighter screen, including some people with low vision.

## Creator’s Experience

Richard Crane’s approved first-person statement:

> “I am vision impaired and this helps me see my screen.”

Attribute the quote to Richard Crane, creator of MacEdgeLight. Explain why brightness matters using this real experience. Do not invent testimonials, medical outcomes, adoption numbers, awards, or review ratings. Do not claim that greater brightness helps every person with a visual impairment.

## Claims and Boundaries

- Native Swift/AppKit, macOS 13+, Apple silicon and Intel.
- Ring light and brightness boost are independent controls.
- Boost requires an EDR-capable display as reported by macOS. The ring light does not require EDR.
- Version 3.0 preserves boost intent, continuously checks recovery eligibility, repairs gamma resets, and adjusts each display independently.
- Enable Launch at Login for restoration after logout/restart. The app does not run after logout terminates it or illuminate a sleeping display.
- macOS controls current headroom and thermal limits. Do not promise maximum brightness, fixed luminance, universal compatibility, or a measured 45% brightness increase.
- The synthetic gamma ramp bypasses Night Shift, True Tone, and hardware calibration while active. Normal ColorSync state returns on deactivation.
- Describe the source as available under PolyForm Strict 1.0.0. Do not use “open source” or suggest unrestricted modification/redistribution.
- Claim signing and notarization only after verifying the published artifacts.
- Avoid unsupported eye-strain, health, competitor-exclusivity, or physical ring-light performance claims.

## Search, Answer, and Generative Discovery

The canonical page is <https://chiefinnovator.github.io/macedgelight/>. It is deployed by GitHub Pages from `main:/docs`.

- **SEO:** descriptive title and description; one clear H1; semantic sections; canonical and language links; version-specific downloads; accessible image alternatives; social metadata; sitemap; static HTML with no JavaScript required for product information.
- **AEO:** concise, visible FAQs answer what the product does, feature differences, compatibility, sleep/login recovery, headroom, color effects, price, and shortcuts. Keep FAQ structured data identical to the visible answers.
- **GEO:** consistent product/version/developer facts across the site, README, release notes, and `llms.txt`; a real attributed creator quote; clear constraints and authoritative documentation links. `llms.txt` is a supplemental summary, not a ranking guarantee.
- Use SoftwareApplication, WebSite, and FAQPage structured data without fabricated reviews or ratings. Structured data must describe visible content. FAQ markup does not guarantee a Google rich result.
- Submit `https://chiefinnovator.github.io/macedgelight/sitemap.xml` through an authorized Google Search Console or Bing Webmaster Tools property when available. Do not claim a submission was made unless verified.
- `robots.txt` is effective at the hostname root, not the `/macedgelight/` project path. This repository does not own the hostname-root robots configuration; use page-level index/follow metadata and verify crawl access rather than publishing an ineffective project-level robots file.
- Measure release downloads and GitHub traffic. Search rankings and AI citations require recrawling and are not guaranteed.

Google states that ordinary SEO practices apply to AI Overviews and AI Mode and that there is no special AI schema or required AI text file: [AI features and your website](https://developers.google.com/search/docs/appearance/ai-features).

## Release Checklist

1. Match app, website, README, plain-text summary, schema, and release-note versions.
2. Run unit tests and the appropriate live hardware checks; distinguish tested code from physical sleep/logout testing.
3. Verify universal binary architectures, Developer ID signature, notarization, artifact integrity, and bundled version.
4. Publish GitHub release assets before the website’s download links go live.
5. Verify the Pages deployment, download links, sitemap, FAQ/schema parity, and mobile/reflow accessibility.

## Follow-up Content

Potential topics, not commitments or already-published campaigns:

- A first-person account of why Richard uses screen brightness to help see his Mac.
- A two-feature walkthrough: screen ring light for a call, brightness boost for everyday screen use.
- A practical explanation of supported displays, variable EDR headroom, and what happens after sleep.

Publishing social posts or contacting third parties requires a separate instruction; website and release work does not imply that authorization.
