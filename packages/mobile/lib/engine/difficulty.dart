import 'ruleset.dart';

/// Endless-mode difficulty. Normal is the reference balance
/// ([Ruleset.currentVersion]); the others only change forgiveness and
/// pressure, never the rules themselves.
enum Difficulty {
  easy('Easy', 'More lives and time, calmer arrivals'),
  normal('Normal', 'The standard balance'),
  hard('Hard', 'Fewer lives and time, heavier arrivals');

  const Difficulty(this.label, this.blurb);

  final String label;
  final String blurb;

  Ruleset get rules => switch (this) {
    Difficulty.easy => const Ruleset(
      lives: 4,
      requestDeadline: 10,
      compactionCharges: 3,
      arrivalPerMille: 300,
      arrivalMaxPerMille: 650,
      stormPerMille: 400,
    ),
    Difficulty.normal => const Ruleset(),
    Difficulty.hard => const Ruleset(
      lives: 2,
      requestDeadline: 6,
      compactionCharges: 1,
      arrivalPerMille: 500,
      arrivalMaxPerMille: 850,
      stormPerMille: 650,
    ),
  };

  /// Only Normal runs reach the (single) Game Center leaderboard, so every
  /// posted score was earned under the same rules.
  bool get ranked => this == Difficulty.normal;
}
