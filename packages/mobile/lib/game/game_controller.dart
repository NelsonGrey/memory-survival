import 'package:flutter/foundation.dart';

import '../engine/engine.dart';
import 'explain.dart';

/// Base tick length, and the "Relaxed clock" accessibility multiplier.
const baseTickDuration = Duration(milliseconds: 1000);
const relaxedClockMultiplier = 2;

/// How long a fault explanation stays on screen.
const faultNoticeTicks = 6;

/// Drives one endless run: owns the engine state, the selected request and
/// the latest feedback message. Contains no timers; the screen calls [tick]
/// so tests can step the simulation directly and backgrounding can pause it.
class GameController extends ChangeNotifier {
  GameController({required this.rules, required this.seed})
    : engine = MemoryEngine(rules),
      generator = RequestGenerator(rules, seed) {
    state = engine.initial(seed: seed);
  }

  final Ruleset rules;
  final int seed;
  final MemoryEngine engine;
  final RequestGenerator generator;

  late MemoryState state;
  int? _selectedId;
  String? message;

  /// What the last fault was and why, shown for [_noticeTicks] ticks.
  String? faultNotice;
  int _noticeTicks = 0;
  bool paused = false;

  bool get isPlaying => state.status == RunStatus.playing;

  /// The selected request, defaulting to the oldest one waiting.
  Request? get selected {
    final queue = state.requestQueue;
    if (queue.isEmpty) return null;
    return state.requestById(_selectedId ?? -1) ?? queue.first;
  }

  /// Gaps big enough for the selected request: tap-only placement targets.
  List<Gap> get fittingGaps {
    final r = selected;
    if (r == null) return const [];
    return [
      for (final g in state.gaps)
        if (g.size >= r.size) g,
    ];
  }

  void select(int requestId) {
    if (state.requestById(requestId) == null) return;
    _selectedId = requestId;
    message = null;
    notifyListeners();
  }

  /// Places the selected request starting at [start].
  bool placeAt(int start) {
    final r = selected;
    if (r == null || !isPlaying || paused) return false;
    final result = engine.place(state, r.id, start);
    if (result.isOk) {
      state = result.state!;
      _selectedId = null;
      message = null;
    } else {
      message = explainPlacementError(
        result.error!,
        requestSize: r.size,
        cellCount: rules.cellCount,
        blockedBy: result.blockedBy,
      );
    }
    notifyListeners();
    return result.isOk;
  }

  void compact() {
    if (!isPlaying || paused) return;
    final result = engine.compact(state);
    if (result.isOk) {
      state = result.state!;
      message = null;
    } else {
      message = explainCompactionError(result.error!);
    }
    notifyListeners();
  }

  /// Advances the simulation one tick, bringing in the seeded arrival.
  void tick() {
    if (!isPlaying || paused) return;
    final before = state.faultCount;
    state = engine.tick(
      state,
      arrivals: generator.arrivalsFor(state.cycle + 1),
    );
    if (state.faultCount > before) {
      final lives = state.livesLeft;
      faultNotice =
          '${explainFailure(state.failure!, rules)} '
          '$lives ${lives == 1 ? 'life' : 'lives'} left.';
      _noticeTicks = faultNoticeTicks;
    } else if (_noticeTicks > 0 && --_noticeTicks == 0) {
      faultNotice = null;
    }
    notifyListeners();
  }

  void setPaused(bool value) {
    if (paused == value) return;
    paused = value;
    notifyListeners();
  }
}
