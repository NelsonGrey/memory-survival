import '../theme/game_theme.dart';
import 'personal_bests.dart';
import 'scenario_progress.dart';

/// Cosmetic palettes earned through mastery. Nothing here changes
/// gameplay: no bigger memory, longer deadlines or extra lives, so scores
/// stay comparable.
class PaletteUnlock {
  const PaletteUnlock(this.requirement, this.isMet);

  /// Plain-language condition shown on the locked palette.
  final String requirement;
  final bool Function(PersonalBests bests, ScenarioProgress progress) isMet;
}

/// Palettes not listed here are always available (including the
/// high-contrast one, which is an accessibility feature).
final Map<GameThemeId, PaletteUnlock> paletteUnlocks = {
  GameThemeId.ember: PaletteUnlock(
    'Reach a clean-run streak of 12 in any run',
    (b, _) => b.bestStreak >= 12,
  ),
  GameThemeId.forest: PaletteUnlock(
    'Earn 20 scenario stars',
    (_, p) => p.totalStars >= 20,
  ),
};

bool isPaletteUnlocked(
  GameThemeId id,
  PersonalBests bests,
  ScenarioProgress progress,
) => paletteUnlocks[id]?.isMet(bests, progress) ?? true;
