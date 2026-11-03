# Marketing materials

Every Nelson Grey game keeps its icons, brand, social, store and video material
in the same places. This file describes that layout; the same file exists in
Intercept Echo, Memory Survival and Modulo Squares.

## Layout

| Path | What belongs there |
| --- | --- |
| `marketing/README.md` | This file |
| `marketing/ASSET_MANIFEST.md` | What each asset is, its size and how to rebuild it (`ASSET_MANIFEST.csv` may sit beside it, generated, with hashes) |
| `marketing/BRAND_GUIDE.md` | Identity, palette, type and usage rules |
| `marketing/SOCIAL_COPY.md`, `ALT_TEXT.md` | Post copy and image alt text |
| `marketing/assets/identity/` | App icon, mark, wordmark, favicons, profile images |
| `marketing/assets/headers/` | Channel headers and banners (flat files, or one folder per platform) |
| `marketing/assets/social/` | Feed, story and campaign images (`campaigns/<name>/` when there are several) |
| `marketing/assets/campaign/` | Key art and contact sheets |
| `marketing/assets/store/app-store/` | App Store media: `raw/` native captures, one folder per upload size, `in-app-purchase/` |
| `marketing/assets/video/` | Gameplay tours and previews |
| `marketing/assets/source/` | Editable masters (SVG and similar). Edit these, never the exports |
| `marketing/assets/archive/` | Superseded identities and old bundles, kept as history |
| `marketing/tools/` | Scripts that build the assets. Run them from the repository root |

Optional folders: `marketing/concepts/` (design rounds) and
`marketing/validation/` (checks of the published pages).

## Related locations outside `marketing/`

| Path | What belongs there |
| --- | --- |
| `packages/mobile/assets/branding/` | Art bundled into the app itself |
| `packages/mobile/ios/fastlane/screenshots/en-US/` | The App Store upload set that fastlane sends; mirrors the matching folder under `store/app-store/` |
| `packages/mobile/ios/fastlane/metadata/` | App Store listing text |
| `packages/mobile/ios/fastlane/game_center_icons/` | Game Center achievement art (see `docs/GAME_CENTER_SETUP.md`) |
| `packages/mobile/output/` | Scratch capture and render output. Git-ignored; never the final home of an asset |

## Rules

- Finished assets, their sources and the scripts that build them are tracked in
  git. Scratch output and zip bundles are not.
- Native captures stay in `store/app-store/raw/`, unmodified. Build scripts read
  them from there.
- Do not put a game's assets in another game's repository, or a shared
  production ID or credential in any of them.
- Record where each asset came from in `docs/ASSET_PROVENANCE.md`, including
  anything AI-generated.

## This repository

- Identity is rebuilt by `marketing/tools/build_identity.py`, and the headers
  and social images by `marketing/tools/build_campaign_assets.py`.
- Native captures come from
  `packages/mobile/scripts/media/capture_app_store_screenshots.sh`, which
  writes to `assets/store/app-store/raw/`.
- `concepts/` holds the logo rounds and `validation/` the page checks.
