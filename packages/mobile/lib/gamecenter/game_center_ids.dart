/// Achievement/leaderboard/cloud-save IDs. These have to match records
/// created in App Store Connect's Game Center configuration exactly — see
/// docs/GAME_CENTER_SETUP.md for the manual setup (names, descriptions and
/// point values) this list drives.
class GameCenterIds {
  const GameCenterIds._();

  /// Endless survival score (MAS-BR-016): one board, whatever the ruleset
  /// version.
  static const leaderboardEndlessScore = 'memory_survival_endless_score';

  static const achievementFirstAllocation = 'memory_survival_first_allocation';
  static const achievementFirstCompaction = 'memory_survival_first_compaction';
  static const achievementCampaignComplete =
      'memory_survival_campaign_complete';

  /// The saved-game slot name for cloud-synced campaign progress (Game
  /// Center's iCloud-backed saved games, via SaveGame.saveGame/loadGame).
  static const cloudSaveName = 'memory_survival_progress';
}
