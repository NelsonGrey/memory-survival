import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/engine/engine.dart';
import 'package:memory_survival/game/explain.dart';
import 'package:memory_survival/game/game_controller.dart';
import 'package:memory_survival/game/game_screen.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppServices fakeServices() => AppServices(
  consent: FakeConsentService(),
  entitlement: FakeEntitlementService(),
  ads: FakeAdService(),
  auth: FakePlatformGameAuthService(),
  progress: FakeGameCenterProgressService(),
  openUrl: (_) async {},
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GameController', () {
    test('selects the oldest request and places it', () {
      final g = GameController(rules: const Ruleset(), seed: 3);
      while (g.state.requestQueue.isEmpty) {
        g.tick();
      }
      final first = g.state.requestQueue.first;
      expect(g.selected!.id, first.id);
      expect(g.fittingGaps, isNotEmpty);
      expect(g.placeAt(0), isTrue);
      expect(g.state.processes.single.id, first.id);
    });

    test('explains an invalid placement and keeps the request', () {
      final g = GameController(rules: const Ruleset(cellCount: 4), seed: 3);
      while (g.state.requestQueue.isEmpty) {
        g.tick();
      }
      final size = g.selected!.size;
      expect(g.placeAt(4 - size + 1), isFalse);
      expect(g.message, contains('past the end'));
      expect(g.state.requestQueue, isNotEmpty);
    });

    test('paused controller ignores ticks and actions', () {
      final g = GameController(rules: const Ruleset(), seed: 3)
        ..setPaused(true);
      g.tick();
      expect(g.state.cycle, 0);
    });

    test('an unattended run ends with a failure', () {
      final g = GameController(rules: const Ruleset(), seed: 3);
      for (var i = 0; i < 2000 && g.isPlaying; i++) {
        g.tick();
      }
      expect(g.isPlaying, isFalse);
      expect(explainFailure(g.state.failure!, g.rules), isNotEmpty);
    });
  });

  group('GameScreen', () {
    testWidgets('banner is hidden while playing, shown when paused', (
      tester,
    ) async {
      final services = fakeServices();
      await services.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(services: services, seed: 3, autoTick: false),
        ),
      );
      expect(find.text('Waiting for a request…'), findsOneWidget);
      expect(find.text('Paused'), findsNothing);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(find.text('Paused'), findsNothing);
    });

    testWidgets('tapping a gap button places the waiting request', (
      tester,
    ) async {
      final services = fakeServices();
      await services.initialize();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(services: services, seed: 3)),
      );
      for (
        var i = 0;
        i < 5 && find.textContaining('lives').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(baseTickDuration);
      }
      expect(find.textContaining('lives'), findsWidgets);
      final before = find.textContaining('lives').evaluate().length;
      await tester.tap(find.textContaining('Cells ').first);
      await tester.pump();
      expect(find.textContaining('lives').evaluate().length, lessThan(before));
      // Leave the screen so the periodic timer is disposed.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
