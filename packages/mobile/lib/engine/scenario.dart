import 'bots.dart';
import 'model.dart';
import 'ruleset.dart';

/// Bump when the scenario data shape changes.
const scenarioSchemaVersion = 1;

/// What a scenario can be mastered on. The first is needed to clear it;
/// the others are optional and earn stars.
enum Objective {
  /// Survive to the goal.
  survive('Survive', 'Last until the clock runs out.'),

  /// Survive without free memory ever splintering past the warning level.
  tidy('Tidy', 'Never let free memory splinter into small pieces.'),

  /// Survive without compacting and without a single fault.
  clean('Clean', 'No faults and no compaction.');

  const Objective(this.title, this.description);
  final String title;
  final String description;
}

/// The four mechanic chapters.
const chapterTitles = <int, String>{
  1: 'Contiguous cells',
  2: 'Lifetimes',
  3: 'Compaction',
  4: 'Pressure',
};

/// One authored challenge: a fixed seed and ruleset teaching a single idea.
class Scenario {
  const Scenario({
    required this.id,
    required this.chapter,
    required this.number,
    required this.title,
    required this.lesson,
    required this.rules,
    required this.seed,
  });

  /// Stable, never reused: "c1-01".
  final String id;
  final int chapter;

  /// 1-based position within the chapter.
  final int number;
  final String title;

  /// The one thing it teaches.
  final String lesson;
  final Ruleset rules;
  final int seed;

  int get goalTicks => rules.goalTicks;

  /// Which objectives a finished run met.
  Set<Objective> objectivesMet(MemoryState end) {
    if (end.status != RunStatus.completed) return const {};
    return {
      Objective.survive,
      if (end.score.fragmentationWarnings == 0) Objective.tidy,
      if (end.score.compactions == 0 && end.faultCount == 0) Objective.clean,
    };
  }
}

Ruleset _quiet({
  required int cells,
  required int goal,
  int queue = 4,
  int deadline = 6,
  int arrival = 500,
  int minSize = 1,
  int maxSize = 3,
  int minLife = 3,
  int maxLife = 7,
  int lives = 3,
  int compactions = 0,
  Set<RequestFamily> families = const {},
  int familyPerMille = 0,
  int wavePeriod = 0,
  int storm = 800,
}) => Ruleset(
  cellCount: cells,
  goalTicks: goal,
  maxQueue: queue,
  requestDeadline: deadline,
  arrivalPerMille: arrival,
  arrivalRampPerMille: 0,
  arrivalMaxPerMille: arrival,
  minSize: minSize,
  maxSize: maxSize,
  minLifetime: minLife,
  maxLifetime: maxLife,
  lives: lives,
  compactionCharges: compactions,
  families: families,
  familyPerMille: families.isEmpty
      ? 0
      : (familyPerMille == 0 ? 400 : familyPerMille),
  progressiveFamilies: false,
  wavePeriod: wavePeriod,
  stormPerMille: storm,
  stormRampPerMille: 0,
);

Scenario _s(
  int chapter,
  int number,
  String title,
  String lesson,
  Ruleset rules,
) => Scenario(
  id: 'c$chapter-${number.toString().padLeft(2, '0')}',
  chapter: chapter,
  number: number,
  title: title,
  lesson: lesson,
  rules: rules,
  seed: _seeds[chapter * 10 + number] ?? 7000 + chapter * 100 + number,
);

/// Authored seeds, chosen so a careful scripted player clears each one
/// (the solvability rule). Regenerate with tool/pick_scenario_seeds.dart.
const _seeds = <int, int>{
  11: 7101,
  12: 7102,
  13: 7103,
  14: 7104,
  15: 7105,
  16: 7106,
  17: 7107,
  18: 7109,
  19: 7109,
  21: 7201,
  22: 7203,
  23: 7204,
  24: 7204,
  25: 7205,
  26: 7206,
  27: 7207,
  28: 7208,
  29: 7209,
  31: 7302,
  32: 7302,
  33: 7304,
  34: 7304,
  35: 7305,
  36: 7306,
  37: 7307,
  38: 7308,
  39: 7309,
  41: 7401,
  42: 7402,
  43: 7403,
  44: 7404,
  45: 7407,
  46: 7406,
  47: 7407,
  48: 7408,
  49: 7409,
};

