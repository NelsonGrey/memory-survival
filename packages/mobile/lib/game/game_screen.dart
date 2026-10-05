import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../engine/engine.dart';
import '../shell/shell.dart';
import '../screens/how_to_play_screen.dart';
import '../screens/settings_screen.dart';
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
  bool _newBest = false;
  bool _scoreSubmitted = false;

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
    _newBest = false;
    _scoreSubmitted = false;
    _game.addListener(_onGameChanged);
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

  /// Records the score once when the run ends.
  void _onGameChanged() {
    if (_game.isPlaying || _scoreSubmitted) return;
    _scoreSubmitted = true;
    services.bestScore.submit(_game.state.score.points).then((isBest) {
      if (mounted && isBest) setState(() => _newBest = true);
    });
  }

  /// Settings and instructions open over a paused game; it stays paused
  /// until the player taps Resume.
  Future<void> _openPaused(WidgetBuilder builder) async {
    _game.setPaused(true);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  void _openSettings() =>
      _openPaused((_) => SettingsScreen(services: services));

  void _openHowTo() => _openPaused((_) => HowToPlayScreen(services: services));

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
      listenable: Listenable.merge([_game, services.theme, services.bestScore]),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(p, s),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: MemoryStrip(
                    state: s,
                    palette: p,
                    onCellTap: _game.placeAt,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _notice(p, s),
                        _queue(p, s),
                        const SizedBox(height: 12),
                        ..._gapPicker(p),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _compactButton(s),
        ],
      ),
    );
  }

  Widget _header(GameThemePalette p, MemoryState s) {
    final best = services.bestScore.value;
    return Row(
      children: [
        _stat(p, 'Score', '${s.score.points}'),
        const SizedBox(width: 14),
        _stat(p, 'Best', '${best > s.score.points ? best : s.score.points}'),
        const SizedBox(width: 14),
        _stat(p, 'Time', '${s.cycle}'),
        const SizedBox(width: 14),
        Semantics(
          label: '${s.livesLeft} lives left',
          excludeSemantics: true,
          child: Row(
            children: [
              Icon(Icons.favorite, size: 20, color: p.danger),
              const SizedBox(width: 4),
              Text(
                '${s.livesLeft}',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'How to play',
          onPressed: _openHowTo,
          icon: Icon(Icons.help_outline, color: p.textPrimary),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: _openSettings,
          icon: Icon(Icons.settings_outlined, color: p.textPrimary),
        ),
        IconButton(
          tooltip: 'Pause',
          onPressed: () => _game.setPaused(true),
          icon: Icon(Icons.pause_circle_outline, color: p.textPrimary),
        ),
      ],
    );
  }

  /// What happened last (a fault), or what to do next.
  Widget _notice(GameThemePalette p, MemoryState s) {
    final sel = _game.selected;
    final String text;
    final bool bad;
    if (_game.message != null) {
      text = _game.message!;
      bad = true;
    } else if (_game.faultNotice != null) {
      text = _game.faultNotice!;
      bad = true;
    } else if (sel == null) {
      text = 'Waiting for a request…';
      bad = false;
    } else {
      text =
          'Tap a cell to place #${sel.id} (${sel.size} cells), '
          'or pick a gap below.';
      bad = false;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(color: bad ? p.danger : p.textMuted, fontSize: 12),
      ),
    );
  }

  Widget _queue(GameThemePalette p, MemoryState s) {
    final sel = _game.selected;
    final full = s.requestQueue.length >= widget.rules.maxQueue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waiting ${s.requestQueue.length} of ${widget.rules.maxQueue}'
          '${full ? ' · full: the next one is turned away' : ''}',
          style: TextStyle(
            color: full ? p.danger : p.textMuted,
            fontSize: 12,
            fontWeight: full ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in s.requestQueue)
              _requestChip(p, r, selected: r.id == sel?.id),
          ],
        ),
      ],
    );
  }

  List<Widget> _gapPicker(GameThemePalette p) {
    if (_game.selected == null) return const [];
    return [
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
    ];
  }

  Widget _compactButton(MemoryState s) => OutlinedButton.icon(
    onPressed: s.compactionsLeft > 0 ? _game.compact : null,
    icon: const Icon(Icons.compress),
    label: Text(
      'Compact (${s.compactionsLeft} left) · '
      'costs ${widget.rules.compactionTickCost} ticks, '
      '${widget.rules.compactionPointCost} pts',
    ),
  );

  Widget _stat(GameThemePalette p, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
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

  /// A waiting request. The bar drains as its deadline nears, with a "!"
  /// and the number so urgency never depends on colour.
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
          constraints: const BoxConstraints(minWidth: 84, minHeight: 48),
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                'lives ${r.lifetime}'
                '${r.releasePolicy == ReleasePolicy.leak ? ' · leaks' : ''}'
                '${r.pinned ? ' · pinned' : ''}',
                style: TextStyle(color: p.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (r.deadline / widget.rules.requestDeadline).clamp(
                    0.0,
                    1.0,
                  ),
                  minHeight: 5,
                  color: urgent ? p.danger : p.ok,
                  backgroundColor: p.cellFreeBorder.withValues(alpha: 0.35),
                ),
              ),
              Text(
                '⏱ ${r.deadline}${urgent ? ' !' : ''}',
                style: TextStyle(
                  color: urgent ? p.danger : p.textMuted,
                  fontSize: 11,
                  fontWeight: urgent ? FontWeight.w700 : FontWeight.w400,
                ),
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
            child: SingleChildScrollView(
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
      OutlinedButton(onPressed: _openSettings, child: const Text('Settings')),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: _openHowTo, child: const Text('How to play')),
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
          'The last fault: ${explainFailure(s.failure!, widget.rules)}',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textPrimary, fontSize: 15),
        ),
        const SizedBox(height: 16),
        Text(
          _newBest ? 'New best: ${s.score.points}' : 'Score ${s.score.points}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _newBest ? p.ok : p.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Best ${services.bestScore.value} · survived ${s.score.ticksSurvived} '
          'ticks · ${s.score.completed} processes finished',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => setState(() {
            final old = _game;
            old.removeListener(_onGameChanged);
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
