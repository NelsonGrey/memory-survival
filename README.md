# Memory-Allocation Survival

Flutter + Firebase monorepo, following the same architecture pattern as
Modulo Squares.

Related docs: [Business Requirements](./docs/BUSINESS_REQUIREMENTS.md) ·
[Technical Requirements](./docs/TECHNICAL_REQUIREMENTS.md)

## Layout

- `packages/mobile` — Flutter client (iOS + Android). Depends on [game-shell](https://github.com/NelsonGrey/game-shell) for auth, ads, consent, and the ad-removal entitlement — see that repo before reimplementing any of those.
- `packages/functions` — Firebase Cloud Functions (Node 22 / TypeScript)
- `packages/firestore-rules` — Firestore security rules
- `packages/web` — landing page (Firebase Hosting)
- `firebase-config/` — downloaded per-environment Firebase config files (gitignored)

## Firebase projects

| Env     | Project ID              |
| ------- | ------------------------ |
| dev     | `memory-alloc-survival-dev`     |
| staging | `memory-alloc-survival-staging` |
| prod    | `memory-alloc-survival-prod`    |

Bundle/package ID base: `com.memoryallocationsurvival`

## Deliverables

Each game in this portfolio ships three deliverables:

| Deliverable | Platform | Identifier | Status |
| --- | --- | --- | --- |
| Android app | Google Play | `com.memoryallocationsurvival.app.android` | Firebase-registered; Play Console listing not yet created (see [docs/STORE_SETUP.md](docs/STORE_SETUP.md)) |
| iOS app | Apple App Store Connect | `com.memoryallocationsurvival.app.ios` | Firebase-registered; ASC app record not yet created (see [docs/STORE_SETUP.md](docs/STORE_SETUP.md)) |
| Website | Firebase Hosting | `memory-alloc-survival-{env}.web.app` | **Dev live**; staging/prod configured, not yet deployed |

Website URLs (redeploy with `firebase deploy --only hosting --project <env>`, or run the equivalent Hosting REST API calls if `firebase login` has not been done on this machine):

- Dev: https://memory-alloc-survival-dev.web.app &mdash; **live**
- Staging: https://memory-alloc-survival-staging.web.app &mdash; not yet deployed
- Prod: https://memory-alloc-survival-prod.web.app &mdash; not yet deployed

## Store setup still required manually

Google Play Console and Apple App Store Connect have no public API for
**creating a brand-new app listing** — that first step has to happen in
each console's UI. See `docs/STORE_SETUP.md` for the exact values to enter.

## Getting started

```bash
cd packages/mobile
cp ../../firebase-config/google-services.dev.json android/app/google-services.json
cp ../../firebase-config/GoogleService-Info.dev.plist ios/Runner/GoogleService-Info.plist
flutter pub get
flutter run
```

## License

See [LICENSE](LICENSE). Security issues: see [SECURITY.md](SECURITY.md).
