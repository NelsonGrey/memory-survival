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
Game Center, purchases, relaxed clock, legal links). The deterministic
allocation engine (`lib/engine/`) and the playable game (`lib/game/`,
tap-only) are in:

- **Endless survival** in pressure waves (calm, warning, storm, recovery),
  with one new process family unlocked per wave (burst, resident, priority,
  volatile, pinned, linked, leak).
- **Clean-run multiplier** on every point, broken by faults, compaction, a
  full waiting list, or fragmentation; tidy placements earn a bonus.
- **Arriving** list of the next requests, with detail that thins out as waves
  pass; tap one to hold space for it. The first storm comes after a calm
  stretch (`firstWaveDelay`).
- **Faults add heat** (shorter deadlines, then a locked cell) that a clean wave
  cools; lives are never refunded.
- **Tower layout**: the memory strip runs the full height of the screen with
  cell numbers in an outside gutter; every live block shows a time-to-live
  pill and a draining bar (red "!" at two ticks or less).
- **Placement choices**: valid starts marked on the strip, Start/End of each
  gap with the resulting biggest free block, and an optional one-tap
  suggestion that earns no multiplier.
- **Risk and reward**: overclock, hold space for an arriving request, turn a
  request away once per wave, clean up leaks at the cost of locked cells.
- **Compaction** costs ticks while arrivals continue.
- **36 authored scenarios** in four chapters, each with survive / tidy / clean
  objectives, checked solvable by scripted players (`lib/engine/bots.dart`).
- **Daily run** (shared seed), personal bests (clean streak, biggest rescue,
  most waves), a leaderboard per ruleset version, and cosmetic palette
  unlocks earned through mastery.

**Not built yet:** Android Play Games Services and gameplay analytics. The
original visual identity (S2, Shrinking Safe Corridor) is in: mark, wordmark,
launch screen, and the pressure-wall backdrop.

Balance tooling: `dart run tool/balance.dart` (survival of scripted policies,
including human-speed bots that act every tick or every other tick; rules are
tuned so a slow-paced player lasts a few minutes, not seconds) and `dart run tool/pick_scenario_seeds.dart` (re-picks authored scenario
seeds after a rules change).

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
