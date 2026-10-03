# Memory Survival

[![CI](https://github.com/NelsonGrey/memory-survival/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/NelsonGrey/memory-survival/actions/workflows/ci.yml) [![License](https://img.shields.io/badge/license-proprietary-lightgrey.svg)](https://github.com/NelsonGrey/memory-survival/blob/develop/LICENSE)

## Contents

- [Status](#status)
- [Repository Structure](#repository-structure)
- [Deliverables](#deliverables)
- [Store setup still required manually](#store-setup-still-required-manually)
- [Legal/support pages](#legalsupport-pages)
- [Getting Started](#getting-started)

Flutter monorepo. No custom backend: sign-in, leaderboards, achievements,
and cloud save go through each platform's own game-services layer (Game
Center on iOS; Play Games Services on Android, once testing resumes) rather
than a shared Firebase project. This is the same framework as
[Intercept Echo](https://github.com/NelsonGrey/intercept-echo).

Memory Survival is a one-dimensional memory-allocation puzzle: processes of
different sizes and lifetimes arrive, and the player places each one in a
contiguous run of cells. Total free space can be enough while no single gap
is — that's fragmentation, and compaction is a costly way out.

Related docs: [Business Requirements](./docs/BUSINESS_REQUIREMENTS.md) ·
[Technical Requirements](./docs/TECHNICAL_REQUIREMENTS.md)

## Status

Pre-release, discovery. The app shell is in place and verified (analyze,
tests, and an iOS simulator build): ads and consent, the one-time ad-removal
purchase, Game Center sign-in and its first-run prompt, and Settings (palette,
Game Center, purchases, relaxed clock, legal links). The home screen is a
placeholder.

**Not built yet:** the allocation engine and gameplay, the 36 authored
scenarios, endless mode and its leaderboard submission, the original visual
identity (MAS-BR-009), and gameplay analytics.

## Repository Structure

- `packages/mobile` — Flutter client (iOS + Android). Carries its own ads, consent, ad-removal entitlement, and Game Center sign-in under `lib/shell/` and `lib/gamecenter/` (ported from Intercept Echo, now maintained here).

Bundle/package ID base: `com.memorysurvival`

## Deliverables

| Deliverable | Platform | Identifier | Status |
| --- | --- | --- | --- |
| Android app | Google Play | `com.memorysurvival.app.android` | Kept buildable; no tester group yet, Play Console listing not yet created (see [docs/STORE_SETUP.md](docs/STORE_SETUP.md)) |
| iOS app | Apple App Store Connect | `com.memorysurvival.app.ios` | Bundle ID not yet registered; app record not yet created (see [docs/STORE_SETUP.md](docs/STORE_SETUP.md)) |

## Store setup still required manually

Google Play Console and Apple App Store Connect have no public API for
**creating a brand-new app listing** — that first step has to happen in
each console's UI. See `docs/STORE_SETUP.md` for the exact values to enter.

## Legal/support pages

This project has no marketing site of its own. Privacy/Terms/Support live on
the Nelson Grey site, under `games/memory-survival/` in the `nelson-grey`
repo — see `docs/STORE_SETUP.md` for the URLs.

## Getting Started

```bash
cd packages/mobile
flutter pub get
flutter run
```

Ads run on Google's public test IDs until this game has its own AdMob app.
