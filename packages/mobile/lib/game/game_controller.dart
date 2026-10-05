import 'package:flutter/foundation.dart';

import '../engine/engine.dart';
import 'explain.dart';

/// Base tick length, and the "Relaxed clock" accessibility multiplier.
const baseTickDuration = Duration(milliseconds: 1000);
const relaxedClockMultiplier = 2;

/// How long a fault explanation or event note stays on screen.
const faultNoticeTicks = 6;
const toastTicks = 4;

/// How much the forecast tells the player, easing off as waves pass:
/// exact early, a lifetime band mid-run, size only (sometimes scrambled)
/// late.
enum ForecastDetail { exact, band, sizeOnly }

class ForecastItem {
  const ForecastItem({
    required this.ticksAway,
    required this.request,
    required this.detail,
    required this.scrambled,
  });

  final int ticksAway;

  /// The real request. The UI must show only what [detail] allows.
  final Request request;
  final ForecastDetail detail;

  /// A late-run preview that shows no size at all.
  final bool scrambled;

  int get id => request.id;

  /// The size to show, or null when scrambled.
  int? get shownSize => scrambled ? null : request.size;

  /// Whether the player may reserve space for it: only when its size is
  /// really known.
  bool get reservable => !scrambled;

  String get lifetimeLabel {
    switch (detail) {
      case ForecastDetail.exact:
        return lifetimeText(request);
      case ForecastDetail.band:
        final lo = (request.lifetime - 1) ~/ 3 * 3 + 1;
        return 'lives $lo–${lo + 2}';
      case ForecastDetail.sizeOnly:
        return '';
    }
  }

  String? get tag => detail == ForecastDetail.exact ? familyTag(request) : null;
}

/// One tap-to-place choice inside a gap.
class PlacementOption {
  const PlacementOption({
    required this.start,
    required this.label,
    required this.largestFreeAfter,
  });

  final int start;

  /// "Start", "End" or "Fill".
  final String label;

  /// Largest contiguous free block left if this placement is chosen.
  final int largestFreeAfter;
}

/// Drives one run: owns the engine state, the selected request and the
/// latest feedback message. Contains no timers; the screen calls [tick]
/// so tests can step the simulation directly and backgrounding can pause it.
class GameController extends ChangeNotifier {
  GameController({
    required this.rules,
    required this.seed,
    this.suggestions = false,
  }) : engine = MemoryEngine(rules),
       generator = RequestGenerator(rules, seed) {
    state = engine.initial(seed: seed);
  }

  final Ruleset rules;
  final int seed;
  final MemoryEngine engine;
  final RequestGenerator generator;

  /// Whether the one-tap suggestion is offered (a setting).
  final bool suggestions;

  late MemoryState state;
  int? _selectedId;
  String? message;

  /// What the last fault was and why, shown for [faultNoticeTicks] ticks.
  String? faultNotice;
  int _noticeTicks = 0;

  /// A positive or neutral note about the last event (wave cleared, the
  /// multiplier dropping, a lock).
  String? toast;
  int _toastTicks = 0;
  int _eventsSeen = 0;
  bool paused = false;

  /// A forecast request the player is choosing a region for.
  ForecastItem? _reserving;

  bool get isPlaying => state.status == RunStatus.playing;
  bool get isCompleted => state.status == RunStatus.completed;

  /// The selected request, defaulting to the oldest one waiting.
  Request? get selected {
    final queue = state.requestQueue;
    if (queue.isEmpty) return null;
    return state.requestById(_selectedId ?? -1) ?? queue.first;
  }

  ForecastItem? get reserving => _reserving;

  /// Gaps big enough for the selected request: tap-only placement targets.
  List<Gap> get fittingGaps {
    final r = selected;
    if (r == null) return const [];
    return [
      for (final g in state.gaps)
        if (g.size >= r.size) g,
    ];
  }

  /// Start and end of every fitting gap, with what each would leave behind.
  /// A reservation held for the selected request counts as free for it.
  List<PlacementOption> get placementOptions {
    final r = selected;
    if (r == null) return const [];
    final starts = <int, String>{};
    for (final g in state.gaps) {
      if (g.size < r.size) continue;
      if (g.size == r.size) {
        starts[g.start] = 'Fill';
      } else {
        starts[g.start] = 'Start';
        starts[g.end - r.size] = 'End';
      }
    }
    final reserved = state.reservation;
    if (reserved != null && reserved.reservedFor == r.id) {
      starts.putIfAbsent(reserved.start, () => 'Reserved');
    }
    final out = <PlacementOption>[];
    for (final e in starts.entries) {
      final pv = engine.previewPlacement(state, r, e.key);
      if (pv != null) {
        out.add(
          PlacementOption(
            start: e.key,
            label: e.value,
            largestFreeAfter: pv.largestFreeBlock,
          ),
        );
      }
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  /// Start cells where the selected request fits, to highlight on the strip.
  Set<int> get validStarts {
    final r = selected;
    if (r == null) return const {};
    if (_reserving != null) {
      final size = _reserving!.request.size;
      return {
        for (var i = 0; i + size <= rules.cellCount; i++)
          if (state.cells.sublist(i, i + size).every((c) => c == null)) i,
      };
    }
    return engine.validStarts(state, r).toSet();
  }

  /// The next arrivals, as much of them as this stage of the run reveals.
  List<ForecastItem> get forecast {
    final wave = state.wave.number;
    final detail = wave <= 2
        ? ForecastDetail.exact
        : wave <= 5
        ? ForecastDetail.band
        : ForecastDetail.sizeOnly;
    return [
      for (final u in generator.upcoming(
        state.cycle,
        overclocked: state.overclocked,
      ))
        ForecastItem(
          ticksAway: u.ticksAway,
          request: u.request,
          detail: detail,
          scrambled: detail == ForecastDetail.sizeOnly && u.request.id % 4 == 0,
        ),
    ];
  }

  /// The id the one-tap suggestion would use, if it is offered.
  int? get suggestedStart {
    final r = selected;
    if (!suggestions || r == null) return null;
    return engine.recommendedStart(state, r);
  }

  void select(int requestId) {
    if (state.requestById(requestId) == null) return;
    _selectedId = requestId;
    message = null;
    notifyListeners();
  }

  /// Places the selected request starting at [start], or, while choosing a
  /// reservation, holds a region there instead.
  bool placeAt(int start, {bool assisted = false}) {
    if (!isPlaying || paused) return false;
    if (_reserving != null) return _reserveAt(start);
    final r = selected;
    if (r == null) return false;
    final result = engine.place(state, r.id, start, assisted: assisted);
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
        linkedTo: result.linkedTo,
      );
    }
    notifyListeners();
    return result.isOk;
  }

