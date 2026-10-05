import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/engine/engine.dart';
import 'package:memory_survival/game/game_controller.dart';
import 'package:memory_survival/game/game_screen.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/gamecenter/game_center_connection.dart';
import 'package:memory_survival/gamecenter/game_center_progress_service.dart';
import 'package:memory_survival/main.dart';
import 'package:memory_survival/screens/scenario_select_screen.dart';
import 'package:memory_survival/screens/settings_screen.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

FakeGameCenterProgressService? lastProgress;

AppServices fakeServices({bool connected = false}) {
  final progress = FakeGameCenterProgressService();
  lastProgress = progress;
  return AppServices(
    connection: connected ? GameCenterConnection.connectedFake() : null,
    consent: FakeConsentService(),
    entitlement: FakeEntitlementService(),
    ads: FakeAdService(),
    auth: FakePlatformGameAuthService(),
    progress: progress,
    openUrl: (_) async {},
  );
}

/// A scenario that finishes in two ticks with nothing arriving.
const quickScenario = Scenario(
  id: 'c1-01',
  chapter: 1,
  number: 1,
  title: 'Quick test',
  lesson: 'Finishes at once.',
  rules: Ruleset(
    cellCount: 8,
    wavePeriod: 0,
    goalTicks: 2,
    arrivalPerMille: 0,
    arrivalMaxPerMille: 0,
  ),
  seed: 1,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Home', () {
    testWidgets('offers Play, Daily run and Scenarios', (tester) async {
      final services = fakeServices();
      await tester.pumpWidget(MemorySurvivalApp(services: services));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Daily run'), findsOneWidget);
      expect(find.text('Scenarios'), findsOneWidget);
    });

    testWidgets('the daily run shows today and uses the shared seed', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'onboarding.howToPlaySeen': true,
      });
      final services = fakeServices();
      await tester.pumpWidget(MemorySurvivalApp(services: services));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily run'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.textContaining('Daily ${services.daily.dayKey}'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Game screen', () {
    testWidgets('shows the clean-run multiplier and the forecast', (
      tester,
    ) async {
      final services = fakeServices();
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(services: services, seed: 3, autoTick: false),
        ),
      );
      expect(find.textContaining('Clean run ×1'), findsOneWidget);
      expect(find.text('Coming up'), findsOneWidget);
      expect(find.textContaining('Wave 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('offers Start and End options and marks valid starts', (
      tester,
    ) async {
      final services = fakeServices();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(services: services, seed: 3)),
      );
      for (
        var i = 0;
        i < 8 && find.textContaining('· cells').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(baseTickDuration);
      }
      expect(find.textContaining('Start · cells'), findsWidgets);
      expect(find.textContaining('biggest gap after'), findsWidgets);
      expect(find.textContaining('▸'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the suggestion button appears only when enabled', (
      tester,
    ) async {
      final services = fakeServices();
      await services.suggestions.set(true);
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(services: services, seed: 3)),
      );
      for (
        var i = 0;
        i < 8 && find.textContaining('Suggested').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(baseTickDuration);
      }
      expect(find.textContaining('Suggested: cell'), findsOneWidget);
      expect(find.textContaining('no multiplier'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the first placement unlocks its achievement', (tester) async {
      final services = fakeServices(connected: true);
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(services: services, seed: 3)),
      );
      for (
        var i = 0;
        i < 8 && find.textContaining('· cells').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(baseTickDuration);
      }
      expect(lastProgress!.unlockedAchievements, isEmpty);
      await tester.tap(find.textContaining('· cells').first);
      await tester.pump();
      expect(lastProgress!.unlockedAchievements, [
        GameCenterIds.achievementFirstAllocation,
      ]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('overclock and compaction controls are present', (
      tester,
    ) async {
      final services = fakeServices();
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(services: services, seed: 3, autoTick: false),
        ),
      );
      expect(find.text('Overclock'), findsOneWidget);
      expect(find.textContaining('traffic continues'), findsOneWidget);
      await tester.tap(find.text('Overclock'));
      await tester.pump();
      expect(find.textContaining('Overclock 10'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Scenario runs', () {
    testWidgets('a finished scenario shows its objectives and saves stars', (
      tester,
    ) async {
      final services = fakeServices();
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            services: services,
            mode: RunMode.scenario,
            scenario: quickScenario,
          ),
        ),
      );
      await tester.pump(baseTickDuration);
      await tester.pump(baseTickDuration);
      await tester.pump();
      expect(find.text('Scenario complete'), findsOneWidget);
      expect(find.textContaining('Survive:'), findsOneWidget);
      expect(find.textContaining('Tidy:'), findsOneWidget);
      expect(find.textContaining('Clean:'), findsOneWidget);
      expect(find.textContaining('(new!)'), findsNWidgets(3));
      expect(services.scenarioProgress.starsFor('c1-01'), 3);
      expect(services.scenarioProgress.isUnlocked('c1-02'), isTrue);
      expect(find.text('Next scenario'), findsOneWidget);
      // A scenario never touches the endless leaderboard.
      expect(lastProgress!.submittedScores, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an unplayed scenario fails with an explanation', (
      tester,
    ) async {
      final services = fakeServices();
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            services: services,
            mode: RunMode.scenario,
            scenario: scenarioById('c1-03')!,
          ),
        ),
      );
      for (
        var i = 0;
        i < 80 && find.text('Scenario failed').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(baseTickDuration);
      }
      expect(find.text('Scenario failed'), findsOneWidget);
      expect(find.textContaining('The last fault'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(services.scenarioProgress.starsFor('c1-03'), 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the scenario list shows chapters, stars and locks', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final services = fakeServices();
      await services.scenarioProgress.record('c1-01', {
        Objective.survive,
        Objective.tidy,
      });
      await tester.pumpWidget(
        MaterialApp(home: ScenarioSelectScreen(services: services)),
      );
      expect(find.text('Chapter 1: Contiguous cells'), findsOneWidget);
      expect(find.text('1. First steps'), findsOneWidget);
      expect(find.text('2. Wider requests'), findsOneWidget);
      expect(find.textContaining('2 of 108 stars'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      expect(find.byIcon(Icons.star), findsNWidgets(2));
      await tester.tap(find.text('1. First steps'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('C1-01 · First steps'), findsOneWidget);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a locked scenario cannot be started', (tester) async {
      final services = fakeServices();
      await tester.pumpWidget(
        MaterialApp(home: ScenarioSelectScreen(services: services)),
      );
      expect(find.text('Clear the previous scenario to unlock'), findsWidgets);
      await tester.tap(find.text('3. Short queue'));
      await tester.pump();
      expect(find.byType(GameScreen), findsNothing);
    });
  });

  group('Run records', () {
    testWidgets('an endless run submits to the versioned leaderboard', (
      tester,
    ) async {
      final services = fakeServices(connected: true);
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(services: services, seed: 3)),
      );
      for (
        var i = 0;
        i < 400 && find.text('Run over').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(baseTickDuration);
      }
      expect(find.text('Run over'), findsOneWidget);
      await tester.pump();
      expect(find.textContaining('Longest clean run'), findsOneWidget);
      final score = services.bestScore.value;
      expect(lastProgress!.submittedScores, [score]);
      expect(lastProgress!.submittedLeaderboards, [
        'memory_survival_endless_score_v${Ruleset.currentVersion}',
      ]);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Settings', () {
    testWidgets('locked palettes show how to earn them', (tester) async {
      final services = fakeServices();
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(services: services)),
      );
      expect(
        find.textContaining('Locked: Reach a clean-run streak'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Locked: Earn 20 scenario stars'),
        findsOneWidget,
      );
      await tester.tap(find.textContaining('Locked: Earn 20'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(services.theme.value.name, isNot('forest'));
    });

    testWidgets('the suggestion switch persists the setting', (tester) async {
      final services = fakeServices();
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(services: services)),
      );
      await tester.scrollUntilVisible(
        find.text('Suggested placement'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Suggested placement'));
      await tester.pump();
      expect(services.suggestions.value, isTrue);
    });
  });

  group('Layout', () {
    for (final size in const [Size(360, 640), Size(390, 844), Size(430, 932)]) {
      testWidgets(
        'a long run fits a ${size.width.toInt()}x${size.height.toInt()} phone',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final services = fakeServices();
          await services.suggestions.set(true);
          await tester.pumpWidget(
            MaterialApp(
              home: GameScreen(
                services: services,
                seed: 11,
                // Plenty of lives so the run lasts through a storm and the
                // families that unlock after it.
                rules: const Ruleset(lives: 99, maxQueue: 6),
              ),
            ),
          );
          // Place the oldest request whenever the options are showing, so the
          // strip fills with blocks of every family while the run advances.
          for (var i = 0; i < 90; i++) {
            await tester.pump(baseTickDuration);
            final opt = find.textContaining('· cells');
            if (opt.evaluate().isNotEmpty) {
              await tester.tap(opt.first, warnIfMissed: false);
              await tester.pump();
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets('the results card fits a small phone', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final services = fakeServices();
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            services: services,
            mode: RunMode.scenario,
            scenario: quickScenario,
          ),
        ),
      );
      await tester.pump(baseTickDuration);
      await tester.pump(baseTickDuration);
      await tester.pump();
      expect(find.text('Scenario complete'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('home and settings fit a small phone', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final services = fakeServices();
      await tester.pumpWidget(MemorySurvivalApp(services: services));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
