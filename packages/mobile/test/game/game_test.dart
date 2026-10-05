import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/engine/engine.dart';
import 'package:memory_survival/game/explain.dart';
import 'package:memory_survival/game/game_controller.dart';
import 'package:memory_survival/game/game_screen.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/main.dart';
import 'package:memory_survival/settings/best_score.dart';
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

    test('a fault shows an explanation and costs a life', () {
      final g = GameController(rules: const Ruleset(), seed: 3);
      for (var i = 0; i < 2000 && g.state.faultCount == 0; i++) {
        g.tick();
      }
      expect(g.state.faultCount, 1);
      expect(g.state.livesLeft, g.rules.lives - 1);
      expect(g.faultNotice, contains('left.'));
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
        i < 8 && find.textContaining('Where should').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(baseTickDuration);
      }
      expect(find.textContaining('Where should'), findsOneWidget);
      await tester.tap(find.textContaining('· cells').first);
      await tester.pump();
      expect(find.textContaining('Where should'), findsNothing);
      // Leave the screen so the periodic timer is disposed.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Settings opens over a paused game until Resume', (
      tester,
    ) async {
      final services = fakeServices();
      await services.initialize();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(services: services, seed: 3)),
      );
      await tester.pump(baseTickDuration * 2);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);

      // Time passes while Settings is open; the game must not advance.
      await tester.pump(baseTickDuration * 5);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(find.text('Paused'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('first run', () {
    testWidgets('first Play shows instructions, then starts the game', (
      tester,
    ) async {
      final services = fakeServices();
      await tester.pumpWidget(MemorySurvivalApp(services: services));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Play'));

      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(find.text('How to play'), findsWidgets);
      expect(find.text('Start playing'), findsOneWidget);

      await tester.tap(find.text('Start playing'));
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(services.howToPlay.value, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('best score keeps only improvements and persists', () async {
    final best = BestScore();
    expect(await best.submit(40), isTrue);
    expect(await best.submit(25), isFalse);
    expect(best.value, 40);
    final again = BestScore();
    await again.load();
    expect(again.value, 40);
  });
}
