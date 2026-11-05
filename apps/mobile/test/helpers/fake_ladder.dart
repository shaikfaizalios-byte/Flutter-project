import 'package:preploop/core/errors/app_failure.dart';
import 'package:preploop/core/localization/content_language.dart';
import 'package:preploop/features/ladder/data/ladder_repository.dart';
import 'package:preploop/features/ladder/domain/ladder_models.dart';

const firstRound = [
  LadderDifficulty.easy,
  LadderDifficulty.easy,
  LadderDifficulty.medium,
  LadderDifficulty.hard,
  LadderDifficulty.extremeHard,
];
const laterRound = [
  LadderDifficulty.mediumHard,
  LadderDifficulty.mediumHard,
  LadderDifficulty.hard,
  LadderDifficulty.hard,
  LadderDifficulty.hard,
];

/// Stand-in for the ladder API. Every question's right option is the second one.
class FakeLadderRepository implements LadderRepository {
  FakeLadderRepository({this.data = const LadderOverview()});

  LadderOverview data;

  /// Thrown by the next start or generate (then cleared).
  AppFailure? failure;

  /// Answers to mark a step as a real paper question.
  int? paperStep;
  final calls = <String>[];
  final _rounds = <int, LadderRound>{};

  LadderRound _plan(int number) => LadderRound(
    sessionId: 's1',
    roundNumber: number,
    topicName: 'Percentage',
    subject: 'Quantitative Aptitude',
    sourceMix: LadderSourceMix.papers,
    steps: [
      for (final (i, d) in (number == 1 ? firstRound : laterRound).indexed)
        LadderStep(
          roundNumber: number,
          step: i + 1,
          difficulty: d,
          ready: false,
          modelName: i.isEven ? 'Income' : 'Discount',
        ),
    ],
  );

  void _maybeFail() {
    final next = failure;
    failure = null;
    if (next != null) throw next;
  }

  @override
  Future<LadderOverview> overview(String examCode) async {
    calls.add('overview:$examCode');
    return data;
  }

  @override
  Future<LadderRound> start({
    required String examCode,
    required String topicId,
    required ContentLanguage language,
  }) async {
    calls.add('start:$examCode:$topicId:${language.code}');
    _maybeFail();
    return _rounds[1] = _plan(1);
  }

  @override
  Future<LadderRound> nextRound(String sessionId) async {
    calls.add('more');
    final number = _rounds.length + 1;
    return _rounds[number] = _plan(number);
  }

  @override
  Future<LadderStep> generate(String sessionId, int round, int step) async {
    calls.add('generate:$round:$step');
    _maybeFail();
    final planned = _rounds[round]!.steps[step - 1];
    final paper = paperStep == step;
    final written = LadderStep(
      roundNumber: round,
      step: step,
      difficulty: planned.difficulty,
      ready: true,
      modelName: planned.modelName,
      fromPaper: paper,
      basisPapers: paper ? 1 : 4,
      basisWeb: step == 2,
      paperLabel: paper ? 'chsl.pdf 2023' : null,
      stem: 'Question $round-$step?',
      options: const ['10', '20', '30', '40'],
      timeTargetSeconds: paper ? null : 60,
    );
    _rounds[round] = _rounds[round]!.withStep(written);
    return written;
  }

  @override
  Future<LadderStep> answer(
    String sessionId,
    int round,
    int step, {
    required int selectedIndex,
    int? timeSpentMs,
  }) async {
    calls.add('answer:$round:$step:$selectedIndex');
    final planned = _rounds[round]!.steps[step - 1];
    return LadderStep(
      roundNumber: round,
      step: step,
      difficulty: planned.difficulty,
      ready: true,
      modelName: planned.modelName,
      basisPapers: planned.basisPapers,
      stem: planned.stem,
      options: planned.options,
      result: LadderResult(
        selectedIndex: selectedIndex,
        correct: selectedIndex == 1,
        answerIndex: 1,
        solution: const ['20 is the answer.'],
        shortcut: 'Half of 40.',
        timeSpentMs: timeSpentMs,
      ),
    );
  }
}
