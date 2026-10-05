// Finds, for each scenario, the first seed a careful scripted player clears,
// and prints the `_seeds` map to paste into lib/engine/scenario.dart.
// Run: dart run tool/pick_scenario_seeds.dart
// ignore_for_file: avoid_print
import 'package:memory_survival/engine/engine.dart';

void main() {
  final out = StringBuffer('const _seeds = <int, int>{\n');
  for (final s in scenarios) {
    int? found;
    final base = 7000 + s.chapter * 100 + s.number;
    for (var seed = base; seed < base + 400 && found == null; seed++) {
      final end = playBot(s.rules, humanCareful, seed, cap: s.goalTicks + 5);
      if (end.status == RunStatus.completed) found = seed;
    }
    out.writeln('  ${s.chapter * 10 + s.number}: ${found ?? -1},');
  }
  out.writeln('};');
  print(out);
}
