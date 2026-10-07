// Automated acceptance tests, one group per business requirement in
// docs/BUSINESS_REQUIREMENTS.md (MAS-BR-nnn) or technical requirement in
// docs/TECHNICAL_REQUIREMENTS.md (MAS-TR-nnn). A requirement missing here
// needs human evidence instead: see docs/ACCEPTANCE_TESTING.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/engine/engine.dart';
import 'package:memory_survival/game/explain.dart';
import 'package:memory_survival/game/game_controller.dart';
import 'package:memory_survival/game/game_screen.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/gamecenter/game_center_connection.dart';
import 'package:memory_survival/main.dart';
import 'package:memory_survival/screens/scenario_select_screen.dart';
import 'package:memory_survival/screens/settings_screen.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _banner = Key('fake_banner_ad');

late FakeAdService _ads;
late FakeGameCenterProgressService _gameCenter;
late FakeEntitlementService _entitlement;

AppServices _services({bool connected = false}) {
  _ads = FakeAdService();
  _gameCenter = FakeGameCenterProgressService();
  _entitlement = FakeEntitlementService();
  return AppServices(
    connection: connected ? GameCenterConnection.connectedFake() : null,
    consent: FakeConsentService(),
    entitlement: _entitlement,
    ads: _ads,
    auth: FakePlatformGameAuthService(),
    progress: _gameCenter,
    openUrl: (_) async {},
  );
}

