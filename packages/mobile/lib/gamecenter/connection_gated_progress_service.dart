import 'package:shared_preferences/shared_preferences.dart';

import 'game_center_connection.dart';
import 'game_center_progress_service.dart';

/// Forwards to [inner] only while the player is connected to Game Center.
///
/// Achievements earned while disconnected aren't lost: their IDs are kept
/// locally and granted by [flushEarned] the next time the player connects.
/// Scores and cloud saves need no such queue — the game's run-state re-pushes its
/// current totals on connect.
class ConnectionGatedProgressService implements GameCenterProgressService {
  ConnectionGatedProgressService(this.inner, this.connection);

  final GameCenterProgressService inner;
  final GameCenterConnection connection;

  static const _earnedKey = 'gamecenter.earnedWhileDisconnected';

  @override
  Future<void> unlockAchievement(String id) async {
    if (connection.isConnected) return inner.unlockAchievement(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      final earned = (prefs.getStringList(_earnedKey) ?? []).toSet()..add(id);
      await prefs.setStringList(_earnedKey, earned.toList());
    } catch (_) {
      // Best-effort, like every Game Center call.
    }
  }

  /// Grants every achievement remembered from while disconnected.
  Future<void> flushEarned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final earned = prefs.getStringList(_earnedKey) ?? const [];
      await prefs.remove(_earnedKey);
      for (final id in earned) {
        await inner.unlockAchievement(id);
      }
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<void> submitScore(int score, {String? leaderboardId}) async {
    if (connection.isConnected) {
      await inner.submitScore(score, leaderboardId: leaderboardId);
    }
  }

  @override
  Future<void> showLeaderboard({String? leaderboardId}) async {
    if (connection.isConnected) {
      await inner.showLeaderboard(leaderboardId: leaderboardId);
    }
  }

  @override
  Future<void> showAchievements() async {
    if (connection.isConnected) await inner.showAchievements();
  }

  @override
  Future<void> saveCloudProgress(String data) async {
    if (connection.isConnected) await inner.saveCloudProgress(data);
  }

  @override
  Future<String?> loadCloudProgress() async =>
      connection.isConnected ? inner.loadCloudProgress() : null;
}
