// The TestFlight release checklist in docs/ACCEPTANCE_TESTING.md, for the
// steps a widget test can drive: the first-run Game Center prompt, a run on
// every difficulty, and settings that survive a relaunch. Steps that need a
// store account or a real ad SDK (sandbox purchase, real ads, Game Center
// sign-in) stay manual.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/engine/engine.dart';
import 'package:memory_survival/game/game_controller.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/main.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:memory_survival/theme/game_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fresh app instance over whatever is in (mock) storage: a relaunch.
AppServices _launch() => AppServices(
  consent: FakeConsentService(),
  entitlement: FakeEntitlementService(),
  ads: FakeAdService(),
  auth: FakePlatformGameAuthService(),
  progress: FakeGameCenterProgressService(),
  openUrl: (_) async {},
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('1. Fresh install', () {
    testWidgets('Game Center is offered once; Not now reaches Home', (
      tester,
    ) async {
      final first = _launch();
      await first.initialize();
      await tester.pumpWidget(MemorySurvivalApp(services: first));
      await tester.pumpAndSettle();
      expect(find.text('Connect to Game Center?'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);

      // A relaunch does not ask again.
      await tester.pumpWidget(const SizedBox());
      final second = _launch();
      await second.initialize();
      await tester.pumpWidget(MemorySurvivalApp(services: second));
      await tester.pumpAndSettle();
      expect(find.text('Connect to Game Center?'), findsNothing);
      expect(find.text('Play'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('2. An endless run on each difficulty', () {
    for (final d in Difficulty.values) {
      testWidgets('${d.label}: the run ends and explains the final fault', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final services = _launch();
        await services.initialize();
        await services.difficulty.set(d);
        await tester.pumpWidget(MemorySurvivalApp(services: services));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Play'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start playing'));
        await tester.pump();
        for (
          var i = 0;
          i < 900 && find.text('Run over').evaluate().isEmpty;
          i++
        ) {
          await tester.pump(baseTickDuration);
        }
        await tester.pump();
        expect(find.text('Run over'), findsOneWidget);
        expect(find.textContaining('The last fault'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('7. Settings persist across a relaunch', () {
    test(
      'palette, difficulty, relaxed clock and suggestions are remembered',
      () async {
        final before = _launch();
        await before.initialize();
        await before.difficulty.set(Difficulty.hard);
        await before.relaxedClock.set(true);
        await before.suggestions.set(true);
        final palette = GameThemeId.values.firstWhere(
          (id) => id != before.theme.value,
        );
        await before.theme.select(palette);

        final after = _launch();
        await after.initialize();
        expect(after.difficulty.value, Difficulty.hard);
        expect(after.relaxedClock.value, isTrue);
        expect(after.suggestions.value, isTrue);
        expect(after.theme.value, palette);
      },
    );

    test('the best score is kept per difficulty across a relaunch', () async {
      final before = _launch();
      await before.initialize();
      await before.difficulty.set(Difficulty.normal);
      await before.bestScore.submit(1234, difficulty: Difficulty.normal);
      await before.bestScore.submit(99, difficulty: Difficulty.easy);

      final after = _launch();
      await after.initialize();
      await after.difficulty.set(Difficulty.normal);
      expect(after.bestScore.value, 1234);
      await after.difficulty.set(Difficulty.easy);
      expect(after.bestScore.value, 99);
    });
  });
}
