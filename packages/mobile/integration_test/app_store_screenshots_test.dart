import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/engine/engine.dart';
import 'package:memory_survival/game/game_controller.dart';
import 'package:memory_survival/game/game_screen.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/main.dart';
import 'package:memory_survival/screens/how_to_play_screen.dart';
import 'package:memory_survival/screens/scenario_select_screen.dart';
import 'package:memory_survival/screens/settings_screen.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:memory_survival/theme/game_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppServices _services() => AppServices(
  consent: FakeConsentService(),
  entitlement: FakeEntitlementService(),
  ads: FakeAdService(),
  auth: FakePlatformGameAuthService(),
  progress: FakeGameCenterProgressService(),
  openUrl: (_) async {},
);

Widget _host(AppServices services, Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: materialThemeFor(services.theme.palette),
  home: home,
);

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump();
  debugPrint('APP_STORE_CAPTURE:$name');
  await Future<void>.delayed(const Duration(seconds: 2));
}

Future<void> _waitForRequest(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    if (find.textContaining('Where should').evaluate().isNotEmpty) return;
    await tester.pump(baseTickDuration);
  }
  fail('A request did not arrive in time.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the App Store iPhone screenshot set', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.howToPlaySeen': true,
      'assist.suggestedPlacement': true,
    });
    final services = _services();
    await services.initialize();
    await services.entitlement.purchaseAdRemoval();
    services.ads.setAdFree(true);

    await tester.pumpWidget(MemorySurvivalApp(services: services));
    await tester.pumpAndSettle();
    if (find.text('Not now').evaluate().isNotEmpty) {
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
    }
    await _shot(tester, '01-home');

    await tester.pumpWidget(
      _host(services, HowToPlayScreen(services: services)),
    );
    await tester.pumpAndSettle();
    await _shot(tester, '02-how-to-play');

    await tester.pumpWidget(
      _host(services, ScenarioSelectScreen(services: services)),
    );
    await tester.pumpAndSettle();
    await _shot(tester, '03-scenarios');

    await tester.pumpWidget(
      _host(services, SettingsScreen(services: services)),
    );
    await tester.pumpAndSettle();
    await _shot(tester, '04-settings');

    Future<void> freshGame(int seed) async {
      await tester.pumpWidget(
        _host(
          services,
          GameScreen(
            key: ValueKey('game-$seed'),
            services: services,
            seed: seed,
          ),
        ),
      );
      await _waitForRequest(tester);
    }

    await freshGame(3);
    await _shot(tester, '05-incoming-request');

    await tester.tap(find.textContaining('Start · cells').first);
    await tester.pump();
    await _waitForRequest(tester);
    await _shot(tester, '06-active-memory');

    await tester.tap(find.textContaining('End · cells').first);
    await tester.pump(baseTickDuration);
    await _waitForRequest(tester);
    await _shot(tester, '07-strategic-placement');

    await freshGame(7);
    await tester.tap(find.text('Overclock'));
    await tester.pump();
    await _waitForRequest(tester);
    await _shot(tester, '08-overclock-pressure');

    await tester.tap(find.byIcon(Icons.pause_circle_outline));
    await tester.pump();
    await _shot(tester, '09-paused-run');

    await tester.pumpWidget(
      _host(
        services,
        GameScreen(
          key: const ValueKey('leak-game'),
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
    await _shot(tester, '10-leak-request');
  });
}
