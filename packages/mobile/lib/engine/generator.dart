import 'model.dart';
import 'ruleset.dart';

/// Version of the pseudo-random algorithm below. Stored alongside the seed
/// and ruleset version so a run can always be reproduced.
const generatorVersion = 2;

/// Stateless seeded request generator: the arrival for a given tick depends
/// only on (seed, ruleset, tick), never on call order, so a run can be
/// replayed or resumed from any point.
///
/// Uses 32-bit integer mixing that relies on 64-bit native ints, which holds
/// on iOS and Android (the only targets).
class RequestGenerator {
  const RequestGenerator(this.rules, this.seed);

  final Ruleset rules;
  final int seed;

  /// The request arriving on [cycle], if any. Its id is the cycle number.
  Request? arrivalAt(int cycle) {
    var h = _mix(seed ^ _mix(cycle));
    int draw(int bound) {
      h = _mix(h + 0x9E3779B9);
      return h % bound;
    }

    final chance =
        (rules.arrivalPerMille + rules.arrivalRampPerMille * (cycle ~/ 100))
            .clamp(0, rules.arrivalMaxPerMille);
    if (draw(1000) >= chance) return null;
    final size = rules.minSize + draw(rules.maxSize - rules.minSize + 1);
    final lifetime =
        rules.minLifetime + draw(rules.maxLifetime - rules.minLifetime + 1);
    final leaks = draw(1000) < rules.leakPerMille;
    final pinned = draw(1000) < rules.pinnedPerMille;
    return Request(
      id: cycle,
      size: size,
      lifetime: lifetime,
      deadline: rules.requestDeadline,
      releasePolicy: leaks ? ReleasePolicy.leak : ReleasePolicy.normal,
      pinned: pinned,
    );
  }

  List<Request> arrivalsFor(int cycle) {
    final r = arrivalAt(cycle);
    return r == null ? const [] : [r];
  }

  static int _mix(int x) {
    x &= 0xFFFFFFFF;
    x ^= x >> 16;
    x = (x * 0x85EBCA6B) & 0xFFFFFFFF;
    x ^= x >> 13;
    x = (x * 0xC2B2AE35) & 0xFFFFFFFF;
    x ^= x >> 16;
    return x;
  }
}