/// A scenario that finishes in two ticks with nothing arriving.
const _quickScenario = Scenario(
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

Future<void> _playUntilOver(WidgetTester tester, String banner) async {
  for (var i = 0; i < 400 && find.text(banner).evaluate().isEmpty; i++) {
    await tester.pump(baseTickDuration);
  }
  await tester.pump();
  expect(find.text(banner), findsOneWidget);
}

Future<void> _declineGameCenter(WidgetTester tester) async {
  await tester.tap(find.text('Not now'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MAS-BR-003 failures distinguish capacity from fragmentation', () {
    const engine = MemoryEngine(Ruleset(cellCount: 12, wavePeriod: 0));

    Request request(int size) => Request(
      id: 5,
      size: size,
      lifetime: 4,
      deadline: 1,
      family: RequestFamily.standard,
    );

    MemoryProcess process(int id, int start, int size) => MemoryProcess(
      id: id,
      size: size,
      start: start,
      remaining: 99,
      releasePolicy: ReleasePolicy.normal,
    );

    test('a full memory is reported as capacity', () {
      final s = engine.tick(
        engine.initial(processes: [process(1, 0, 9)], requests: [request(4)]),
      );
      expect(s.failure!.kind, FailureKind.capacity);
      expect(
        explainFailure(s.failure!, engine.rules),
        contains('Memory was simply full'),
      );
    });

    test('enough free cells in pieces is reported as fragmentation', () {
      final s = engine.tick(
        engine.initial(
          processes: [process(1, 2, 1), process(2, 5, 1), process(3, 8, 1)],
          requests: [request(4)],
        ),
      );
      expect(s.failure!.kind, FailureKind.fragmentation);
      expect(
        explainFailure(s.failure!, engine.rules),
        contains('fragmentation'),
      );
    });
  });

  group('MAS-BR-004 compaction has a visible cost', () {
    const rules = Ruleset(cellCount: 12, wavePeriod: 0);
    const engine = MemoryEngine(rules);

    test('uses a charge, costs points and lets time pass', () {
      final before = engine.initial(
        processes: [
          MemoryProcess(
            id: 1,
            size: 2,
            start: 4,
            remaining: 20,
            releasePolicy: ReleasePolicy.normal,
          ),
        ],
      );
      final after = engine.compact(before).state!;
      expect(after.compactionsLeft, before.compactionsLeft - 1);
      expect(after.cycle - before.cycle, rules.compactionTickCost);
      expect(after.processes.single.start, 0, reason: 'packed to the start');
    });

    test('is refused once the charges run out', () {
      var s = engine.initial();
      s = s.copyWith(compactionsLeft: 0);
      expect(
        engine.compact(s).error,
        CompactionError.noChargesLeft,
        reason: explainCompactionError(CompactionError.noChargesLeft),
      );
    });
  });

  group('MAS-BR-005 content: 36 scenarios and an endless mode', () {
    test('there are at least 36 uniquely identified scenarios', () {
      expect(scenarios.length, greaterThanOrEqualTo(36));
      expect({for (final s in scenarios) s.id}.length, scenarios.length);
    });

    testWidgets('home offers endless play and the scenario list', (
      tester,
    ) async {
      await tester.pumpWidget(MemorySurvivalApp(services: _services()));
      await tester.pumpAndSettle();
      await _declineGameCenter(tester);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Scenarios'), findsOneWidget);
    });
  });

  group('MAS-BR-006 / MAS-TR-016 sign-in is opt-in and never gates play', () {
    testWidgets(
      'an endless run can be played and finished without signing in',
      (tester) async {
        final services = _services();
        await tester.pumpWidget(
          MaterialApp(home: GameScreen(services: services, seed: 3)),
        );
        await _playUntilOver(tester, 'Run over');
        expect(services.connection.isConnected, isFalse);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'no score or achievement reaches Game Center while disconnected',
      (tester) async {
        final services = _services();
        await tester.pumpWidget(
          MaterialApp(home: GameScreen(services: services, seed: 3)),
        );
        await _playUntilOver(tester, 'Run over');
        expect(_gameCenter.submittedScores, isEmpty);
        expect(_gameCenter.unlockedAchievements, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('a scenario can be played without signing in', (tester) async {
      final services = _services();
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            services: services,
            mode: RunMode.scenario,
            scenario: _quickScenario,
          ),
        ),
      );
      await _playUntilOver(tester, 'Scenario complete');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('MAS-BR-007 / MAS-TR-015 one purchase removes all ads', () {
    testWidgets('a free player sees the banner; buying ad removal hides it', (
      tester,
    ) async {
      final services = _services();
      await services.initialize();
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(services: services)),
      );
      expect(find.byKey(_banner), findsOneWidget);

      await _entitlement.purchaseAdRemoval();
      await tester.pump();
      expect(_ads.isAdFree, isTrue);

      // The next screen the player opens no longer carries one.
      await tester.pumpWidget(
        MaterialApp(home: ScenarioSelectScreen(services: services)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_banner), findsNothing);
    });

    test('an ad-free player gets no interstitial', () async {
      _services();
      _ads.setAdFree(true);
      await _ads.showInterstitial();
      expect(_ads.interstitialShownCount, 0);
    });

    test('a restored purchase also removes ads', () async {
      final services = AppServices(
        consent: FakeConsentService(),
        entitlement: FakeEntitlementService(hasPreviousPurchase: true),
        ads: FakeAdService(),
        auth: FakePlatformGameAuthService(),
        progress: FakeGameCenterProgressService(),
        openUrl: (_) async {},
      );
      await services.initialize();
      expect(services.ads.isAdFree, isTrue);
    });
  });

  group('MAS-BR-012 every failure is explained from visible state', () {
    test('each failure kind has a plain-language explanation', () {
      const rules = Ruleset();
      for (final kind in FailureKind.values) {
        final text = explainFailure(
          Failure(
            kind: kind,
            cycle: 10,
            requestId: 7,
            requestSize: 4,
            freeCells: 5,
            largestFreeBlock: 2,
          ),
          rules,
        );
        expect(text, contains('#7'), reason: '$kind names the request');
        expect(text.length, greaterThan(20), reason: '$kind');
      }
    });

    test('a run that ends carries the failure that ended it', () {
      final g = GameController(rules: const Ruleset(), seed: 3);
      for (var i = 0; i < 2000 && g.isPlaying; i++) {
        g.tick();
      }
      expect(g.isPlaying, isFalse);
      expect(g.state.failure, isNotNull);
    });

    test('every refused placement and compaction has an explanation', () {
      for (final e in PlacementError.values) {
        expect(
          explainPlacementError(e, requestSize: 3, cellCount: 16),
          isNotEmpty,
        );
      }
      for (final e in CompactionError.values) {
        expect(explainCompactionError(e), isNotEmpty);
      }
    });
  });

  group('MAS-BR-015 ad placement', () {
    testWidgets('the banner shows on home, scenarios and settings', (
      tester,
    ) async {
      final services = _services();
      await tester.pumpWidget(MemorySurvivalApp(services: services));
      await tester.pumpAndSettle();
      await _declineGameCenter(tester);
      expect(find.byKey(_banner), findsOneWidget, reason: 'home');

      await tester.pumpWidget(
        MaterialApp(home: ScenarioSelectScreen(services: services)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_banner), findsOneWidget, reason: 'scenario list');

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(services: services)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_banner), findsOneWidget, reason: 'settings');
    });

    testWidgets('no banner while placing; the banner returns on pause', (
      tester,
    ) async {
      final services = _services();
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(services: services, seed: 3, autoTick: false),
        ),
      );
      expect(find.byKey(_banner), findsNothing, reason: 'active play');
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.byKey(_banner), findsOneWidget, reason: 'pause overlay');
    });

    testWidgets('the results screen carries the banner', (tester) async {
      final services = _services();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(services: services, seed: 3)),
      );
      await _playUntilOver(tester, 'Run over');
      expect(find.byKey(_banner), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('one interstitial when leaving a finished scenario', (
      tester,
    ) async {
      final services = _services();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GameScreen(
                      services: services,
                      mode: RunMode.scenario,
                      scenario: _quickScenario,
                    ),
                  ),
                ),
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(_ads.interstitialShownCount, 0, reason: 'never gates the start');

      await _playUntilOver(tester, 'Scenario complete');
      expect(_ads.interstitialShownCount, 0, reason: 'not on the results card');

      await tester.tap(find.text('Scenarios'));
      await tester.pumpAndSettle();
      expect(_ads.interstitialShownCount, 1);
    });

    testWidgets('menu navigation never fires an interstitial', (tester) async {
      final services = _services();
      await tester.pumpWidget(MemorySurvivalApp(services: services));
      await tester.pumpAndSettle();
      await _declineGameCenter(tester);
      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scenarios'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_ads.interstitialShownCount, 0);
    });
  });

  group('MAS-BR-016 leaderboard', () {
    testWidgets('a signed-in player\'s endless score is submitted', (
      tester,
    ) async {
      final services = _services(connected: true);
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(services: services, seed: 3)),
      );
      await _playUntilOver(tester, 'Run over');
      expect(_gameCenter.submittedScores, [services.bestScore.value]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an ad-free (paid) player still submits', (tester) async {
      final services = _services(connected: true);
      await _entitlement.purchaseAdRemoval();
      _ads.setAdFree(true);
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(services: services, seed: 3)),
      );
      await _playUntilOver(tester, 'Run over');
      expect(_gameCenter.submittedScores, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('only Normal runs are ranked on the single leaderboard', (
      tester,
    ) async {
      final services = _services(connected: true);
      await services.difficulty.set(Difficulty.easy);
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(services: services, seed: 3)),
      );
      await _playUntilOver(tester, 'Run over');
      expect(_gameCenter.submittedScores, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
