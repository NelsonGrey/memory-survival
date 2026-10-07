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
| End-to-end launch | The real app on an iOS simulator: decline Game Center, open Settings and Scenarios, finish an endless run | `integration_test/app_smoke_test.dart` (CI job `integration`) |

## Human evidence still required

These cannot be proven by a test. Record the result and the date next to each
item when it is collected.

| Requirement | Evidence to collect | Result |
|---|---|---|
| MAS-BR-001 placement is understood | Usability test: at least 80% first-allocation success | |
| MAS-BR-002 size and lifetime both matter | Playtest examples with divergent strategies | |
| MAS-BR-008 overlays are optional or progressive | UX and accessibility review | |
| MAS-BR-009 original visual metaphor and assets | Originality review; `ASSET_PROVENANCE.md` is current | |
| MAS-BR-010 title and icon clearance | Signed clearance checklist | |
| MAS-BR-011 non-programmers enjoy the loop | Discovery report, at least 15 target players | |
| MAS-BR-012 failures are comprehensible | Usability and state-reconstruction sessions | |
| MAS-BR-013 not reliant on color, audio, fine motor precision or rapid reading | Accessibility test report (VoiceOver, larger text, relaxed clock, high-contrast palette) | |
| MAS-BR-014 store claims | Store-listing review | |
| MAS-BR-015 ad placement on device | Playtest with the real ad SDK, free and ad-free | |
| MAS-BR-006, MAS-BR-016 platform services | Game Center sign-in, leaderboard and achievements on a real device and sandbox account | |

## Release checklist (run on a TestFlight build)

1. Fresh install: Game Center is offered once; "Not now" reaches Home.
2. Play an endless run on each difficulty; the results card explains the final fault.
3. Finish a scenario: stars are saved and the next scenario unlocks.
4. Free player: banner on menus and pause, none while placing, one interstitial after a scenario.
5. Buy (sandbox) and restore: banner and interstitials disappear and stay gone after relaunch.
6. Connect Game Center: a Normal-difficulty score appears on the leaderboard; an Easy score does not.
7. Settings: palette, difficulty, relaxed clock and suggested placement persist across relaunch.
