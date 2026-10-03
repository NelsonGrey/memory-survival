// Balance simulation: how long do simple placement policies survive?
// Run: dart run tool/balance.dart
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:memory_survival/engine/engine.dart';

typedef Policy = MemoryState Function(MemoryEngine e, MemoryState s, Random r);

MemoryState _placeAll(
  MemoryEngine e,
  MemoryState s,
  int? Function(MemoryState, Request) pick,
) {
  final queue = [...s.requestQueue]..sort((a, b) => a.deadline - b.deadline);
  for (final req in queue) {
    final start = pick(s, req);
    if (start == null) continue;
    final placed = e.place(s, req.id, start);
    if (placed.isOk) s = placed.state!;
  }
  return s;
}

int? firstFit(MemoryState s, Request r) {
  for (final g in s.gaps) {
    if (g.size >= r.size) return g.start;
  }
  return null;
}

int? bestFit(MemoryState s, Request r) {
  Gap? best;
  for (final g in s.gaps) {
    if (g.size >= r.size && (best == null || g.size < best.size)) best = g;
  }
  return best?.start;
}

/// Packs short-lived processes to the high end and long-lived to the low end.
int? lifetimeAware(MemoryState s, Request r) {
  Gap? best;
  for (final g in s.gaps) {
    if (g.size >= r.size && (best == null || g.size < best.size)) best = g;
  }
  if (best == null) return null;
  return r.lifetime <= 5 ? best.end - r.size : best.start;
}

Policy greedy(
  int? Function(MemoryState, Request) pick, {
  bool compact = false,
}) => (e, s, rnd) {
  s = _placeAll(e, s, pick);
  if (compact &&
      s.requestQueue.isNotEmpty &&
      s.freeCells >= s.requestQueue.first.size) {
    final r = e.compact(s);
    if (r.isOk) s = _placeAll(e, r.state!, pick);
  }
  return s;
};

Policy randomValid = (e, s, rnd) {
  for (final req in [...s.requestQueue]) {
    final starts = [
      for (var i = 0; i + req.size <= s.cellCount; i++)
        if (e.validate(s, req, i) == null) i,
    ];
    if (starts.isNotEmpty) {
      s = e.place(s, req.id, starts[rnd.nextInt(starts.length)]).state!;
    }
  }
  return s;
};

List<int> run(Ruleset rules, Policy policy, {int seeds = 300, int cap = 400}) {
  final e = MemoryEngine(rules);
  final out = <int>[];
  for (var seed = 0; seed < seeds; seed++) {
    final gen = RequestGenerator(rules, seed);
    final rnd = Random(seed);
    var s = e.initial(seed: seed);
    while (s.status == RunStatus.playing && s.cycle < cap) {
      s = policy(e, s, rnd);
      s = e.tick(s, arrivals: gen.arrivalsFor(s.cycle + 1));
    }
    out.add(s.cycle);
  }
  out.sort();
  return out;
}

String summary(List<int> v) =>
    'p10 ${v[v.length ~/ 10]}  median ${v[v.length ~/ 2]}  p90 ${v[v.length * 9 ~/ 10]}  '
    'survived-cap ${(100 * v.where((x) => x >= 400).length / v.length).round()}%';

void main(List<String> args) {
  final configs = <String, Ruleset>{'default': const Ruleset()};
  final policies = <String, Policy>{
    'random-valid': randomValid,
    'first-fit': greedy(firstFit),
    'best-fit': greedy(bestFit),
    'lifetime-aware': greedy(lifetimeAware),
    'first-fit+compact': greedy(firstFit, compact: true),
    'lifetime+compact': greedy(lifetimeAware, compact: true),
  };
  for (final c in configs.entries) {
    print('== ${c.key}');
    for (final p in policies.entries) {
      print('  ${p.key.padRight(18)} ${summary(run(c.value, p.value))}');
    }
  }
}
