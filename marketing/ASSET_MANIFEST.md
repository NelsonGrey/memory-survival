# Asset Manifest

**Identity:** S2 “Shrinking Safe Corridor” (selected 2026-10-05; see `concepts/logo-round-4-survival/s2-shrinking-corridor.png` for the AI-generated reference it was reconstructed from).
**Rebuild everything:** `python3 tools/build_identity.py --font "Sora[wght].ttf" --out assets` (needs `fonttools`, `rsvg-convert`). All SVG masters and PNG exports below are produced by that script.

## Vector masters (`assets/source/`) — edit these, never the PNGs

| File | Purpose |
| --- | --- |
| `s2-mark.svg` | Mark on a rounded tile with transparent corners (web, wordmark, social, favicons) |
| `s2-app-icon.svg` | Full-bleed square icon; iOS and Google Play apply their own masks |
| `s2-app-icon-foreground.svg` | Transparent artwork for the Android adaptive-icon foreground layer |
| `s2-wordmark-horizontal.svg` | Mark + MEMORY / SURVIVAL, 1200 × 300 |
| `s2-wordmark-stacked.svg` | Mark over stacked wordmark |
| `s2-wordtype-stacked.svg` | Stacked type alone, for use without the mark |
| `s2-social-*.svg` | One editable card per social format (below) |

Type is converted to outlines from Sora Bold/SemiBold/Regular, so no SVG needs the font installed. `tools/Sora-OFL.txt` carries the licence.

## Identity exports (`assets/identity/`)

- `mark.svg`, `mark.png` (512 × 512, transparent corners)
- `wordmark.svg`, `wordmark.png` (1200 × 300, transparent), `wordmark-stacked.svg`
- `app-icon-1024.png`, `app-icon-512.png` — opaque, RGB, full-bleed square (no alpha channel)
- `apple-touch-icon.png` — 180 × 180, opaque
- `favicon-32x32.png`, `favicon-16x16.png` — from the rounded mark
- `s2-contact-sheet.png` — the icon at 1024 / 128 / 64 / 32 / 16 px, on dark and light

## Social exports (`assets/social/`) — vector layouts, no raster artwork

- `og-image.png` 1200 × 630 · `x-landscape.png` 1600 × 900 · `instagram-square.png` 1080 × 1080
- `story.png` 1080 × 1920 · `linkedin-banner.png` 1128 × 191 · `youtube-banner.png` 2560 × 1440 (content kept inside the 1546 × 423 safe area)

Headline “Every gap is a risk.”, supporting line “A real-time memory allocation puzzle.”, status label “IN DEVELOPMENT”. Text is set from outlined Sora paths, not rendered by an image model.

## Native app integration (`packages/mobile`)

- iOS: every size in `ios/Runner/Assets.xcassets/AppIcon.appiconset` rendered directly from `s2-app-icon.svg` (RGB, no alpha).
- Android: legacy `mipmap-*/ic_launcher.png` from `s2-mark.svg`; adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`, `mipmap-*/ic_launcher_foreground.png` from `s2-app-icon-foreground.svg`, background colour `#10151C` in `values/ic_launcher_background.xml`).

## Archived and design history (kept, not deleted)

- `assets/archive/pre-s2/` — the previous working identity, sources and social exports.
- `concepts/logo-round-2`, `-3-d`, `-4-survival` — concept rounds, including the S2 reference image.
- `assets/campaign/key-art-master.png` — AI-generated key art, **no longer used by any social export**; the website hero and “Emergency procedure” section still show it.

## Provenance

Mark, wordmark, icon and social layouts are original vector constructions. The only AI-generated imagery remaining in the repository is the S2 concept reference, the other concept rounds, and `key-art-master.png`. See `docs/ASSET_PROVENANCE.md`. The title “Memory Survival” still requires formal clearance.

Press copies: `press/BRAND_GUIDE.md`, `press/SOCIAL_COPY.md`.
