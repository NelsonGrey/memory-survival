import 'game_center_progress_service.dart';

/// Deterministic [GameCenterProgressService] for tests: records every call
/// instead of touching a platform channel. `loadCloudProgress` returns
/// whatever `cloudData` currently holds, so a test can simulate an
/// existing cloud save by setting it before the run state loads.
class FakeGameCenterProgressService implements GameCenterProgressService {
  final List<String> unlockedAchievements = [];
  final List<int> submittedScores = [];
  int showLeaderboardCount = 0;
  int showAchievementsCount = 0;
  final List<String> savedCloudProgress = [];

  /// What `loadCloudProgress` returns; null means "no cloud save yet".
  String? cloudData;

  @override
  Future<void> unlockAchievement(String id) async {
    unlockedAchievements.add(id);
  }

  @override
  Future<void> submitScore(int score) async {
    submittedScores.add(score);
  }

  @override
  Future<void> showLeaderboard() async {
    showLeaderboardCount++;
  }

  @override
  Future<void> showAchievements() async {
    showAchievementsCount++;
  }

  @override
  Future<void> saveCloudProgress(String data) async {
    savedCloudProgress.add(data);
    cloudData = data;
  }

  @override
  Future<String?> loadCloudProgress() async => cloudData;
}
