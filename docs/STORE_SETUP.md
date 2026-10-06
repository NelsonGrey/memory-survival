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

These pages go live when the `nelson-grey` repo is deployed. Use them for App
Store Connect's Privacy Policy URL and Support URL, and Play Console's
Privacy Policy URL, below.

## Apple App Store Connect

1. Developer portal → Identifiers → register bundle ID: `com.memorysurvival.app.ios` — **not done yet**
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
   - Product ID: `memory_survival_remove_ads` (must match `adRemovalProductId`
     in `lib/app/app_services.dart`)
   - Price: Tier 3 ($2.99)
   - Validate on a real device in a TestFlight build: tapping "Remove Ads —
     $2.99" in Settings shows the StoreKit purchase sheet at the right price.
4. AdMob console → create an app for `com.memorysurvival.app.ios` with a banner
   and an interstitial unit. Until then the game runs on Google's public test
   IDs (`AdMobConfig.test()` in `lib/app/app_services.dart`, and
   `GADApplicationIdentifier` in `ios/Runner/Info.plist`). **Never reuse
   another game's production IDs.** When the real IDs exist:
   - Replace `AdMobConfig.test()` with a real `AdMobConfig` and update
     `GADApplicationIdentifier`.
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
   — enable Game Center, then create these records (IDs must match
   `lib/gamecenter/game_center_progress_service.dart`'s `GameCenterIds`
   exactly — the code references them by ID, nothing here is auto-created):
   - **Leaderboard** (Classic, higher score is better): one per ruleset
     version, ID `memory_survival_endless_score_v<N>` (currently
     `memory_survival_endless_score_v5`, see `Ruleset.currentVersion`) —
     endless survival score. Scores earned under different rules never share
     a board, so **create a new leaderboard each time `Ruleset.currentVersion`
     is bumped** (before shipping that build).
   - **Achievements** (three, no ordering requirement):
     - `memory_survival_first_allocation` — place the first process
     - `memory_survival_first_compaction` — use compaction for the first time
     - `memory_survival_campaign_complete` — finish every authored scenario
   - The game only signs in after the player opts in (first-run prompt,
     home-screen badge, or Settings > Game Center). Reviewers can play the
     whole game without it.
   - Game Center's cloud-saved games (`SaveGame`) are used for cross-device
     progress sync — no separate configuration beyond Game Center being on.
   - The `com.apple.developer.game-center` entitlement is already in
     `ios/Runner/Runner.entitlements` and the Xcode project.
   - Validate on a real device signed into Game Center in a TestFlight build:
     Settings → Leaderboard/Achievements should open Game Center's native UI.

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

Not set up yet. Intercept Echo's `ios-mobile-release.yml` and
`ios/fastlane` are the model; port them once the bundle ID is registered and
the app record exists.
