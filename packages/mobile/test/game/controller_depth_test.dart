import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/engine/engine.dart';
import 'package:memory_survival/game/game_controller.dart';

const quiet = Ruleset(cellCount: 12, wavePeriod: 0);

Request req(int id, int size, {int deadline = 6, int life = 5}) =>
    Request(id: id, size: size, lifetime: life, deadline: deadline);

MemoryProcess proc(int id, int start, int size, {int remaining = 9}) =>
    MemoryProcess(id: id, size: size, start: start, remaining: remaining);

/// A controller whose state is set by hand so choices are predictable.
GameController controller({
  Ruleset rules = quiet,
  bool suggestions = false,
  List<MemoryProcess> processes = const [],
  List<Request> requests = const [],
  int cycle = 0,
}) {
  final g = GameController(rules: rules, seed: 1, suggestions: suggestions);
  g.state = g.engine
      .initial(processes: processes, requests: requests)
      .copyWith(cycle: cycle);
  return g;
}

void main() {
  group('forecast', () {
    test('early waves show everything', () {
      final g = controller(rules: const Ruleset(), cycle: 3);
      final f = g.forecast;
      expect(f, isNotEmpty);
      expect(f.length, lessThanOrEqualTo(2));
      for (final item in f) {
        expect(item.detail, ForecastDetail.exact);
        expect(item.scrambled, isFalse);
        expect(item.shownSize, item.request.size);
        expect(item.lifetimeLabel, startsWith('lives'));
      }
    });

    test('mid-run it shows a lifetime band, not the exact lifetime', () {
      final g = controller(rules: const Ruleset(), cycle: 60);
      for (final item in g.forecast) {
        expect(item.detail, ForecastDetail.band);
        final label = item.lifetimeLabel;
        final m = RegExp(r'lives (\d+)–(\d+)').firstMatch(label)!;
        final lo = int.parse(m.group(1)!), hi = int.parse(m.group(2)!);
        expect(hi - lo, 2);
        expect(item.request.lifetime, inInclusiveRange(lo, hi));
        expect(item.tag, isNull);
      }
    });

    test('late in the run only the size is shown, sometimes scrambled', () {
      final seen = <bool>{};
      for (var cycle = 130; cycle < 400; cycle += 3) {
        final g = controller(rules: const Ruleset(), cycle: cycle);
        for (final item in g.forecast) {
          expect(item.detail, ForecastDetail.sizeOnly);
          expect(item.lifetimeLabel, isEmpty);
          expect(item.tag, isNull);
          seen.add(item.scrambled);
          if (item.scrambled) {
            expect(item.shownSize, isNull);
            expect(item.reservable, isFalse);
          } else {
            expect(item.shownSize, item.request.size);
            expect(item.reservable, isTrue);
          }
        }
      }
      expect(seen, {true, false});
    });

    test('the forecast matches what then arrives', () {
      final g = controller(rules: const Ruleset());
      final first = g.forecast.first;
      while (g.state.cycle < first.ticksAway) {
        g.tick();
      }
      expect(g.state.requestQueue.any((r) => r.id == first.id), isTrue);
    });
  });

  group('placement options', () {
    test('offer the start and the end of a roomy gap, with a preview', () {
      final g = controller(processes: [proc(1, 5, 2)], requests: [req(2, 3)]);
      final opts = g.placementOptions;
      expect(opts.map((o) => (o.start, o.label)), [
        (0, 'Start'),
        (2, 'End'),
        (7, 'Start'),
        (9, 'End'),
      ]);
      // Start of the left gap leaves 2 + the 5-cell tail as the biggest.
      expect(opts.first.largestFreeAfter, 5);
    });

    test('an exact fit is a single Fill option', () {
      final g = controller(processes: [proc(1, 3, 9)], requests: [req(2, 3)]);
      expect(g.placementOptions.single.label, 'Fill');
      expect(g.placementOptions.single.start, 0);
    });

    test('nothing is offered when nothing fits', () {
      final g = controller(
        processes: [proc(1, 3, 1), proc(2, 5, 1)],
        requests: [req(3, 9)],
      );
      expect(g.placementOptions, isEmpty);
      expect(g.validStarts, isEmpty);
    });

    test('valid starts match the engine', () {
      final g = controller(processes: [proc(1, 4, 2)], requests: [req(2, 3)]);
      expect(g.validStarts, {0, 1, 6, 7, 8, 9}.difference({}));
      expect(g.validStarts.contains(2), isFalse);
    });

    test('placing at an option places there', () {
      final g = controller(requests: [req(2, 3)]);
      expect(g.placeAt(g.placementOptions.last.start), isTrue);
      expect(g.state.processes.single.start, 9);
    });
  });

  group('suggestion', () {
    test('is hidden unless the setting is on', () {
      final off = controller(requests: [req(1, 2)]);
      expect(off.suggestedStart, isNull);
      expect(off.placeSuggested(), isFalse);
      final on = controller(suggestions: true, requests: [req(1, 2)]);
      expect(on.suggestedStart, isNotNull);
    });

    test('placing the suggestion is assisted and earns no streak', () {
      final g = controller(suggestions: true, requests: [req(1, 2, life: 1)]);
      expect(g.placeSuggested(), isTrue);
      expect(g.state.processes.single.assisted, isTrue);
      g.tick();
      expect(g.state.streak, 0);
      expect(g.state.score.completed, 1);
    });
  });

  group('actions', () {
    test('reject then a second reject in the same wave explains itself', () {
      final g = controller(
        rules: const Ruleset(cellCount: 12),
        requests: [req(1, 3), req(2, 3)],
      );
      g.reject(1);
      expect(g.state.requestQueue.single.id, 2);
      g.reject(2);
      expect(g.message, contains('Not available'));
      expect(g.state.requestQueue.single.id, 2);
    });

    test('overclock starts and notes it', () {
      final g = controller();
      g.overclock();
      expect(g.state.overclocked, isTrue);
      expect(g.toast, contains('Overclock'));
    });

    test('cleanup removes a leak and notes the lock', () {
      final g = controller(
        processes: [
          const MemoryProcess(
            id: 1,
            size: 4,
            start: 0,
            remaining: 1,
            releasePolicy: ReleasePolicy.leak,
          ),
        ],
      );
      g.cleanup(1);
      expect(g.state.processes.single.kind, ProcessKind.quarantine);
      expect(g.toast, contains('Leak cleaned up'));
      g.cleanup(1);
      expect(g.message, isNotNull);
    });

    test('reserving: pick a forecast, then a cell, and it is held', () {
      final g = controller(rules: const Ruleset(cellCount: 12));
      final item = g.forecast.first;
      g.beginReserve(item);
      expect(g.reserving, item);
      expect(g.message, contains('Tap the first cell'));
      // While reserving, valid starts are free runs of the forecast's size.
      g.state = g.state.copyWith(requestQueue: [req(99, 1)]);
      expect(g.validStarts, isNotEmpty);
      expect(g.placeAt(0), isTrue);
      expect(g.reserving, isNull);
      expect(g.state.reservation!.reservedFor, item.id);
      expect(g.state.reservation!.size, item.request.size);
    });

    test('cancelling a reserve leaves memory untouched', () {
      final g = controller(rules: const Ruleset(cellCount: 12));
      g.beginReserve(g.forecast.first);
      g.cancelReserve();
      expect(g.reserving, isNull);
      expect(g.state.reservation, isNull);
    });

    test('a scrambled forecast cannot be reserved', () {
      final g = controller(rules: const Ruleset(), cycle: 130);
      final scrambled = g.forecast.where((f) => f.scrambled);
      for (final item in scrambled) {
        g.beginReserve(item);
        expect(g.reserving, isNull);
      }
    });

    test('compaction keeps traffic coming and says so', () {
      final g = controller(
        rules: const Ruleset(
          cellCount: 12,
          wavePeriod: 0,
          arrivalPerMille: 1000,
          arrivalMaxPerMille: 1000,
        ),
        processes: [proc(1, 5, 2)],
      );
      g.compact();
      expect(g.state.requestQueue, isNotEmpty);
      expect(g.toast, contains('Arrivals kept coming'));
    });
  });

  group('explanations', () {
    test('a locked or held cell is not called a process', () {
      final g = controller(requests: [req(2, 3)]);
      g.state = g.state.copyWith(
        processes: [
          const MemoryProcess(
            id: -1,
            size: 1,
            start: 4,
            remaining: 5,
            kind: ProcessKind.quarantine,
          ),
        ],
      );
      expect(g.placeAt(3), isFalse);
      expect(g.message, contains('locked or held'));
      expect(g.message, isNot(contains('#-1')));
    });

    test('a linked pair explains the adjacency rule', () {
      final g = controller(
        requests: [
          const Request(
            id: 1,
            size: 2,
            lifetime: 5,
            deadline: 6,
            family: RequestFamily.linked,
          ),
          const Request(
            id: 2,
            size: 2,
            lifetime: 5,
            deadline: 6,
            family: RequestFamily.linked,
            linkedWith: 1,
          ),
        ],
      );
      g.placeAt(0);
      g.select(2);
      expect(g.placeAt(8), isFalse);
      expect(g.message, contains('side by side'));
      expect(g.message, contains('#1'));
    });
  });

  group('notes', () {
    test('clearing a wave shows a toast that then fades', () {
      final g = controller(rules: const Ruleset(cellCount: 12), cycle: 24);
      g.tick();
      expect(g.toast, contains('Wave 1 cleared'));
      for (var i = 0; i < toastTicks; i++) {
        g.tick();
      }
      expect(g.toast, isNull);
    });

    test('a fault notice explains the heat', () {
      final g = controller(
        rules: const Ruleset(cellCount: 12, wavePeriod: 0),
        requests: [req(1, 3, deadline: 1)],
      );
      g.tick();
      expect(g.faultNotice, contains('System heat 1'));
    });

    test('a completed goal ends the run', () {
      final g = controller(
        rules: const Ruleset(
          cellCount: 12,
          wavePeriod: 0,
          goalTicks: 2,
          arrivalPerMille: 0,
          arrivalMaxPerMille: 0,
        ),
      );
      g.tick();
      g.tick();
      expect(g.isCompleted, isTrue);
      expect(g.isPlaying, isFalse);
      g.tick();
      expect(g.state.cycle, 2);
    });
  });
}
