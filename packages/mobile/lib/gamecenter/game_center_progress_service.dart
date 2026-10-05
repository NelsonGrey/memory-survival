import '../engine/ruleset.dart';

/// Achievement/leaderboard/cloud-save IDs. These have to match records
/// created in App Store Connect's Game Center configuration exactly — see
/// docs/STORE_SETUP.md for the manual setup this list drives.
class GameCenterIds {
  const GameCenterIds._();

  /// Endless survival score (MAS-BR-016). The record created in App Store
  /// Connect carries the ruleset version as a suffix; see
  /// [endlessLeaderboardFor].
  static const leaderboardEndlessScore = 'memory_survival_endless_score';

  /// One leaderboard per ruleset version, so a balance change starts a fresh
  /// board instead of mixing scores earned under different rules.
  static String endlessLeaderboardFor(int rulesetVersion) =>
      '${leaderboardEndlessScore}_v$rulesetVersion';

  /// The board for the rules this build plays.
  static String get currentEndlessLeaderboard =>
      endlessLeaderboardFor(Ruleset.currentVersion);

  static const achievementFirstAllocation = 'memory_survival_first_allocation';
  static const achievementFirstCompaction = 'memory_survival_first_compaction';
  static const achievementCampaignComplete =
      'memory_survival_campaign_complete';

  /// The saved-game slot name for cloud-synced campaign progress (Game
  /// Center's iCloud-backed saved games, via SaveGame.saveGame/loadGame).
  static const cloudSaveName = 'memory_survival_progress';
}

/// Game Center integration beyond sign-in: achievements, the leaderboard,
/// and cloud-saved campaign progress.
///
/// Every method is best-effort: a failure (not signed in, offline,
/// simulator without a Game Center account, Android with no Play Games
/// project yet) is swallowed inside the implementation, never thrown — so
/// callers never need to guard these calls, the same contract
/// [PlatformGameAuthService.signIn] already has in `AppServices.initialize`.
abstract class GameCenterProgressService {
  Future<void> unlockAchievement(String id);

  /// Submits [score] to [leaderboardId], defaulting to this build's endless
  /// board ([GameCenterIds.currentEndlessLeaderboard]).
  Future<void> submitScore(int score, {String? leaderboardId});
  Future<void> showLeaderboard({String? leaderboardId});
  Future<void> showAchievements();

  /// Pushes [data] (a small, opaque JSON string) to the platform's cloud
  /// save slot ([GameCenterIds.cloudSaveName]).
  Future<void> saveCloudProgress(String data);

  /// The last cloud-saved data, or null if there is none yet or the load
  /// failed.
  Future<String?> loadCloudProgress();
}
