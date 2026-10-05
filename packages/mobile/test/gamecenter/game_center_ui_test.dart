import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/gamecenter/game_center_connection.dart';
import 'package:memory_survival/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppServices _services(GameCenterConnection connection) => AppServices(
  consent: FakeConsentService(),
  entitlement: FakeEntitlementService(),
  ads: FakeAdService(),
  auth: FakePlatformGameAuthService(),
  connection: connection,
  progress: FakeGameCenterProgressService(),
  openUrl: (_) async {},
);

GameCenterConnection _fresh({bool supported = true}) => GameCenterConnection(
  auth: FakePlatformGameAuthService(),
  supported: supported,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpApp(WidgetTester tester, AppServices services) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MemorySurvivalApp(services: services));
    await tester.pumpAndSettle();
  }

  testWidgets('first visit offers Game Center; Connect connects', (
    tester,
  ) async {
    final connection = _fresh();
    await pumpApp(tester, _services(connection));
    expect(find.text('Connect to Game Center?'), findsOneWidget);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(connection.isConnected, isTrue);
    expect(find.text('Connect to Game Center?'), findsNothing);
    expect(find.text('Test Player'), findsOneWidget);
    expect(find.byTooltip('Leaderboard'), findsOneWidget);
    expect(find.byTooltip('Achievements'), findsOneWidget);
  });

  testWidgets('Not now leaves a connect button on home', (tester) async {
    final connection = _fresh();
    await pumpApp(tester, _services(connection));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(connection.status, GameCenterStatus.off);
    expect(find.text('Connect Game Center'), findsOneWidget);
  });

  testWidgets('unsupported platform hides every Game Center control', (
    tester,
  ) async {
    await pumpApp(tester, _services(_fresh(supported: false)));
    expect(find.text('Connect to Game Center?'), findsNothing);
    expect(find.text('Connect Game Center'), findsNothing);

    await tester.ensureVisible(find.text('Settings'));

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Game Center'), findsNothing);
  });

  testWidgets('Settings switch connects and disconnects', (tester) async {
    final connection = _fresh();
    await pumpApp(tester, _services(connection));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(SwitchListTile, 'Connect to Game Center');
    await tester.scrollUntilVisible(tile, 200);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(connection.isConnected, isTrue);
    expect(find.text('Connected as Test Player'), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(connection.status, GameCenterStatus.off);
  });
}