/// The 36 authored scenarios, four chapters of nine.
final List<Scenario> scenarios = List.unmodifiable([
  // Chapter 1: a request needs cells in a row.
  _s(
    1,
    1,
    'First steps',
    'A request needs free cells side by side.',
    _quiet(cells: 12, goal: 30, arrival: 400, maxSize: 3),
  ),
  _s(
    1,
    2,
    'Wider requests',
    'Bigger requests need bigger gaps.',
    _quiet(cells: 12, goal: 30, arrival: 500, minSize: 2, maxSize: 4),
  ),
  _s(
    1,
    3,
    'Short queue',
    'Only three can wait. Place the urgent ones first.',
    _quiet(cells: 12, goal: 35, queue: 3, arrival: 850),
  ),
  _s(
    1,
    4,
    'Tight deadlines',
    'Requests give up quickly. Decide fast.',
    _quiet(cells: 12, goal: 35, deadline: 4, arrival: 900),
  ),
  _s(
    1,
    5,
    'Rush',
    'More traffic: keep the queue moving.',
    _quiet(cells: 12, goal: 40, arrival: 900),
  ),
  _s(
    1,
    6,
    'Small memory',
    'Every cell counts in a small strip.',
    _quiet(cells: 10, goal: 40, arrival: 800, maxSize: 3),
  ),
  _s(
    1,
    7,
    'Long lives',
    'Long-lived processes hold their cells for ages.',
    _quiet(cells: 16, goal: 40, arrival: 850, minLife: 6, maxLife: 10),
  ),
  _s(
    1,
    8,
    'Busy hour',
    'Sustained pressure rewards tidy habits.',
    _quiet(cells: 14, goal: 45, arrival: 850, maxSize: 4),
  ),
  _s(
    1,
    9,
    'Chapter test',
    'Everything so far, together.',
    _quiet(cells: 12, goal: 60, arrival: 650, maxSize: 4, queue: 3),
  ),

  // Chapter 2: short and long lives belong in different places.
  _s(
    2,
    1,
    'Burst and resident',
    'Large short-lived and small long-lived mix.',
    _quiet(
      cells: 14,
      goal: 40,
      families: {RequestFamily.burst, RequestFamily.resident},
      familyPerMille: 600,
      arrival: 850,
      maxSize: 4,
    ),
  ),
  _s(
    2,
    2,
    'Park the long ones',
    'Keep long-lived processes together at one end.',
    _quiet(
      cells: 14,
      goal: 45,
      families: {RequestFamily.resident},
      familyPerMille: 600,
      arrival: 950,
      minLife: 3,
      maxLife: 8,
    ),
  ),
  _s(
    2,
    3,
    'Burst traffic',
    'Big, brief requests free large blocks fast.',
    _quiet(
      cells: 14,
      goal: 45,
      families: {RequestFamily.burst},
      familyPerMille: 600,
      arrival: 700,
      maxSize: 5,
    ),
  ),
  _s(
    2,
    4,
    'Priority',
    'Priority requests pay double but will not wait.',
    _quiet(
      cells: 14,
      goal: 45,
      families: {RequestFamily.priority},
      familyPerMille: 500,
      arrival: 1000,
    ),
  ),
  _s(
    2,
    5,
    'Fuzzy lifetimes',
    'Volatile processes only show a range of lives.',
    _quiet(
      cells: 14,
      goal: 45,
      families: {RequestFamily.volatile},
      familyPerMille: 600,
      arrival: 800,
      maxSize: 4,
    ),
  ),
  _s(
    2,
    6,
    'Neighbours',
    'Linked requests must sit side by side.',
    _quiet(
      cells: 14,
      goal: 45,
      families: {RequestFamily.linked},
      familyPerMille: 350,
      arrival: 700,
      maxSize: 4,
    ),
  ),
  _s(
    2,
    7,
    'Mixed lives',
    'Burst, resident and priority together.',
    _quiet(
      cells: 14,
      goal: 50,
      families: {
        RequestFamily.burst,
        RequestFamily.resident,
        RequestFamily.priority,
      },
      familyPerMille: 600,
      arrival: 800,
      maxSize: 4,
    ),
  ),
  _s(
    2,
    8,
    'Dense packing',
    'Little spare room: pack by lifetime.',
    _quiet(
      cells: 12,
      goal: 50,
      families: {RequestFamily.burst, RequestFamily.resident},
      familyPerMille: 600,
      arrival: 700,
      maxSize: 4,
    ),
  ),
  _s(
    2,
    9,
    'Chapter test',
    'Every family, no safety net.',
    _quiet(
      cells: 14,
      goal: 60,
      families: {
        RequestFamily.burst,
        RequestFamily.resident,
        RequestFamily.priority,
        RequestFamily.volatile,
        RequestFamily.linked,
      },
      familyPerMille: 500,
      arrival: 800,
      maxSize: 4,
    ),
  ),

  // Chapter 3: compaction is a costly emergency button.
  _s(
    3,
    1,
    'One compaction',
    'Close the gaps once, at the right moment.',
    _quiet(cells: 12, goal: 40, arrival: 700, maxSize: 4, compactions: 1),
  ),
  _s(
    3,
    2,
    'When it pays',
    'Compacting costs ticks while requests keep arriving.',
    _quiet(cells: 12, goal: 40, arrival: 700, maxSize: 4, compactions: 2),
  ),
  _s(
    3,
    3,
    'Pinned in place',
    'Pinned processes do not move when you compact.',
    _quiet(
      cells: 14,
      goal: 45,
      arrival: 900,
      maxSize: 4,
      compactions: 2,
      families: {RequestFamily.pinned},
      familyPerMille: 300,
    ),
  ),
  _s(
    3,
    4,
    'Too late',
    'A compaction at the last second may not save you.',
    _quiet(
      cells: 12,
      goal: 45,
      arrival: 700,
      maxSize: 4,
      compactions: 2,
      deadline: 5,
    ),
  ),
  _s(
    3,
    5,
    'Save your charge',
    'One compaction, many chances to waste it.',
    _quiet(cells: 14, goal: 50, arrival: 800, maxSize: 4, compactions: 1),
  ),
  _s(
    3,
    6,
    'Leaks',
    'Leaking processes never end. Clean them up.',
    _quiet(
      cells: 14,
      goal: 45,
      arrival: 700,
      compactions: 1,
      families: {RequestFamily.leak},
      familyPerMille: 150,
    ),
  ),
  _s(
    3,
    7,
    'Pins and leaks',
    'Immovable blocks cap what compaction can do.',
    _quiet(
      cells: 16,
      goal: 50,
      arrival: 700,
      compactions: 2,
      families: {RequestFamily.leak, RequestFamily.pinned},
      familyPerMille: 250,
    ),
  ),
  _s(
    3,
    8,
    'Tight and urgent',
    'Compaction under deadline pressure.',
    _quiet(
      cells: 12,
      goal: 50,
      arrival: 650,
      deadline: 5,
      compactions: 2,
      maxSize: 4,
    ),
  ),
  _s(
    3,
    9,
    'Chapter test',
    'Pinned, leaking and crowded.',
    _quiet(
      cells: 16,
      goal: 60,
      arrival: 900,
      compactions: 2,
      maxSize: 4,
      families: {RequestFamily.leak, RequestFamily.pinned, RequestFamily.burst},
      familyPerMille: 300,
    ),
  ),

  // Chapter 4: waves of pressure.
  _s(
    4,
    1,
    'First wave',
    'Calm, then a storm, then relief.',
    _quiet(
      cells: 14,
      goal: 40,
      arrival: 600,
      wavePeriod: 20,
      storm: 700,
      compactions: 1,
      maxSize: 5,
      minLife: 4,
      maxLife: 9,
    ),
  ),
  _s(
    4,
    2,
    'Prepare',
    'Use the warning to clear room.',
    _quiet(
      cells: 14,
      goal: 50,
      arrival: 500,
      wavePeriod: 25,
      storm: 800,
      compactions: 1,
      maxSize: 5,
      minLife: 4,
      maxLife: 9,
    ),
  ),
  _s(
    4,
    3,
    'Priority storm',
    'Priority requests arrive in the storm.',
    _quiet(
      cells: 14,
      goal: 50,
      arrival: 450,
      wavePeriod: 25,
      storm: 750,
      compactions: 1,
      families: {RequestFamily.priority},
      familyPerMille: 400,
      maxSize: 5,
      minLife: 4,
      maxLife: 9,
    ),
  ),
  _s(
    4,
    4,
    'Cooling',
    'A fault heats the system. Clear a wave to cool it.',
    _quiet(
      cells: 14,
      goal: 60,
      arrival: 450,
      wavePeriod: 25,
      storm: 750,
      compactions: 1,
      maxSize: 5,
      minLife: 4,
      maxLife: 9,
    ),
  ),
  _s(
    4,
    5,
    'Burst storm',
    'Storms of large requests.',
    _quiet(
      cells: 16,
      goal: 60,
      arrival: 600,
      wavePeriod: 25,
      storm: 800,
      compactions: 1,
      families: {RequestFamily.burst},
      familyPerMille: 500,
      maxSize: 5,
      minLife: 4,
      maxLife: 9,
    ),
  ),
  _s(
    4,
    6,
    'Linked surge',
    'Pairs must stay together under pressure.',
    _quiet(
      cells: 16,
      goal: 60,
      arrival: 450,
      wavePeriod: 25,
      storm: 700,
      compactions: 1,
      families: {RequestFamily.linked},
      familyPerMille: 300,
      maxSize: 5,
      minLife: 4,
      maxLife: 9,
    ),
  ),
  _s(
    4,
    7,
    'Leaky storm',
    'Clean leaks before the next wave.',
    _quiet(
      cells: 16,
      goal: 60,
      arrival: 700,
      wavePeriod: 25,
      storm: 700,
      compactions: 2,
      families: {RequestFamily.leak, RequestFamily.resident},
      familyPerMille: 300,
      maxSize: 5,
      minLife: 4,
      maxLife: 9,
    ),
  ),
  _s(
    4,
    8,
    'Everything',
    'All families, all storms.',
    _quiet(
      cells: 16,
      goal: 75,
      arrival: 600,
      wavePeriod: 25,
      storm: 800,
      compactions: 2,
      families: {
        RequestFamily.burst,
        RequestFamily.resident,
        RequestFamily.priority,
        RequestFamily.volatile,
        RequestFamily.linked,
        RequestFamily.leak,
      },
      familyPerMille: 350,
      maxSize: 5,
      minLife: 4,
      maxLife: 9,
    ),
  ),
  _s(
    4,
    9,
    'Final exam',
    'Three waves with nowhere to hide.',
    _quiet(
      cells: 16,
      goal: 78,
      arrival: 500,
      wavePeriod: 25,
      storm: 850,
      compactions: 2,
      families: {
        RequestFamily.burst,
        RequestFamily.resident,
        RequestFamily.priority,
        RequestFamily.volatile,
        RequestFamily.linked,
        RequestFamily.leak,
        RequestFamily.pinned,
      },
      familyPerMille: 350,
      maxSize: 5,
      minLife: 4,
      maxLife: 9,
    ),
  ),
]);

