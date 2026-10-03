import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/game/game_controller.dart';
import 'package:memory_survival/game/game_screen.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/layout/game_layout.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:memory_survival/theme/game_theme.dart';
import 'package:memory_survival/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppServices fakeServices({LayoutController? layout, ThemeController? theme}) =>
    AppServices(
      consent: FakeConsentService(),
      entitlement: FakeEntitlementService(),
      ads: FakeAdService(),
      auth: FakePlatformGameAuthService(),
      progress: FakeGameCenterProgressService(),
      openUrl: (_) async {},
      layout: layout,
      theme: theme,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every layout id has a spec and appears in the picker order', () {
    expect(gameLayouts.keys.toSet(), GameLayoutId.values.toSet());
    expect(gameLayoutOrder.toSet(), GameLayoutId.values.toSet());
    expect(gameLayoutOrder.length, inInclusiveRange(3, 5));
    expect(gameThemeOrder.length, inInclusiveRange(3, 5));
  });

  test('layout choice persists and unknown names fall back', () async {
    final a = LayoutController();
    await a.select(GameLayoutId.tower);
    final b = LayoutController();
    await b.load();
    expect(b.value, GameLayoutId.tower);

    SharedPreferences.setMockInitialValues({'gameplay.layout': 'removed'});
    final c = LayoutController();
    await c.load();
    expect(c.value, defaultGameLayout);
  });

  test('palette choice persists for the new palettes', () async {
    final a = ThemeController();
    await a.select(GameThemeId.ember);
    final b = ThemeController();
    await b.load();
    expect(b.value, GameThemeId.ember);
  });

  for (final layoutId in GameLayoutId.values) {
    testWidgets('${layoutId.name} layout renders a live run in every palette '
        'on a small phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final layout = LayoutController();
      final theme = ThemeController();
      final services = fakeServices(layout: layout, theme: theme);
      await services.initialize();
      layout.value = layoutId;
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(services: services, seed: 5)),
      );

      // Let requests arrive and place a few so blocks are on the strip.
      for (var i = 0; i < 12; i++) {
        await tester.pump(baseTickDuration);
        final gap = find.textContaining('Cells ');
        if (gap.evaluate().isNotEmpty) {
          await tester.tap(gap.first);
          await tester.pump();
        }
      }
      for (final id in GameThemeId.values) {
        theme.value = id;
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$layoutId / $id');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
