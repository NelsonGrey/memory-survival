import 'dart:math';

import 'generator.dart';
import 'memory_engine.dart';
import 'model.dart';
import 'ruleset.dart';

/// Picks a start address for a request, or null to leave it waiting.
typedef Picker = int? Function(MemoryEngine e, MemoryState s, Request r);

/// A simple scripted player. Used by the balance tool and by scenario
/// solvability checks, never by the app itself.
class Bot {
  const Bot(
    this.name,
    this.pick, {
    this.compacts = false,
    this.cleansLeaks = false,
    this.perTick = 1 << 30,
  });

  final String name;
  final Picker pick;

  /// Whether it compacts when memory is free in total but split.
  final bool compacts;

  /// Whether it cleans up leaks when memory runs short.
  final bool cleansLeaks;

  /// Most placements per tick. A person taps roughly one request a tick, so
  /// a limit of 1 models a human far better than placing everything at once.
  final int perTick;

  MemoryState act(MemoryEngine e, MemoryState s, ArrivalSource arrivals) {
    s = _placeAll(e, s);
    if (cleansLeaks && s.requestQueue.isNotEmpty) {
      for (final p in s.processes) {
        if (p.isNormal && p.releasePolicy == ReleasePolicy.leak) {
          final r = e.cleanup(s, p.id);
          if (r.isOk) {
            s = _placeAll(e, r.state!);
          }
          break;
        }
      }
    }
    if (compacts &&
        s.requestQueue.isNotEmpty &&
        s.compactionsLeft > 0 &&
        s.freeCells >= s.requestQueue.first.size &&
        s.largestFreeBlock < s.requestQueue.first.size) {
      final r = e.compact(s, arrivals: arrivals);
      if (r.isOk) s = _placeAll(e, r.state!);
    }
    return s;
  }

  MemoryState _placeAll(MemoryEngine e, MemoryState s) {
    // Linked pairs first so the second half can still sit beside the first.
    final queue = [...s.requestQueue]
      ..sort(
        (a, b) =>
            a.deadline != b.deadline ? a.deadline - b.deadline : a.id - b.id,
      );
    var left = perTick;
    for (final req in queue) {
      if (left <= 0) break;
      if (s.requestById(req.id) == null) continue;
      left--;
      if (req.family == RequestFamily.linked) {
        s = _placePair(e, s, req);
        continue;
      }
      final start = pick(e, s, req);
      if (start == null) continue;
      final placed = e.place(s, req.id, start);
      if (placed.isOk) s = placed.state!;
    }
    return s;
  }

  /// Places both halves of a linked pair together, once both are waiting;
  /// a lone leader waits for its partner while it still can.
  MemoryState _placePair(MemoryEngine e, MemoryState s, Request req) {
    final Request? leader;
    final Request? follower;
    if (req.linkedWith == null) {
      leader = req;
      follower = [
        for (final r in s.requestQueue)
          if (r.linkedWith == req.id) r,
      ].firstOrNull;
    } else {
      leader = s.requestById(req.linkedWith!);
      follower = req;
    }
    if (leader == null || follower == null) {
      // Partner not here yet (or already gone): place on its own, or wait.
      if (leader != null && follower == null && leader.deadline > 2) return s;
      final start = pick(e, s, req);
      if (start == null) return s;
      final placed = e.place(s, req.id, start);
      return placed.isOk ? placed.state! : s;
    }
    final total = leader.size + follower.size;
    final gaps = [
      for (final g in s.gaps)
        if (g.size >= total) g,
    ]..sort((a, b) => a.size.compareTo(b.size));
    for (final g in gaps) {
      final first = e.place(s, leader.id, g.start);
      if (!first.isOk) continue;
      final second = e.place(first.state!, follower.id, g.start + leader.size);
      if (second.isOk) return second.state!;
    }
    return s;
  }
}

/// Runs [bot] on [seed] until the run ends or [cap] ticks pass.
MemoryState playBot(Ruleset rules, Bot bot, int seed, {int cap = 600}) {
  final e = MemoryEngine(rules);
  final gen = RequestGenerator(rules, seed);
  var s = e.initial(seed: seed);
  while (s.status == RunStatus.playing && s.cycle < cap) {
    s = bot.act(e, s, gen.arrivalsFor);
    s = e.tick(s, arrivals: gen.arrivalsFor(s.cycle + 1));
  }
  return s;
}

/// Gap starts and ends the request fits in, tightest gap first, skipping
/// placements the linked-pair rule forbids.
List<int> _candidates(MemoryEngine e, MemoryState s, Request r) {
  final gaps = [
    for (final g in s.gaps)
      if (g.size >= r.size) g,
  ]..sort((a, b) => a.size.compareTo(b.size));
  return [
    for (final g in gaps) ...[g.start, g.end - r.size],
  ].where((st) => e.validate(s, r, st) == null).toList();
}

int? _firstFit(MemoryEngine e, MemoryState s, Request r) {
  for (final g in s.gaps) {
    if (g.size >= r.size && e.validate(s, r, g.start) == null) return g.start;
  }
  // A linked partner may need the far edge of a gap.
  final c = _candidates(e, s, r);
  return c.isEmpty ? null : c.first;
}

int? _bestFit(MemoryEngine e, MemoryState s, Request r) {
  final c = _candidates(e, s, r);
  return c.isEmpty ? null : c.first;
}

/// Packs short-lived processes to the high end of a gap and long-lived ones
/// to the low end, so gaps close up as the short ones leave.
int? _lifetimeAware(MemoryEngine e, MemoryState s, Request r) {
  final c = _candidates(e, s, r);
  if (c.isEmpty) return null;
  final wantsEnd = r.lifetime <= 5;
  for (final start in c) {
    for (final g in s.gaps) {
      final atEnd = start == g.end - r.size;
      final atStart = start == g.start;
      if (start >= g.start && start + r.size <= g.end) {
        if (wantsEnd ? atEnd : atStart) return start;
      }
    }
  }
  return c.first;
}

int? _suggested(MemoryEngine e, MemoryState s, Request r) =>
    e.recommendedStart(s, r);

Bot randomBot(int seed) {
  final rnd = Random(seed);
  return Bot('random-valid', (e, s, r) {
    final starts = e.validStarts(s, r);
    return starts.isEmpty ? null : starts[rnd.nextInt(starts.length)];
  });
}

final firstFit = Bot('first-fit', _firstFit);
final bestFit = Bot('best-fit', _bestFit);
final lifetimeAware = Bot('lifetime-aware', _lifetimeAware);
final tidy = Bot('tidy', _suggested);
final firstFitCompact = Bot('first-fit+compact', _firstFit, compacts: true);
final lifetimeCompact = Bot(
  'lifetime+compact',
  _lifetimeAware,
  compacts: true,
  cleansLeaks: true,
);

/// Scripted stand-ins for a careful and a casual player: one placement per
/// tick, with compaction as a last resort.
final humanCareful = Bot(
  'human-careful',
  _lifetimeAware,
  compacts: true,
  cleansLeaks: true,
  perTick: 1,
);
final humanCasual = Bot('human-casual', _firstFit, perTick: 1);

final tidyCompact = Bot(
  'tidy+compact',
  _suggested,
  compacts: true,
  cleansLeaks: true,
);

/// Every scripted policy, for solvability checks.
List<Bot> get allBots => [
  tidy,
  bestFit,
  lifetimeAware,
  firstFit,
  tidyCompact,
  lifetimeCompact,
  firstFitCompact,
];
