// Launches the real app on a device or simulator and walks the paths a new
// player takes. Runs in CI (see .github/workflows/ci.yml), unlike the
// recording-only gameplay_video_test.dart. Uses the deterministic fakes, so
// no ad network, store or Game Center is contacted.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/game/game_controller.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/main.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppServices _services() => AppServices(
  consent: FakeConsentService(),
  entitlement: FakeEntitlementService(),
  ads: FakeAdService(),
  auth: FakePlatformGameAuthService(),
  progress: FakeGameCenterProgressService(),
  openUrl: (_) async {},
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a new player can reach every menu and finish an endless run', (
    tester,
  ) async {
    final services = _services();
    await services.initialize();
    await tester.pumpWidget(MemorySurvivalApp(services: services));
    await tester.pumpAndSettle();

    // Game Center is offered once and declining it never blocks play.
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Scenarios'), findsOneWidget);
    expect(find.byKey(const Key('fake_banner_ad')), findsWidgets);

    // Settings and the scenario list open and return.
    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Difficulty'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scenarios'));
    await tester.pumpAndSettle();
    expect(find.text('CHAPTER 1'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // First Play shows the instructions, then an unattended run ends with an
    // explained failure.
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start playing'));
    await tester.pump();
    for (var i = 0; i < 600 && find.text('Run over').evaluate().isEmpty; i++) {
      await tester.pump(baseTickDuration);
    }
    await tester.pump();
    expect(find.text('Run over'), findsOneWidget);
    expect(find.textContaining('The last fault'), findsOneWidget);
    expect(services.bestScore.value, greaterThanOrEqualTo(0));
  });
}
