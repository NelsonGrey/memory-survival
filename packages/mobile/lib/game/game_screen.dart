import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../engine/engine.dart';
import '../gamecenter/game_center_progress_service.dart';
import '../screens/how_to_play_screen.dart';
import '../screens/settings_screen.dart';
import '../settings/personal_bests.dart';
import '../shell/shell.dart';
import '../theme/game_theme.dart';
import '../theme/memory_survival_brand.dart';
import 'explain.dart';
import 'game_controller.dart';
import 'game_widgets.dart';
import 'memory_strip.dart';

/// What kind of run this is.
enum RunMode {
  /// Endless survival with a random seed; feeds the leaderboard.
  endless,

  /// Today's shared seed.
  daily,

  /// An authored scenario with a goal and three objectives.
  scenario,
}

/// A run. Everything is tap-only: select a request, then tap a cell or a
/// "gap" button. The banner shows only while paused or on the results card,
/// never during active placement (MAS-BR-015).
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.services,
    this.seed,
    this.rules = const Ruleset(),
    this.autoTick = true,
    this.mode = RunMode.endless,
    this.scenario,
  }) : assert(mode != RunMode.scenario || scenario != null);

  final AppServices services;

  /// Fixed seed for reproducible runs and tests; random when null. Daily and
  /// scenario runs use their own seeds.
  final int? seed;
  final Ruleset rules;

  /// Tests turn this off and step the controller by hand.
  final bool autoTick;
  final RunMode mode;
  final Scenario? scenario;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameController _game;
  Timer? _timer;
  bool _interstitialShown = false;
  bool _newBest = false;
  bool _scoreSubmitted = false;
  bool _firstPlacementReported = false;
  bool _firstCompactionReported = false;
  NewRecords _records = const NewRecords();
  Set<Objective> _freshObjectives = const {};

  AppServices get services => widget.services;
  Scenario? get _scenario => widget.scenario;
  Ruleset get _rules => _scenario?.rules ?? widget.rules;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _newRun();
    services.relaxedClock.addListener(_restartTimer);
  }

  int _seedForRun() {
    switch (widget.mode) {
      case RunMode.endless:
        return widget.seed ??
            DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
      case RunMode.daily:
        return widget.seed ?? services.daily.seed;
      case RunMode.scenario:
        return _scenario!.seed;
    }
  }

  void _newRun() {
    _game = GameController(
      rules: _rules,
      seed: _seedForRun(),
      suggestions: services.suggestions.value,
    );
    _interstitialShown = false;
    _newBest = false;
    _scoreSubmitted = false;
    _firstPlacementReported = false;
    _firstCompactionReported = false;
    _records = const NewRecords();
    _freshObjectives = const {};
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

  void _onGameChanged() {
    final s = _game.state;
    if (!_firstPlacementReported && s.score.placed > 0) {
      _firstPlacementReported = true;
      services.progress.unlockAchievement(
        GameCenterIds.achievementFirstAllocation,
      );
    }
    if (!_firstCompactionReported && s.score.compactions > 0) {
      _firstCompactionReported = true;
      services.progress.unlockAchievement(
        GameCenterIds.achievementFirstCompaction,
      );
    }
    if (_game.isPlaying || _scoreSubmitted) return;
    _scoreSubmitted = true;
    _finishRun(s);
  }

  /// Records the finished run once: best scores, personal records, scenario
  /// stars and the leaderboard, depending on the mode.
  Future<void> _finishRun(MemoryState s) async {
    final records = await services.personalBests.submit(s.score);
    var newBest = false;
    var fresh = const <Objective>{};
    switch (widget.mode) {
      case RunMode.endless:
        newBest = await services.bestScore.submit(s.score.points);
        services.progress.submitScore(s.score.points);
      case RunMode.daily:
        newBest = await services.daily.submit(s.score.points);
      case RunMode.scenario:
        fresh = await services.scenarioProgress.record(
          _scenario!.id,
          _scenario!.objectivesMet(s),
        );
        if (services.scenarioProgress.campaignComplete) {
          services.progress.unlockAchievement(
            GameCenterIds.achievementCampaignComplete,
          );
        }
    }
    if (!mounted) return;
    setState(() {
      _records = records;
      _newBest = newBest;
      _freshObjectives = fresh;
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

  void _restart() => setState(() {
    final old = _game;
    old.removeListener(_onGameChanged);
    _newRun();
    old.dispose();
  });

  void _playNext() {
    final next = nextScenario(_scenario!.id);
    if (next == null) return _leave();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          services: services,
          mode: RunMode.scenario,
          scenario: next,
          autoTick: widget.autoTick,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _game,
        services.theme,
        services.bestScore,
        services.daily,
      ]),
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
                    CorridorBackdrop(
                      palette: p,
                      intensity: 0.85,
                      pressure: wavePressure(_game.state),
                      child: _playfield(p),
                    ),
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
          const SizedBox(height: 8),
          WaveBanner(state: s, palette: p),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: MemoryStrip(
                    state: s,
                    palette: p,
                    onCellTap: _game.placeAt,
                    validStarts: _game.validStarts,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AnimatedSize(
                                duration: const Duration(milliseconds: 150),
                                alignment: Alignment.topCenter,
                                child: _notice(p, s),
                              ),
                              _forecast(p, s),
                              _queue(p, s),
                              const SizedBox(height: 12),
                              ..._placementPicker(p, s),
                              ..._leakCleanup(p, s),
                            ],
                          ),
                        ),
                      ),
                      _actions(p, s),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _modeLabel {
    switch (widget.mode) {
      case RunMode.endless:
        return '';
      case RunMode.daily:
        return 'Daily ${services.daily.dayKey}';
      case RunMode.scenario:
        return '${_scenario!.id.toUpperCase()} · ${_scenario!.title}';
    }
  }

  Widget _header(GameThemePalette p, MemoryState s) {
    final int best;
    switch (widget.mode) {
      case RunMode.endless:
        best = services.bestScore.value;
      case RunMode.daily:
        best = services.daily.todaysBest ?? 0;
      case RunMode.scenario:
        best = 0;
    }
    final goal = _rules.goalTicks;
    final streak = s.completionsToNextTier;
    final score = s.score.points;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandMark(size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Memory Survival',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _iconButton(p, 'How to play', Icons.help_outline, _openHowTo),
            _iconButton(
              p,
              'Pause',
              Icons.pause_circle_outline,
              () => _game.setPaused(true),
            ),
            _iconButton(p, 'Settings', Icons.settings_outlined, _openSettings),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: StatTile(
                palette: p,
                icon: Icons.emoji_events_outlined,
                label: 'Score',
                value: '$score',
              ),
            ),
            if (widget.mode != RunMode.scenario) ...[
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  palette: p,
                  icon: Icons.star_outline,
                  label: 'Best',
                  value: '${best > score ? best : score}',
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                palette: p,
                icon: Icons.timer_outlined,
                label: goal > 0 ? 'Time / goal' : 'Time',
                value: goal > 0 ? '${s.cycle}/$goal' : '${s.cycle}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                palette: p,
                icon: Icons.favorite,
                iconColor: p.danger,
                label: 'Lives',
                value: '${s.livesLeft}',
                semantics: '${s.livesLeft} lives left',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            StatusPill(
              palette: p,
              icon: Icons.local_fire_department_outlined,
              good: s.multiplier > 1,
              text: s.multiplier >= _rules.multiplierMax
                  ? 'Clean run ×${s.scoreFactor} · max'
                  : 'Clean run ×${s.scoreFactor} · next in $streak',
              semantics:
                  'Clean run multiplier ${s.scoreFactor}. '
                  '${streak == null ? 'At maximum.' : '$streak more completed processes to the next level.'}',
            ),
            if (s.heat > 0)
              StatusPill(
                palette: p,
                icon: Icons.thermostat,
                alert: true,
                text: 'Heat ${s.heat}',
                semantics: explainHeat(s.heat, _rules),
              ),
            if (s.overclocked)
              StatusPill(
                palette: p,
                icon: Icons.speed,
                good: true,
                text: 'Overclock ${s.overclockLeft}',
              ),
            if (_modeLabel.isNotEmpty)
              StatusPill(
                palette: p,
                icon: Icons.flag_outlined,
                text: _modeLabel,
              ),
          ],
        ),
      ],
    );
  }

  Widget _iconButton(
    GameThemePalette p,
    String tooltip,
    IconData icon,
    VoidCallback onPressed,
  ) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, color: p.textPrimary),
  );

  /// What happened last (a fault), or what to do next.
  Widget _notice(GameThemePalette p, MemoryState s) {
    final String text;
    final bool bad;
    if (_game.message != null) {
      text = _game.message!;
      bad = true;
    } else if (_game.faultNotice != null) {
      text = _game.faultNotice!;
      bad = true;
    } else if (_game.toast != null) {
      text = _game.toast!;
      bad = false;
    } else {
      // No standing instructions: the ▸ cells and the buttons say it.
      return const SizedBox.shrink();
    }
    final good = !bad && _game.toast != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: bad
              ? p.danger
              : good
              ? p.ok
              : p.textMuted,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _forecast(GameThemePalette p, MemoryState s) {
    final items = _game.forecast;
    if (items.isEmpty) return const SizedBox.shrink();
    final canReserve =
        s.reservation == null && _game.reserving == null && _game.isPlaying;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _game.reserving == null
                ? 'Arriving · tap to hold space'
                : 'Arriving',
            style: TextStyle(color: p.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items)
                ForecastChip(
                  item: item,
                  palette: p,
                  onReserve: canReserve && item.reservable
                      ? () => _game.beginReserve(item)
                      : null,
                ),
            ],
          ),
          if (_game.reserving != null)
            TextButton(
              onPressed: _game.cancelReserve,
              child: const Text('Cancel reserve'),
            ),
        ],
      ),
    );
  }

  Widget _queue(GameThemePalette p, MemoryState s) {
    final sel = _game.selected;
    final full = s.requestQueue.length >= _rules.maxQueue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waiting ${s.requestQueue.length} of ${_rules.maxQueue}'
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

  List<Widget> _placementPicker(GameThemePalette p, MemoryState s) {
    final sel = _game.selected;
    if (sel == null) return const [];
    final options = _game.placementOptions;
    final suggested = _game.suggestedStart;
    final rejectUsed = _rules.hasWaves && s.lastRejectWave == s.wave.number;
    return [
      Text(
        'Where should #${sel.id} go?',
        style: TextStyle(color: p.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 6),
      if (options.isEmpty)
        Text(
          'No gap is big enough. Wait for space to free up, or compact.',
          style: TextStyle(color: p.danger, fontSize: 13),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              Semantics(
                button: true,
                label:
                    '${o.label} at cell ${o.start}, leaves ${o.largestFreeAfter} '
                    'free in a row',
                excludeSemantics: true,
                child: FilledButton(
                  onPressed: () => _game.placeAt(o.start),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${o.label} · cells ${o.start}–${o.start + sel.size - 1}',
                      ),
                      Text(
                        'biggest gap after: ${o.largestFreeAfter}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      if (suggested != null) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _game.placeSuggested,
          icon: const Icon(Icons.auto_fix_high, size: 18),
          label: Text('Suggested: cell $suggested (no multiplier)'),
        ),
      ],
      const SizedBox(height: 4),
      TextButton(
        onPressed: rejectUsed ? null : () => _game.reject(sel.id),
        child: Text(
          rejectUsed
              ? 'Turn away: used this wave'
              : 'Turn away #${sel.id} (breaks your clean run)',
        ),
      ),
    ];
  }

  /// Leaking processes can be ended early, at a cost.
  List<Widget> _leakCleanup(GameThemePalette p, MemoryState s) {
    final leaks = [
      for (final proc in s.processes)
        if (proc.isNormal && proc.releasePolicy == ReleasePolicy.leak) proc,
    ];
    if (leaks.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      for (final leak in leaks)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: OutlinedButton.icon(
            onPressed: () => _game.cleanup(leak.id),
            icon: const Icon(Icons.cleaning_services_outlined, size: 18),
            label: Text(
              'Clean up leak #${leak.id}: locks ${(leak.size + 1) ~/ 2} '
              'cells for ${_rules.cleanupLockTicks} ticks, '
              '−${_rules.cleanupPointCost} pts',
            ),
          ),
        ),
    ];
  }

  Widget _actions(GameThemePalette p, MemoryState s) {
    final ready = s.cycle >= s.overclockReadyCycle && !s.overclocked;
    final wait = s.overclockReadyCycle - s.cycle;
    const labelStyle = TextStyle(fontSize: 12);
    final buttonStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      minimumSize: const Size(0, 40),
      visualDensity: VisualDensity.compact,
    );
    Widget label(String text) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, style: labelStyle),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: buttonStyle,
              onPressed: ready ? _game.overclock : null,
              icon: const Icon(Icons.speed, size: 16),
              label: label(
                s.overclocked
                    ? 'On'
                    : ready
                    ? 'Overclock'
                    : 'Ready in $wait',
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Tooltip(
              message:
                  'Costs ${_rules.compactionTickCost} ticks and '
                  '${_rules.compactionPointCost} pts; traffic continues.',
              child: OutlinedButton.icon(
                style: buttonStyle,
                onPressed: s.compactionsLeft > 0 ? _game.compact : null,
                icon: const Icon(Icons.compress, size: 16),
                label: label('Compact · ${s.compactionsLeft}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A waiting request. The bar drains as its deadline nears, with a "!"
  /// and the number so urgency never depends on colour.
  Widget _requestChip(GameThemePalette p, Request r, {required bool selected}) {
    final urgent = r.deadline <= 2;
    final tag = familyTag(r);
    return Semantics(
      button: true,
      selected: selected,
      label:
          'Request ${r.id}, ${r.size} cells, ${lifetimeText(r)} ticks, '
          '${r.deadline} ticks left to place'
          '${tag == null ? '' : ', $tag'}',
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
                lifetimeText(r),
                style: TextStyle(color: p.textMuted, fontSize: 11),
              ),
              if (tag != null)
                Text(
                  tag,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (r.deadline / _rules.requestDeadline).clamp(0.0, 1.0),
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
      const Center(child: BrandMark(size: 64)),
      const SizedBox(height: 16),
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
    final scenario = _scenario;
    final won = _game.isCompleted;
    final title = scenario != null
        ? (won ? 'Scenario complete' : 'Scenario failed')
        : widget.mode == RunMode.daily
        ? 'Daily run over'
        : 'Run over';
    TextStyle small() => TextStyle(color: p.textMuted, fontSize: 13);
    return _overlay(
      p,
      children: [
        const Center(child: BrandMark(size: 64)),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: won ? p.ok : p.danger,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (!won && s.failure != null)
          Text(
            'The last fault: ${explainFailure(s.failure!, _rules)}',
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
          'Survived ${s.score.ticksSurvived} ticks · '
          '${s.score.completed} processes finished · '
          '${s.score.wavesCleared} waves cleared',
          textAlign: TextAlign.center,
          style: small(),
        ),
        const SizedBox(height: 4),
        Text(
          'Longest clean run ${s.score.peakStreak}'
          '${s.score.largestRescued > 0 ? ' · biggest rescue ${s.score.largestRescued} cells' : ''}',
          textAlign: TextAlign.center,
          style: small(),
        ),
        if (_records.any) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (_records.streak) 'New best clean run!',
              if (_records.rescued) 'New biggest rescue!',
              if (_records.waves) 'Most waves cleared yet!',
            ].join('  '),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.ok,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (scenario != null) ...[
          const SizedBox(height: 16),
          for (final o in Objective.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Semantics(
                label:
                    '${o.title}: ${scenario.objectivesMet(s).contains(o) ? 'met' : 'not met'}',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Icon(
                      scenario.objectivesMet(s).contains(o)
                          ? Icons.star
                          : Icons.star_border,
                      color: scenario.objectivesMet(s).contains(o)
                          ? p.ok
                          : p.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${o.title}: ${o.description}'
                        '${_freshObjectives.contains(o) ? '  (new!)' : ''}',
                        style: TextStyle(color: p.textPrimary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        if (scenario != null && won && nextScenario(scenario.id) != null) ...[
          FilledButton(
            onPressed: _playNext,
            child: const Text('Next scenario'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _restart, child: const Text('Replay')),
        ] else
          FilledButton(
            onPressed: _restart,
            child: Text(scenario != null ? 'Try again' : 'Play again'),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _leave,
          child: Text(scenario != null ? 'Scenarios' : 'Home'),
        ),
      ],
    );
  }
}
