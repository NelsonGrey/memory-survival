# Store setup checklist — Memory-Allocation Survival

Neither Google Play nor Apple provide a public API to create a brand-new
app listing, so this part is manual. Everything else (bundle IDs, Firebase
projects, CI) is already wired up to match these values.

## Apple App Store Connect

1. Developer portal → Identifiers → register bundle ID: `com.memoryallocationsurvival.app.ios`
2. App Store Connect → Apps → **+** → New App
   - Platform: iOS
   - Name: Memory-Allocation Survival (check availability; store name is portfolio-wide unique)
   - Primary language: English (U.S.)
   - Bundle ID: `com.memoryallocationsurvival.app.ios`
   - SKU: `memory-alloc-survival-ios`

## Google Play Console

1. Play Console → Create app
   - App name: Memory-Allocation Survival
   - Package name: `com.memoryallocationsurvival.app.android` (must match exactly, permanent)
   - Default language, Free/Paid per BUSINESS_REQUIREMENTS.md monetization section
2. Play Console → Setup → API access → link the `memory-alloc-survival-prod` GCP project,
   then create a service account (`google-play-console-service@memory-alloc-survival-prod.iam.gserviceaccount.com`)
   matching the pattern used by modulo-squares/vehicle-vitals/wishlist-wizard,
   grant it Release Manager access.
