import 'model.dart';
import 'ruleset.dart';
import 'wave.dart';

/// Version of the pseudo-random algorithm below. Stored alongside the seed
/// and ruleset version so a run can always be reproduced.
const generatorVersion = 3;

/// A forecast arrival: what is coming, and in how many ticks.
class Upcoming {
  const Upcoming(this.ticksAway, this.request);
  final int ticksAway;
  final Request request;
}

/// Stateless seeded request generator: the arrival for a given tick depends
/// only on (seed, ruleset, tick, overclock), never on call order, so a run
/// can be replayed or resumed from any point.
///
/// Uses 32-bit integer mixing that relies on 64-bit native ints, which holds
/// on iOS and Android (the only targets).
class RequestGenerator {
  const RequestGenerator(this.rules, this.seed);

  final Ruleset rules;
  final int seed;

  /// The request arriving on [cycle], if any. Its id is the cycle number.
  /// [overclocked] raises the arrival chance without disturbing any other
  /// draw, so the same tick yields the same request, just more often.
  Request? arrivalAt(int cycle, {bool overclocked = false}) {
    // The second half of a linked pair always arrives right after the first.
    if (cycle > 0 && _isLinkLeader(cycle - 1, overclocked: overclocked)) {
      return _build(cycle, _Draws(this, cycle), follower: true);
    }
    final d = _Draws(this, cycle);
    if (d.arrive >= _chance(cycle, overclocked)) return null;
    return _build(cycle, d);
  }

  List<Request> arrivalsFor(int cycle, {bool overclocked = false}) {
    final r = arrivalAt(cycle, overclocked: overclocked);
    return r == null ? const [] : [r];
  }

  /// The next [count] arrivals after [cycle], looking up to [horizon] ticks
  /// ahead.
  List<Upcoming> upcoming(
    int cycle, {
    int count = 2,
    int horizon = 10,
    bool overclocked = false,
  }) {
    final out = <Upcoming>[];
    for (var t = 1; t <= horizon && out.length < count; t++) {
      final r = arrivalAt(cycle + t, overclocked: overclocked);
      if (r != null) out.add(Upcoming(t, r));
    }
    return out;
  }

  int _chance(int cycle, bool overclocked) {
    final w = waveAt(rules, cycle);
    final waves = w.number - 1;
    final int base;
    switch (w.phase) {
      case WavePhase.recovery:
        return 0;
      case WavePhase.storm:
        base = rules.stormPerMille + rules.stormRampPerMille * waves;
      case WavePhase.warning:
      case WavePhase.calm:
        base = (rules.arrivalPerMille + rules.arrivalRampPerMille * waves)
            .clamp(0, rules.arrivalMaxPerMille);
    }
    return (base + (overclocked ? rules.overclockBonusPerMille : 0)).clamp(
      0,
      1000,
    );
  }

  /// Families a request on [cycle] may belong to.
  List<RequestFamily> _available(int cycle) {
    final unlocked = rules.progressiveFamilies
        ? familyUnlockOrder.take(waveAt(rules, cycle).number - 1)
        : familyUnlockOrder;
    return [
      for (final f in unlocked)
        if (rules.families.contains(f)) f,
    ];
  }

  RequestFamily _family(int cycle, _Draws d) {
    if (d.family >= rules.familyPerMille) return RequestFamily.standard;
    final options = _available(cycle);
    if (options.isEmpty) return RequestFamily.standard;
    return options[d.pick % options.length];
  }

  bool _isLinkLeader(int cycle, {required bool overclocked}) {
    if (cycle <= 0) return false;
    final d = _Draws(this, cycle);
    if (d.arrive >= _chance(cycle, overclocked)) return false;
    if (_family(cycle, d) != RequestFamily.linked) return false;
    // A request that is itself the second half of a pair cannot lead one.
    return !_isLinkLeader(cycle - 1, overclocked: overclocked);
  }

  Request _build(int cycle, _Draws d, {bool follower = false}) {
    var family = follower ? RequestFamily.linked : _family(cycle, d);
    var size = rules.minSize + d.size % (rules.maxSize - rules.minSize + 1);
    var life =
        rules.minLifetime +
        d.life % (rules.maxLifetime - rules.minLifetime + 1);
    var deadline = rules.requestDeadline;
    int? lifeMin;
    int? lifeMax;
    switch (family) {
      case RequestFamily.burst:
        size = (rules.maxSize - d.extra % 2).clamp(
          rules.minSize,
          rules.maxSize,
        );
        life = rules.minLifetime + d.extra ~/ 2 % 2;
      case RequestFamily.resident:
        size = (rules.minSize + d.extra % 2).clamp(
          rules.minSize,
          rules.maxSize,
        );
        life = rules.maxLifetime + d.extra ~/ 2 % 3;
      case RequestFamily.priority:
        deadline = (rules.requestDeadline - 3).clamp(
          rules.minDeadline,
          rules.requestDeadline,
        );
      case RequestFamily.volatile:
        final off = d.extra % 3 - 1;
        lifeMin = (life - 2 + off).clamp(1, life);
        lifeMax = life + 2 + off;
        if (lifeMax < life) lifeMax = life;
      case RequestFamily.standard:
      case RequestFamily.pinned:
      case RequestFamily.linked:
      case RequestFamily.leak:
        break;
    }
    return Request(
      id: cycle,
      size: size,
      lifetime: life,
      deadline: deadline,
      family: family,
      releasePolicy: family == RequestFamily.leak
          ? ReleasePolicy.leak
          : ReleasePolicy.normal,
      pinned: family == RequestFamily.pinned,
      lifetimeMin: lifeMin,
      lifetimeMax: lifeMax,
      linkedWith: follower ? cycle - 1 : null,
    );
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

/// The fixed sequence of draws for one tick. Every field is always drawn in
/// the same order so adding behavior never shifts another draw.
class _Draws {
  _Draws(RequestGenerator g, int cycle) {
    var h = RequestGenerator._mix(g.seed ^ RequestGenerator._mix(cycle));
    int draw(int bound) {
      h = RequestGenerator._mix(h + 0x9E3779B9);
      return h % bound;
    }

    arrive = draw(1000);
    size = draw(1 << 16);
    life = draw(1 << 16);
    family = draw(1000);
    pick = draw(1 << 16);
    extra = draw(1 << 16);
  }

  late final int arrive;
  late final int size;
  late final int life;
  late final int family;
  late final int pick;
  late final int extra;
}
