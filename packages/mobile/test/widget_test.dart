import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/main.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('app starts on the home screen and opens Settings', (
    tester,
  ) async {
    final services = AppServices(
      consent: FakeConsentService(),
      entitlement: FakeEntitlementService(),
      ads: FakeAdService(),
      auth: FakePlatformGameAuthService(),
      progress: FakeGameCenterProgressService(),
      openUrl: (_) async {},
    );
    await tester.pumpWidget(MemorySurvivalApp(services: services));
    await tester.pumpAndSettle();

    // First visit offers Game Center; decline it to reach the home screen.
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Survival'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
  });
}
