import 'ruleset.dart';

/// Where a run sits in the repeating pressure-wave cycle:
/// calm traffic, a warning countdown, a short allocation storm, then a
/// recovery window with no arrivals before the next, harder wave.
enum WavePhase { calm, warning, storm, recovery }

class WaveInfo {
  const WaveInfo({
    required this.phase,
    required this.number,
    required this.ticksToStorm,
    required this.ticksLeftInStorm,
  });

  final WavePhase phase;

  /// The wave being approached or fought, counting from 1.
  final int number;

  /// Ticks until the storm begins; 0 once it has.
  final int ticksToStorm;

  /// Ticks of storm still to come, including this one; 0 outside a storm.
  final int ticksLeftInStorm;
}

/// The wave phase for [cycle]. Pure and shared by the generator (which
/// shapes arrivals) and the engine (which pays out surviving a wave), so
/// both always agree. A [Ruleset.wavePeriod] of 0 turns waves off.
WaveInfo waveAt(Ruleset rules, int cycle) {
  final period = rules.wavePeriod;
  if (period <= 0) {
    return const WaveInfo(
      phase: WavePhase.calm,
      number: 1,
      ticksToStorm: 0,
      ticksLeftInStorm: 0,
    );
  }
  final pos = cycle % period;
  final number = cycle ~/ period + 1;
  final stormStart = period - rules.stormTicks;
  final warnStart = stormStart - rules.warningTicks;
  final WavePhase phase;
  if (pos >= stormStart) {
    phase = WavePhase.storm;
  } else if (pos >= warnStart) {
    phase = WavePhase.warning;
  } else if (cycle >= period && pos < rules.recoveryTicks) {
    phase = WavePhase.recovery;
  } else {
    phase = WavePhase.calm;
  }
  return WaveInfo(
    phase: phase,
    number: number,
    ticksToStorm: pos < stormStart ? stormStart - pos : 0,
    ticksLeftInStorm: pos >= stormStart ? period - pos : 0,
  );
}
