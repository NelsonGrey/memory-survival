import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/engine/engine.dart';
import 'package:memory_survival/theme/game_theme.dart';
import 'package:memory_survival/theme/memory_survival_brand.dart';

void main() {
  const rules = Ruleset(cellCount: 12);
  const engine = MemoryEngine(rules);
  MemoryState at(int cycle, {int heat = 0}) =>
      engine.initial().copyWith(cycle: cycle, heat: heat);

  group('wavePressure', () {
    test(
      'builds through the warning, peaks in the storm, eases in recovery',
      () {
        final calm = wavePressure(at(3));
        final warn1 = wavePressure(at(15));
        final warn2 = wavePressure(at(19));
        final storm = wavePressure(at(22));
        final recovery = wavePressure(at(26));
        expect(calm, lessThan(warn1));
        expect(warn1, lessThan(warn2));
        expect(warn2, lessThan(storm));
        expect(storm, 1.0);
        expect(recovery, lessThan(calm));
      },
    );

    test('later waves lean in more, and heat adds to it', () {
      expect(wavePressure(at(11 + 25 * 3)), greaterThan(wavePressure(at(11))));
      expect(wavePressure(at(11, heat: 2)), greaterThan(wavePressure(at(11))));
      expect(wavePressure(at(22, heat: 3)), 1.0, reason: 'clamped');
    });

    test('stays within 0..1 with waves off', () {
      const noWaves = Ruleset(wavePeriod: 0);
      final s = const MemoryEngine(noWaves).initial();
      expect(wavePressure(s), inInclusiveRange(0.0, 1.0));
    });
  });

  group('brand widgets', () {
    final p = gameThemePalettes[GameThemeId.dark]!;

    testWidgets('the backdrop paints under any child and animates pressure', (
      tester,
    ) async {
      var pressure = 0.1;
      late StateSetter set;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return CorridorBackdrop(
                palette: p,
                pressure: pressure,
                child: const Center(child: Text('content')),
              );
            },
          ),
        ),
      );
      expect(find.text('content'), findsOneWidget);
      set(() => pressure = 1);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the backdrop adds nothing to the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: CorridorBackdrop(palette: p, child: const Text('only me')),
        ),
      );
      expect(find.bySemanticsLabel('only me'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the brand images are bundled and decode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              const BrandMark(size: 40),
              Image.asset(wordmarkAsset, width: 200),
              Image.asset(stackedWordmarkAsset, width: 200),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a mini strip sizes itself from its pattern', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: MiniStrip(pattern: 'uu.hd.l', palette: p, cell: 20),
          ),
        ),
      );
      final size = tester.getSize(find.byType(MiniStrip));
      expect(size.width, 7 * 23 - 3);
      expect(size.height, 20);
    });
  });
}
