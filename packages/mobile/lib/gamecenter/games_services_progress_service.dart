import 'dart:io';

import 'package:games_services/games_services.dart';

import 'game_center_progress_service.dart';

/// Real [GameCenterProgressService], backed by Game Center via the
/// `games_services` plugin's static Leaderboards/Achievements/SaveGame
/// APIs. iOS/macOS only, matching `GameCenterAuthService` in lib/shell/auth —
/// Android would need its own Play Games project and a second set of
/// leaderboard/achievement IDs, which don't exist yet (see README status).
class GamesServicesProgressService implements GameCenterProgressService {
  GamesServicesProgressService() {
    if (!(Platform.isIOS || Platform.isMacOS)) {
      throw UnsupportedError(
        'GamesServicesProgressService is only supported on iOS/macOS.',
      );
    }
  }

  @override
  Future<void> unlockAchievement(String id) async {
    try {
      await Achievements.unlock(
        achievement: Achievement(androidID: id, iOSID: id),
      );
    } catch (_) {
      // Best-effort: not signed in, offline, etc. — never blocks gameplay.
    }
  }

  @override
  Future<void> submitScore(int score) async {
    try {
      await Leaderboards.submitScore(
        score: Score(
          androidLeaderboardID: GameCenterIds.leaderboardEndlessScore,
          iOSLeaderboardID: GameCenterIds.leaderboardEndlessScore,
          value: score,
        ),
      );
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<void> showLeaderboard() async {
    try {
      await Leaderboards.showLeaderboards(
        iOSLeaderboardID: GameCenterIds.leaderboardEndlessScore,
        androidLeaderboardID: GameCenterIds.leaderboardEndlessScore,
      );
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<void> showAchievements() async {
    try {
      await Achievements.showAchievements();
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<void> saveCloudProgress(String data) async {
    try {
      await SaveGame.saveGame(data: data, name: GameCenterIds.cloudSaveName);
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<String?> loadCloudProgress() async {
    try {
      return await SaveGame.loadGame(name: GameCenterIds.cloudSaveName);
    } catch (_) {
      return null;
    }
  }
}
