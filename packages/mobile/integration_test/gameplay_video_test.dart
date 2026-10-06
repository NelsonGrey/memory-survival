import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/engine/engine.dart';
import 'package:memory_survival/game/game_controller.dart';
import 'package:memory_survival/game/game_screen.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _beat = Duration(milliseconds: 1500);

AppServices _services() => AppServices(
  consent: FakeConsentService(),
  entitlement: FakeEntitlementService(),
  ads: FakeAdService(),
  auth: FakePlatformGameAuthService(),
  progress: FakeGameCenterProgressService(),
  openUrl: (_) async {},
);

Future<void> _hold(WidgetTester tester, [Duration duration = _beat]) async {
  await tester.pump();
  await Future<void>.delayed(duration);
}

Future<void> _title(WidgetTester tester, String title, String detail) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xff07101d),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(42),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.memory_rounded,
                  color: Color(0xff28f0d0),
                  size: 72,
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xffa9b9cd),
                    fontSize: 18,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await _hold(tester, const Duration(milliseconds: 1900));
}

Future<void> _waitForRequest(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    if (find.textContaining('Where should').evaluate().isNotEmpty) return;
    await tester.pump(baseTickDuration);
  }
  fail('A request did not arrive in time.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('records the complete move and scoring tour', (tester) async {
    SharedPreferences.setMockInitialValues({
      'assist.suggestedPlacement': true,
      'onboarding.howToPlaySeen': true,
    });
    final services = _services();
    await services.initialize();

    await _title(
      tester,
      'MEMORY SURVIVAL',
      'Every placement scores. Every gap can end the run.',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GameScreen(services: services, seed: 3),
      ),
    );
    await _waitForRequest(tester);
    await _hold(tester);

    await _title(
      tester,
      'PLACE AT THE START',
      'A tidy manual placement earns base points, the clean-run multiplier, and a tidy bonus.',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GameScreen(services: services, seed: 3),
      ),
    );
    await _waitForRequest(tester);
    await tester.tap(find.textContaining('Start · cells').first);
    await _hold(tester);

    await _waitForRequest(tester);
    await _title(
      tester,
      'PLACE AT THE END',
      'Pack short- and long-lived processes at opposite edges to preserve one useful gap.',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GameScreen(services: services, seed: 3),
      ),
    );
    await _waitForRequest(tester);
    final end = find.textContaining('End · cells');
    await tester.tap(
      end.evaluate().isEmpty
          ? find.textContaining('Fill · cells').first
          : end.first,
    );
    await _hold(tester);

    await _title(
      tester,
      'SUGGESTED PLACEMENT',
      'The assist finds a safe gap, but assisted moves receive no multiplier.',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GameScreen(services: services, seed: 11),
      ),
    );
    await _waitForRequest(tester);
    await tester.tap(find.textContaining('Suggested: cell'));
    await _hold(tester);

    await _title(
      tester,
      'RESERVE SPACE',
      'Hold a known gap for an incoming request before the rest of the queue can claim it.',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GameScreen(services: services, seed: 3),
      ),
    );
    await _waitForRequest(tester);
    final reserve = find.text('Reserve space').first;
    await tester.tap(reserve);
    await tester.pump();
    final reserveCell = find.textContaining('▸').first;
    await tester.ensureVisible(reserveCell);
    await tester.tap(reserveCell);
    await _hold(tester);

    await _title(
      tester,
      'OVERCLOCK',
      'Increase throughput and scoring by 25% for 10 ticks—while requests arrive faster.',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GameScreen(services: services, seed: 7),
      ),
    );
    await tester.tap(find.text('Overclock'));
    await _hold(tester);
    await _waitForRequest(tester);
    await tester.tap(find.textContaining('Start · cells').first);
    await _hold(tester);

    await _title(
      tester,
      'TURN AWAY',
      'Reject one waiting request per wave. You avoid the allocation, but break the clean run.',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GameScreen(services: services, seed: 7),
      ),
    );
    await _waitForRequest(tester);
    await tester.tap(find.textContaining('Turn away #'));
    await _hold(tester);

    await _title(
      tester,
      'COMPACT',
      'Repack memory to create a large gap. It costs 5 points, time, one charge, and a multiplier tier.',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GameScreen(services: services, seed: 7),
      ),
    );
    await _waitForRequest(tester);
    await tester.tap(find.textContaining('End · cells').first);
    await tester.pump();
    await tester.tap(find.textContaining('Compact ('));
    await _hold(tester, const Duration(milliseconds: 2200));

    await _title(
      tester,
      'CLEAN UP A LEAK',
      'End a leaking process early. Half its cells stay locked temporarily, and the cleanup costs 3 points.',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GameScreen(
          services: services,
          seed: 5,
          rules: const Ruleset(
            arrivalPerMille: 1000,
            arrivalMaxPerMille: 1000,
            minSize: 2,
            maxSize: 2,
            families: {RequestFamily.leak},
            familyPerMille: 1000,
            progressiveFamilies: false,
          ),
        ),
      ),
    );
    await _waitForRequest(tester);
    await tester.tap(find.textContaining('Start · cells').first);
    await tester.pump();
    final cleanup = find.textContaining('Clean up leak #');
    expect(cleanup, findsOneWidget);
    await tester.ensureVisible(cleanup);
    await tester.tap(cleanup);
    await _hold(tester);

    await _title(
      tester,
      'SURVIVE THE PRESSURE',
      'Completed processes raise the multiplier. Clean wave clears add a bonus. Faults cost a life and raise heat.',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GameScreen(
          services: services,
          seed: 23,
          rules: const Ruleset(
            cellCount: 16,
            requestDeadline: 5,
            arrivalPerMille: 1000,
            arrivalMaxPerMille: 1000,
            minSize: 1,
            maxSize: 2,
            minLifetime: 2,
            maxLifetime: 3,
            wavePeriod: 8,
            warningTicks: 2,
            stormTicks: 2,
            recoveryTicks: 2,
            stormPerMille: 1000,
            multiplierStep: 2,
          ),
        ),
      ),
    );
    for (var move = 0; move < 8; move++) {
      await _waitForRequest(tester);
      final starts = find.textContaining('Start · cells');
      final ends = find.textContaining('End · cells');
      final fills = find.textContaining('Fill · cells');
      final target = move.isEven && starts.evaluate().isNotEmpty
          ? starts.first
          : ends.evaluate().isNotEmpty
          ? ends.first
          : fills.evaluate().isNotEmpty
          ? fills.first
          : null;
      if (target != null) {
        await tester.ensureVisible(target);
        await tester.pump();
        await tester.tap(target);
      }
      await tester.pump(baseTickDuration);
      await _hold(tester, const Duration(milliseconds: 650));
      if (find.text('Run over').evaluate().isNotEmpty) break;
    }
    await _hold(tester, const Duration(milliseconds: 2200));

    await _title(
      tester,
      'HOW HIGH CAN YOU SCORE?',
      'Place cleanly. Protect your multiplier. Survive the next wave.',
    );
  });
}
