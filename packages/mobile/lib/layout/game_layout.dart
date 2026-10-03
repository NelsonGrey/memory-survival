import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identifies a gameplay layout. Persisted by name: renaming a value changes
/// what a player who already picked a non-default layout sees next launch.
enum GameLayoutId { classic, ribbon, thumb, focus, tower }

/// How the gameplay screen is arranged. The simulation is identical in every
/// layout; only presentation differs.
class GameLayout {
  const GameLayout({
    required this.name,
    required this.description,
    this.lines = 1,
    this.vertical = false,
    this.controlsFirst = false,
    this.showAdvancedStats = true,
    this.showAddresses = true,
  });

  final String name;
  final String description;

  /// Horizontal strip folded into this many rows (addresses keep running
  /// from one row to the next). Ignored when [vertical].
  final int lines;

  /// Strip drawn as a column beside the controls instead of a row.
  final bool vertical;

  /// Queue and gap buttons above the strip, so the strip sits under the thumb.
  final bool controlsFirst;

  /// Free-cell and biggest-gap readouts (progressively introduced overlays,
  /// MAS-BR-008).
  final bool showAdvancedStats;
  final bool showAddresses;
}

const Map<GameLayoutId, GameLayout> gameLayouts = {
  GameLayoutId.classic: GameLayout(
    name: 'Classic',
    description: 'One long strip on top, requests below',
  ),
  GameLayoutId.ribbon: GameLayout(
    name: 'Ribbon',
    description: 'Strip folded into two rows for bigger cells',
    lines: 2,
  ),
  GameLayoutId.thumb: GameLayout(
    name: 'Thumb',
    description: 'Strip at the bottom, within easy thumb reach',
    lines: 2,
    controlsFirst: true,
  ),
  GameLayoutId.focus: GameLayout(
    name: 'Focus',
    description: 'Two rows, only score and time shown',
    lines: 2,
    showAdvancedStats: false,
    showAddresses: false,
  ),
  GameLayoutId.tower: GameLayout(
    name: 'Tower',
    description: 'Memory as a tall column beside the controls',
    vertical: true,
  ),
};

const List<GameLayoutId> gameLayoutOrder = [
  GameLayoutId.classic,
  GameLayoutId.ribbon,
  GameLayoutId.thumb,
  GameLayoutId.focus,
  GameLayoutId.tower,
];

const GameLayoutId defaultGameLayout = GameLayoutId.classic;

/// Holds the player's chosen layout and persists it.
class LayoutController extends ValueNotifier<GameLayoutId> {
  LayoutController() : super(defaultGameLayout);

  static const _prefsKey = 'gameplay.layout';

  GameLayout get layout => gameLayouts[value]!;

  /// An unknown saved name falls back to the default rather than throwing.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    value = GameLayoutId.values.firstWhere(
      (id) => id.name == saved,
      orElse: () => defaultGameLayout,
    );
  }

  Future<void> select(GameLayoutId id) async {
    value = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id.name);
  }
}
