# Store setup checklist — Memory Survival

Neither Google Play nor Apple provide a public API to create a brand-new
app listing, so this part is manual. Everything else (bundle IDs, CI) is
already wired up to match these values. This project has no backend project
to link — sign-in, leaderboards, and achievements go through Game Center
(iOS) and Play Games Services (Android) directly.

## Legal/support URLs

Memory Survival has no marketing site of its own. Its Privacy/Terms/Support
pages live on the Nelson Grey site, under `games/memory-survival/` in the
`nelson-grey` repo:

- Privacy: <https://nelsongrey.com/games/memory-survival/privacy>
- Terms: <https://nelsongrey.com/games/memory-survival/terms>
- Support: <https://nelsongrey.com/games/memory-survival/support>

These pages are live (checked 2026-11-13). Use them for App Store Connect's
Privacy Policy URL and Support URL, and Play Console's Privacy Policy URL.

The privacy policy currently says Game Center stores a copy of campaign
progress in saved games. The app does not call `saveCloudProgress` /
`loadCloudProgress`; progress is on-device only, and the in-app Game Center
copy does not promise cross-device sync. Before submission, update that
policy in the `nelson-grey` repo so it matches the app, or ship saved-game
sync. This repo does not carry the legal text.

## Apple App Store Connect

0. **iPhone only.** The Xcode project targets iPhone (`TARGETED_DEVICE_FAMILY = 1`),
   so App Store Connect asks for iPhone screenshots only.
1. Developer portal → Identifiers → bundle ID `com.memorysurvival.app.ios`. **Registered.** ASC preflight on 2026-11-09 found the app record, version 1.0 in Prepare for Submission, and build 4 valid and attached. A code change after that build needs a new upload.
2. App Store Connect → Apps → **+** → New App
   - Platform: iOS
   - Name: Memory Survival (check availability; store name is portfolio-wide unique)
   - Primary language: English (U.S.)
   - Bundle ID: `com.memorysurvival.app.ios`
   - SKU: `memory-survival-ios`
   - App Privacy → Privacy Policy URL: see Legal/support URLs above
   - App Information → Support URL: see Legal/support URLs above
3. App Store Connect → In-App Purchases → **+** → Non-Consumable (matches
   Modulo Squares' ad-removal product)
   - Reference name: Remove Ads
   - Display name (shown to players): Unlock Premium (matches Modulo Squares)
   - Description: Remove all ads forever with one simple purchase
   - Promotional image: `marketing/assets/store/app-store/in-app-purchase/remove-ads-1024x1024.png`
     (1024×1024, opaque RGB; built by `marketing/tools/build_campaign_assets.py`)
   - Review screenshot: the Settings purchase section, e.g.
     `marketing/assets/store/app-store/raw/04-settings.png`
   - Product ID: `memory_survival_remove_ads` (must match `adRemovalProductId`
     in `lib/app/app_services.dart`)
   - Price: Tier 3 ($2.99)
   - Validate on a real device in a TestFlight build: tapping "Remove Ads —
     $2.99" in Settings shows the StoreKit purchase sheet at the right price.
4. AdMob console → app `com.memorysurvival.app.ios` with a banner
   (`memory-survival-admob-banner-ios`) and an interstitial unit
   (`memory-survival-admob-interstitial-ios`). **Created.** The IDs are in
   `_memorySurvivalAdMobConfig` in `lib/app/app_services.dart`, and the app ID
   is also `GADApplicationIdentifier` in `ios/Runner/Info.plist`; the two
   must match. **Never reuse another game's production IDs.**
   - `AdMobConfig.test()` is still available for development.
   - **UMP consent message**: configure a GDPR/consent message for this
     AdMob app in AdMob → Privacy & messaging — the code already calls
     Google's UMP SDK before ads load, but the form has nothing to show
     until a message is defined there.
   - **app-ads.txt**: a single shared file at the domain root
     (`https://nelsongrey.com/app-ads.txt`) in the `nelson-grey` repo. Games
     under `/games/` must not add their own; add a line there only for a new
     publisher ID or ad network.
   - Android stays on Google's shared test IDs until an Android AdMob app
     exists (`android/app/src/main/AndroidManifest.xml`).
5. App Store Connect → Features → Game Center → app `com.memorysurvival.app.ios`
   — enable Game Center and create the leaderboard and achievements. The
   exact IDs, names, descriptions, points, art and device checklist are in
   [GAME_CENTER_SETUP.md](GAME_CENTER_SETUP.md); the code references them by
   ID, nothing is auto-created.

## Google Play Console

1. Play Console → Create app
   - App name: Memory Survival
   - Package name: `com.memorysurvival.app.android` (must match exactly, permanent)
   - Default language, Free/Paid per BUSINESS_REQUIREMENTS.md monetization section
   - Store presence → Main store listing → Privacy Policy URL: see Legal/support URLs above
2. Play Console → Play Games Services → set up a new Play Games Services
   project for `com.memorysurvival.app.android`, once Android testing resumes.
3. Play Console → Monetize → Products → In-app products → **+**
   - Product ID: `memory_survival_remove_ads` (must match the iOS product ID above)
   - Price: $2.99

## iOS release pipeline

`.github/workflows/ios-mobile-release.yml` and `packages/mobile/ios/fastlane`
build, upload to TestFlight, push metadata, and (behind the `ios-appstore`
environment) submit for review. `appstore_submit` runs
`scripts/asc_preflight.py --require-attached-build` first.

Signing is automatic. The Runner target sets `CODE_SIGN_STYLE = Automatic`
with the existing development team; the Fastfile also sets it at build time
from `FASTLANE_TEAM_ID`. What's New is `metadata/en-US/release_notes.txt`
("First release."). The submit lane must not replace that with a placeholder.