Scenario? scenarioById(String id) {
  for (final s in scenarios) {
    if (s.id == id) return s;
  }
  return null;
}

/// The scenario after [id] in play order, if any.
Scenario? nextScenario(String id) {
  final i = scenarios.indexWhere((s) => s.id == id);
  return i < 0 || i + 1 >= scenarios.length ? null : scenarios[i + 1];
}

/// Problems that stop a scenario shipping; empty when it is valid. Mirrors
/// the CI schema check (MAS-TR-005).
List<String> validateScenario(Scenario s) {
  final r = s.rules;
  return [
    if (!RegExp(r'^c[1-4]-\d\d$').hasMatch(s.id)) 'bad id ${s.id}',
    if (s.chapter < 1 || s.chapter > 4) '${s.id}: chapter out of range',
    if (s.number < 1 || s.number > 9) '${s.id}: number out of range',
    if (s.title.isEmpty || s.lesson.isEmpty) '${s.id}: missing text',
    if (r.goalTicks <= 0) '${s.id}: no goal',
    if (r.maxSize > r.cellCount) '${s.id}: request larger than memory',
    if (r.minSize > r.maxSize) '${s.id}: bad size range',
    if (r.maxQueue < 2) '${s.id}: queue too short',
  ];
}

/// Whether some scripted policy clears [s] (the declared solvability rule:
/// the survive objective must be reachable).
bool isSolvable(Scenario s) {
  for (final bot in allBots) {
    final end = playBot(s.rules, bot, s.seed, cap: s.goalTicks + 5);
    if (end.status == RunStatus.completed) return true;
  }
  return false;
}
