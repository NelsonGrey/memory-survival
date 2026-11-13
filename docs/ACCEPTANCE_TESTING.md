# Acceptance testing

How each business requirement in `BUSINESS_REQUIREMENTS.md` (MAS-BR) and the
technical requirements it depends on (MAS-TR) is verified. Automated
evidence runs in CI on every push and pull request; the rest is human
evidence that has to be collected and filed before release.

## Automated

| Requirement | Evidence | Where |
|---|---|---|
| MAS-BR-003 capacity vs. fragmentation failures are distinguished | Engine classifies both and the explanation names the cause | `test/acceptance/requirements_test.dart` |
| MAS-BR-004 compaction has a visible cost | Uses a charge, costs points and ticks; refused when out of charges | `test/acceptance/requirements_test.dart` |
| MAS-BR-005 at least 36 scenarios and an endless mode | Scenario inventory count and unique IDs; home offers Play and Scenarios | `test/acceptance/requirements_test.dart` |
| MAS-BR-006, MAS-TR-016 sign-in is opt-in and never gates play | Endless and scenario runs finish while disconnected; nothing reaches Game Center | `test/acceptance/requirements_test.dart`, `test/gamecenter/` |
| MAS-BR-007, MAS-TR-015 one purchase removes all ads | Purchase or restore hides the banner and suppresses interstitials | `test/acceptance/requirements_test.dart` |
| MAS-BR-012 every failure is explained | Every failure, placement and compaction error has a plain-language explanation | `test/acceptance/requirements_test.dart` |
| MAS-BR-015 ad placement | Banner on menus, results and pause; none during placement; one interstitial on leaving a finished scenario; none on menu navigation or at scenario start | `test/acceptance/requirements_test.dart` |
| MAS-BR-016 leaderboard | A signed-in (including ad-free) player's endless score is submitted; only Normal difficulty is ranked | `test/acceptance/requirements_test.dart` |
| MAS-BR-001 placement is understood | Simulated casual player places a first process on every difficulty (80%+ of seeds) and outlasts the opening | `test/acceptance/simulated_players_test.dart` |
| MAS-BR-002 size and lifetime both matter | Strategies diverge: reading lifetimes beats ignoring them on every difficulty; careful play scores 1.5x first-fit | `test/acceptance/simulated_players_test.dart` |
| MAS-BR-004 compaction is worth its cost | Compacting well scores 1.5x never compacting | `test/acceptance/simulated_players_test.dart` |
| MAS-BR-008 overlays are optional | Suggestions are off until enabled; relaxed clock is off by default, slows ticks and persists | `test/acceptance/accessibility_test.dart` |
| MAS-BR-013 not reliant on color, audio, fine motor precision or rapid reading | Tap targets (Android and iOS guidelines), every control labelled, text contrast, no overflow at 1.5x, 2x and 3x text, memory cells and lifetimes described in words | `test/acceptance/accessibility_test.dart`, `test/theme/` |
| MAS-BR-014 store claims | Metadata within App Store limits; the scenario count in the listing is the real count; promised features exist in code; no price or superlative claims | `test/release/release_readiness_test.dart` |
| Release gates | No Google test ad IDs on iOS; Info.plist AdMob app ID equals the code; iPhone-only; opaque screenshots and icons of the right size; docs list every Game Center ID and the purchase product ID | `test/release/release_readiness_test.dart` |
| Live App Store Connect state | Listing, screenshots, categories, age rating, review contact, Free price, availability, the $2.99 Unlock Premium purchase, Game Center IDs, localizations and images, and the build all match the repo | `scripts/asc_preflight.py` (CI job "ASC preflight", weekly and on demand; also gates submit for review) |
| End-to-end launch | The real app on an iOS simulator: decline Game Center, open Settings and Scenarios, finish an endless run | `integration_test/app_smoke_test.dart` (CI job `integration`) |

## Human evidence still required

These cannot be proven by a test. Record the result and the date next to each
item when it is collected. Items that automation now covers in part say what
remains for a person.

| Requirement | What is left for a person | Result |
|---|---|---|
| MAS-BR-001 placement is understood | Optional: watch two or three real people place a first process (simulated players only show it is possible) | |
| MAS-BR-009 original visual metaphor and assets | Originality review; `ASSET_PROVENANCE.md` is current | |
| MAS-BR-010 title and icon clearance | Signed clearance checklist | |
| MAS-BR-011 non-programmers enjoy the loop | Discovery report, at least 15 target players | |
| MAS-BR-012 failures are comprehensible | Explanations exist for every fault (automated); whether players understand them needs a few sessions | |
| MAS-BR-013 accessibility | One VoiceOver pass on a device (the automated suite checks labels, targets, contrast and large text, not how it sounds) | |
| MAS-BR-015 ad placement on device | Playtest with the real ad SDK, free and ad-free (placement rules are automated with fake ads) | |
| MAS-BR-006, MAS-BR-016 platform services | Game Center sign-in, leaderboard and achievements on a real device and sandbox account (the App Store Connect side is checked by `asc_preflight.py`) | |
| App Privacy labels, EU trader status, AdMob consent message | Done (confirmed by the owner, 2026-11-03). Not readable through the API, so re-check in the consoles if the ad or data setup changes | Done |

## Running the automated checks

```sh
cd packages/mobile
flutter analyze && flutter test                # everything above except live App Store Connect
python3 scripts/asc_preflight.py               # live App Store Connect (needs the three APP_STORE_CONNECT_* variables)
```

CI runs the first on every push. The second runs weekly and on demand
(Actions > "ASC preflight"), and the release workflow runs it before
"appstore_submit".

## Release checklist (run on a TestFlight build)

Steps marked *automated* run in CI (`test/acceptance/release_checklist_test.dart`
and the requirement tests above); do them by hand only to confirm on a device.

1. Fresh install: Game Center is offered once; "Not now" reaches Home. *Automated.*
2. Play an endless run on each difficulty; the results card explains the final fault. *Automated.*
3. Finish a scenario: stars are saved and the next scenario unlocks. *Automated* (`test/game/screens_depth_test.dart`).
4. Free player: banner on menus and pause, none while placing, one interstitial after a scenario. *Automated with fake ads; check the real ads on a device.*
5. Buy (sandbox) and restore: banner and interstitials disappear and stay gone after relaunch. *Hiding ads is automated; the sandbox purchase sheet is manual.*
6. Connect Game Center: a Normal-difficulty score appears on the leaderboard; an Easy score does not. *Submission rules are automated; the real leaderboard is manual.*
7. Settings: palette, difficulty, relaxed clock and suggested placement persist across relaunch. *Automated.*
