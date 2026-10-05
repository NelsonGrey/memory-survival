// Balance simulation: how long do simple placement policies survive?
// Run: dart run tool/balance.dart
// ignore_for_file: avoid_print
import 'package:memory_survival/engine/engine.dart';

String summary(List<MemoryState> runs) {
  int pct(List<int> v, double q) =>
      v[(v.length * q).floor().clamp(0, v.length - 1)];
  final cycles = [for (final r in runs) r.cycle]..sort();
  final points = [for (final r in runs) r.score.points]..sort();
  final waves = [for (final r in runs) r.score.wavesCleared]..sort();
  return 'ticks p10 ${pct(cycles, .1)} med ${pct(cycles, .5)} p90 ${pct(cycles, .9)}'
      ' | pts med ${pct(points, .5)} | waves med ${pct(waves, .5)} p90 ${pct(waves, .9)}';
}

void main(List<String> args) {
  final rules = const Ruleset();
  print('== default (version ${Ruleset.currentVersion})');
  for (final bot in [randomBot(1), ...allBots]) {
    final runs = [
      for (var seed = 0; seed < 300; seed++) playBot(rules, bot, seed),
    ];
    print('  ${bot.name.padRight(18)} ${summary(runs)}');
  }
}
