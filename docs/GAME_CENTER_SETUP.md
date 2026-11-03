# Game Center Setup (App Store Connect)

The app reports to Game Center by **ID**; nothing is auto-created. These
records must exist in App Store Connect with exactly these IDs
(`packages/mobile/lib/gamecenter/game_center_ids.dart`) before a build that
uses them ships. The same document, in the same shape, exists in Intercept
Echo and Modulo Squares.

App Store Connect → app `com.memorysurvival.app.ios` → Features → Game Center →
enable Game Center, then create:

**Status:** created in App Store Connect (reported by the owner, 2026-11-03). The
values below are what the code and this document expect; where App Store
Connect differs on titles or descriptions, App Store Connect is authoritative,
but the IDs must match exactly. The real-device check at the end is still open.

## Leaderboard

| Field | Value |
| --- | --- |
| Type | Classic |
| ID | `memory_survival_endless_score` |
| Reference name | Endless Score |
| Name (shown to players) | Endless Score |
| Description | Your best endless survival score on Normal or Hard. Easy runs are not ranked. |
| Score format | Integer |
| Score format suffix | Singular `point`, plural `points` |
| Sort | High to low |
| Score range | 0 – 100000000 |
| Image | `leaderboard-1024.png` (see Art) |

One board for every ruleset version, so a balance change
(`Ruleset.currentVersion`) does not start a new board; scores earned under
different rules share it. The app submits the endless survival score when a
run ends. Only Normal and Hard runs are ranked; Easy runs are not submitted.
On every sign-in the app re-sends this device's best endless score for the
current ruleset version. Game Center keeps only the best score per player, so
resubmitting is harmless.

## Achievements

Three achievements, 70 points total (Game Center allows 100 achievements and
1,000 points). The triggers are in `lib/game/game_screen.dart`. Each needs a
title, a pre-earned description (shown while locked: how to earn it) and an
earned description (shown once unlocked: what the player did), an image and
the point value. All are visible (not hidden) and none are repeatable.

| ID | Title | Pre-earned Description | Earned Description | Pts |
| --- | --- | --- | --- | --- |
| `memory_survival_first_allocation` | First Allocation | Place your first process in memory. | You placed your first process in memory. | 10 |
| `memory_survival_first_compaction` | Defragmented | Use compaction for the first time. | You used compaction for the first time. | 10 |
| `memory_survival_campaign_complete` | Memory Master | Finish every authored scenario. | You finished every authored scenario. | 50 |

Notes:
- Achievements earned while the player is not connected to Game Center are
  remembered on the device and granted on the next sign-in.
- All are one-shot; none use percent-complete (incremental) progress.
- The titles above are proposals; the IDs are what the code depends on.

## Art

Upload-ready art is in `packages/mobile/ios/fastlane/game_center_icons/`: one
1024×1024 PNG per achievement, named `<achievement ID>.png`, plus the
leaderboard image `leaderboard-1024.png`, each with its `.svg` source and the
`make_icons.py` generator. See that folder's README for
regenerating and uploading. Upload each PNG on its achievement's page in App
Store Connect (one at a time; there is no bulk upload).

## Entitlement

`ios/Runner/Runner.entitlements` carries `com.apple.developer.game-center`.
Without it, sign-in and everything downstream fails silently.

Game Center's cloud-saved games (`SaveGame`) have a service layer
(`saveCloudProgress` / `loadCloudProgress`) but the game does not use it yet:
campaign progress is not synced across devices. No configuration is needed
when it is wired in.

## Behaviour to verify on a real device (TestFlight)

Signed into a Game Center account in iOS Settings:

1. First launch offers to connect to Game Center. **Connect** signs in;
   **Not now** is remembered and the game stays fully playable.
2. Settings → Game Center shows the player's alias, Leaderboard and
   Achievements shortcuts, and Disconnect. Leaderboard and Achievements open
   Game Center's native UI.
3. Placing the first process pops the "First Allocation" banner, and a
   Normal-difficulty endless score appears on the leaderboard; an Easy score
   does not.
4. With no Game Center account on the device, the leaderboard shortcut says
   Game Center is unavailable and play is unaffected.
5. Reviewers can play the whole game without connecting.