  /// The single-tap suggestion; scores no multiplier.
  bool placeSuggested() {
    final start = suggestedStart;
    if (start == null) return false;
    return placeAt(start, assisted: true);
  }

  void compact() {
    if (!isPlaying || paused) return;
    final result = engine.compact(state, arrivals: _arrivals);
    if (result.isOk) {
      state = result.state!;
      message = null;
      _afterTransition();
    } else {
      message = explainCompactionError(result.error!);
    }
    notifyListeners();
  }

  List<Request> _arrivals(int cycle) =>
      generator.arrivalsFor(cycle, overclocked: state.overclocked);

  void reject(int requestId) =>
      _action(() => engine.reject(state, requestId), clearSelection: true);

  void overclock() => _action(() => engine.overclock(state));

  void cleanup(int processId) =>
      _action(() => engine.cleanup(state, processId));

  void beginReserve(ForecastItem item) {
    if (!isPlaying || paused || !item.reservable) return;
    _reserving = item;
    message =
        'Tap the first cell of the ${item.request.size} cells to hold '
        'for #${item.id}.';
    notifyListeners();
  }

  void cancelReserve() {
    if (_reserving == null) return;
    _reserving = null;
    message = null;
    notifyListeners();
  }

  bool _reserveAt(int start) {
    final item = _reserving!;
    final result = engine.reserve(
      state,
      start: start,
      size: item.request.size,
      forRequestId: item.id,
    );
    if (result.isOk) {
      state = result.state!;
      _reserving = null;
      message = null;
    } else {
      message = explainActionError(result.error!);
    }
    notifyListeners();
    return result.isOk;
  }

  void _action(ActionResult Function() run, {bool clearSelection = false}) {
    if (!isPlaying || paused) return;
    final result = run();
    if (result.isOk) {
      state = result.state!;
      message = null;
      if (clearSelection) _selectedId = null;
      _afterTransition();
    } else {
      message = explainActionError(result.error!);
    }
    notifyListeners();
  }

  /// Advances the simulation one tick, bringing in the seeded arrival.
  void tick() {
    if (!isPlaying || paused) return;
    final before = state.faultCount;
    state = engine.tick(state, arrivals: _arrivals(state.cycle + 1));
    if (state.faultCount > before) {
      final lives = state.livesLeft;
      faultNotice =
          '${explainFailure(state.failure!, rules)} '
          '$lives ${lives == 1 ? 'life' : 'lives'} left. '
          '${explainHeat(state.heat, rules)}';
      _noticeTicks = faultNoticeTicks;
    } else if (_noticeTicks > 0 && --_noticeTicks == 0) {
      faultNotice = null;
    }
    if (_toastTicks > 0 && --_toastTicks == 0) toast = null;
    _afterTransition();
    notifyListeners();
  }

  /// Turns fresh engine events into on-screen notes.
  void _afterTransition() {
    final events = state.eventHistory;
    for (var i = _eventsSeen; i < events.length; i++) {
      final e = events[i];
      switch (e) {
        case WaveCleared():
          _setToast(
            e.clean
                ? 'Wave ${e.wave} cleared! +${e.bonus} points, system cooled.'
                : 'Wave ${e.wave} survived, but with a fault: no bonus.',
          );
        case MultiplierDropped():
          _setToast('Multiplier dropped. ${e.reason}');
        case Quarantined():
          _setToast('A cell is locked while the system cools.');
        case CleanedUp():
          _setToast(
            'Leak cleaned up. ${e.lockedCells} '
            '${e.lockedCells == 1 ? 'cell stays' : 'cells stay'} locked '
            'for ${rules.cleanupLockTicks} ticks.',
          );
        case OverclockStarted():
          _setToast(
            'Overclock! Double score for ${rules.overclockTicks} ticks, but '
            'requests arrive faster.',
          );
        case Compacted():
          _setToast('Compacted. Arrivals kept coming while memory was packed.');
        default:
          break;
      }
    }
    _eventsSeen = events.length;
  }

  void _setToast(String text) {
    toast = text;
    _toastTicks = toastTicks;
  }

  void setPaused(bool value) {
    if (paused == value) return;
    paused = value;
    notifyListeners();
  }
}
