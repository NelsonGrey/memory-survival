// Automated accessibility evidence for MAS-BR-013 (not reliant on color,
// audio, fine motor precision or rapid reading) and MAS-BR-008 (overlays are
// optional). Covers what a test can prove: tap-target sizes, labelled
// controls, text contrast, large text, and non-color cues. A VoiceOver
// session on a device is still worth doing once; see ACCEPTANCE_TESTING.md.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/engine/engine.dart';
import 'package:memory_survival/game/game_controller.dart';
import 'package:memory_survival/game/game_screen.dart';
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

/// Opens the app on a phone-sized screen, past the Game Center prompt.
Future<AppServices> _openHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final services = _services();
  await tester.pumpWidget(MemorySurvivalApp(services: services));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Not now'));
  await tester.pumpAndSettle();
  return services;
}

Future<void> _open(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

typedef _Screen = Future<void> Function(WidgetTester tester);

final _screens = <String, _Screen>{
  'Home': (tester) async {},
  'Settings': (tester) => _open(tester, 'Settings'),
  'Scenarios': (tester) => _open(tester, 'Scenarios'),
  'How to play': (tester) => _open(tester, 'How to play'),
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Menus meet the platform accessibility guidelines', () {
    for (final entry in _screens.entries) {
      testWidgets('${entry.key}: tap targets are large enough', (tester) async {
        final handle = tester.ensureSemantics();
        await _openHome(tester);
        await entry.value(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('${entry.key}: every tappable control has a label', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _openHome(tester);
        await entry.value(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('${entry.key}: text has enough contrast', (tester) async {
        final handle = tester.ensureSemantics();
        await _openHome(tester);
        await entry.value(tester);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });

  group('Large text', () {
    for (final scale in const [1.5, 2.0, 3.0]) {
      for (final entry in _screens.entries) {
        testWidgets('${entry.key} survives text at ${scale}x', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _openHome(tester);
          await entry.value(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} overflowed at ${scale}x text',
          );
        });
      }
    }

    testWidgets('the game screen survives text at 2x', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final services = _services();
      await services.suggestions.set(true);
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            services: services,
            seed: 11,
            rules: const Ruleset(lives: 99, maxQueue: 6),
          ),
        ),
      );
      for (var i = 0; i < 60; i++) {
        await tester.pump(baseTickDuration);
        final opt = find.textContaining('· cells');
        if (opt.evaluate().isNotEmpty) {
          await tester.tap(opt.first, warnIfMissed: false);
          await tester.pump();
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Nothing relies on color alone', () {
    testWidgets('every memory cell is described in words', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final services = _services();
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            services: services,
            seed: 11,
            rules: const Ruleset(lives: 99, maxQueue: 6),
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(baseTickDuration);
      }
      final labels = <String>[];
      void visit(SemanticsNode node) {
        labels.add(node.label);
        node.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(tester.getSemantics(find.byType(GameScreen)));
      final cellLabels = labels
          .where((l) => RegExp(r'cell', caseSensitive: false).hasMatch(l))
          .toList();
      expect(
        cellLabels,
        isNotEmpty,
        reason: 'memory cells expose no text description',
      );
      // Used and free cells are told apart by their words, not their color.
      expect(
        cellLabels.any((l) => RegExp('free', caseSensitive: false).hasMatch(l)),
        isTrue,
      );
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('lifetimes and states are shown as numbers or text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final services = _services();
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            services: services,
            seed: 11,
            rules: const Ruleset(lives: 99, maxQueue: 6),
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(baseTickDuration);
        final opt = find.textContaining('· cells');
        if (opt.evaluate().isNotEmpty) {
          await tester.tap(opt.first, warnIfMissed: false);
          await tester.pump();
        }
      }
      // Remaining lifetime is a number on each block (a digit in a Text).
      final digits = find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d+$').hasMatch(w.data ?? ''),
      );
      expect(digits, findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Overlays are optional', () {
    testWidgets(
      'placement suggestions are off until the player turns them on',
      (tester) async {
        final services = _services();
        await services.suggestions.load();
        expect(services.suggestions.value, isFalse);
      },
    );

    testWidgets('a relaxed clock is off by default, slows ticks and persists', (
      tester,
    ) async {
      final services = _services();
      await services.relaxedClock.load();
      expect(services.relaxedClock.value, isFalse);
      expect(relaxedClockMultiplier, greaterThan(1));
      await services.relaxedClock.set(true);
      final reopened = _services();
      await reopened.relaxedClock.load();
      expect(reopened.relaxedClock.value, isTrue);
    });
  });
}
