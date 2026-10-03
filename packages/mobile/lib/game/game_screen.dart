import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../engine/engine.dart';
import '../shell/shell.dart';
import '../theme/game_theme.dart';
import 'explain.dart';
import 'game_controller.dart';
import 'memory_strip.dart';

/// An endless run. Everything is tap-only: select a request, then tap a cell
/// or a "gap" button. The banner shows only while paused or on the results
/// card, never during active placement (MAS-BR-015).
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.services,
    this.seed,
    this.rules = const Ruleset(),
    this.autoTick = true,
  });

  final AppServices services;

  /// Fixed seed for reproducible runs and tests; random when null.
  final int? seed;
  final Ruleset rules;

  /// Tests turn this off and step the controller by hand.
  final bool autoTick;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameController _game;
  Timer? _timer;
  bool _interstitialShown = false;

  AppServices get services => widget.services;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _newRun();
    services.relaxedClock.addListener(_restartTimer);
  }

  void _newRun() {
    _game = GameController(
      rules: widget.rules,
      seed: widget.seed ?? DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
    );
    _interstitialShown = false;
    services.ads.preloadInterstitial();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!widget.autoTick) return;
    final d = services.relaxedClock.value
        ? baseTickDuration * relaxedClockMultiplier
        : baseTickDuration;
    _timer = Timer.periodic(d, (_) => _game.tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lifetimes must not run down while the player cannot act (TRD 9).
    if (state != AppLifecycleState.resumed) _game.setPaused(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    services.relaxedClock.removeListener(_restartTimer);
    _timer?.cancel();
    _game.dispose();
    super.dispose();
  }

  /// One interstitial per run, on the way back to a non-gameplay screen.
  void _leave() {
    if (!_interstitialShown) {
      _interstitialShown = true;
      services.ads.showInterstitial();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_game, services.theme]),
      builder: (context, _) {
        final p = services.theme.palette;
        final over = !_game.isPlaying;
        final active = !over && !_game.paused;
        return PopScope(
          canPop: !active,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _game.setPaused(true);
          },
          child: Scaffold(
            backgroundColor: p.pageBg,
            body: GameScreenShell(
              adService: services.ads,
              showBanner: !active,
              body: SafeArea(
                top: false,
                child: Stack(
                  children: [
                    _playfield(p),
                    if (_game.paused && !over) _pauseCard(p),
                    if (over) _resultsCard(p),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _playfield(GameThemePalette p) {
    final s = _game.state;
    final sel = _game.selected;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat(p, 'Score', '${s.score.points}'),
              _stat(p, 'Time', '${s.cycle}'),
              _stat(p, 'Free', '${s.freeCells}'),
              _stat(p, 'Biggest gap', '${s.largestFreeBlock}'),
              IconButton(
                tooltip: 'Pause',
                onPressed: () => _game.setPaused(true),
                icon: Icon(Icons.pause_circle_outline, color: p.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MemoryStrip(state: s, palette: p, onCellTap: _game.placeAt),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: Text(
              _game.message ??
                  (sel == null
                      ? 'Waiting for a request…'
                      : 'Tap a cell to place request #${sel.id} '
                            '(${sel.size} cells), or pick a gap below.'),
              style: TextStyle(
                color: _game.message == null ? p.textMuted : p.danger,
                fontSize: 13,
              ),
            ),
          ),
          Text('Waiting', style: TextStyle(color: p.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in s.requestQueue)
                _requestChip(p, r, selected: r.id == sel?.id),
            ],
          ),
          const SizedBox(height: 16),
          if (sel != null) ...[
            Text(
              'Place in a gap',
              style: TextStyle(color: p.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            if (_game.fittingGaps.isEmpty)
              Text(
                'No gap is big enough. Wait for space to free up, or compact.',
                style: TextStyle(color: p.danger, fontSize: 13),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in _game.fittingGaps)
                    FilledButton(
                      onPressed: () => _game.placeAt(g.start),
                      child: Text('Cells ${g.start}–${g.end - 1}'),
                    ),
                ],
              ),
          ],
          const Spacer(),
          OutlinedButton.icon(
            onPressed: s.compactionsLeft > 0 ? _game.compact : null,
            icon: const Icon(Icons.compress),
            label: Text(
              'Compact (${s.compactionsLeft} left) · '
              'costs ${widget.rules.compactionTickCost} ticks, '
              '${widget.rules.compactionPointCost} pts',
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(GameThemePalette p, String label, String value) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: p.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(label, style: TextStyle(color: p.textMuted, fontSize: 10)),
    ],
  );

  Widget _requestChip(GameThemePalette p, Request r, {required bool selected}) {
    final urgent = r.deadline <= 2;
    return Semantics(
      button: true,
      selected: selected,
      label:
          'Request ${r.id}, ${r.size} cells, lives ${r.lifetime} ticks, '
          '${r.deadline} ticks left to place',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _game.select(r.id),
        child: Container(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: p.cellFree,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? p.ok : p.cellFreeBorder,
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#${r.id} · ${r.size} cells',
                style: TextStyle(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                'lives ${r.lifetime} · ⏱ ${r.deadline}${urgent ? ' !' : ''}',
                style: TextStyle(
                  color: urgent ? p.danger : p.textMuted,
                  fontSize: 11,
                ),
              ),
              if (r.releasePolicy == ReleasePolicy.leak)
                Text('leaks', style: TextStyle(color: p.danger, fontSize: 10)),
              if (r.pinned)
                Text(
                  'pinned',
                  style: TextStyle(color: p.textMuted, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlay(GameThemePalette p, {required List<Widget> children}) =>
      Positioned.fill(
        child: ColoredBox(
          color: p.pageBg.withValues(alpha: 0.94),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      );

  Widget _pauseCard(GameThemePalette p) => _overlay(
    p,
    children: [
      Text(
        'Paused',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: p.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => _game.setPaused(false),
        child: const Text('Resume'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: _leave, child: const Text('Quit run')),
    ],
  );

  Widget _resultsCard(GameThemePalette p) {
    final s = _game.state;
    return _overlay(
      p,
      children: [
        Text(
          'Run over',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: p.danger,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          explainFailure(s.failure!, widget.rules),
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textPrimary, fontSize: 15),
        ),
        const SizedBox(height: 12),
        Text(
          'Score ${s.score.points} · survived ${s.score.ticksSurvived} ticks · '
          '${s.score.completed} processes finished',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => setState(() {
            final old = _game;
            _newRun();
            old.dispose();
          }),
          child: const Text('Play again'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _leave, child: const Text('Home')),
      ],
    );
  }
}
