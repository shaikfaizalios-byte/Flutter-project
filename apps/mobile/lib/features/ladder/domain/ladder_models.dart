import 'package:flutter/foundation.dart';

enum LadderDifficulty { easy, medium, mediumHard, hard, extremeHard }

LadderDifficulty _difficulty(String code) => switch (code) {
  'easy' => LadderDifficulty.easy,
  'medium' => LadderDifficulty.medium,
  'medium_hard' => LadderDifficulty.mediumHard,
  'hard' => LadderDifficulty.hard,
  _ => LadderDifficulty.extremeHard,
};

/// What the questions of a ladder are based on.
enum LadderSourceMix { papers, webMain, webOnly }

/// What the learner sees once they have answered a step.
@immutable
class LadderResult {
  const LadderResult({
    required this.correct,
    required this.solution,
    required this.shortcut,
    this.selectedIndex,
    this.answerIndex,
    this.timeSpentMs,
    this.response,
    this.answerLines = const [],
    this.partlyRight = false,
    this.marks,
    this.marksPossible,
  });

  factory LadderResult.fromJson(Map<String, dynamic> json) => LadderResult(
    selectedIndex: json['selected_index'] as int?,
    correct: json['correct'] as bool,
    answerIndex: json['answer_index'] as int?,
    solution: (json['solution'] as List<dynamic>).cast<String>(),
    shortcut: json['shortcut'] as String,
    timeSpentMs: json['time_spent_ms'] as int?,
    response: json['response'] as Map<String, dynamic>?,
    answerLines: (json['answer_lines'] as List<dynamic>? ?? const []).cast<String>(),
    partlyRight: json['partly_right'] as bool? ?? false,
    marks: (json['marks'] as num?)?.toDouble(),
    marksPossible: (json['marks_possible'] as num?)?.toDouble(),
  );

  final int? selectedIndex;
  final bool correct;
  final int? answerIndex;
  final List<String> solution;
  final String shortcut;
  final int? timeSpentMs;
  final Map<String, dynamic>? response;

  /// The right answer in words, when no single option shows it.
  final List<String> answerLines;

  /// Not correct, but earned marks under the exam's rule.
  final bool partlyRight;

  /// Null: the exam states no marks for this subject.
  final double? marks;
  final double? marksPossible;
}

/// One step of a round: planned, then [ready] with a checked question, then answered.
@immutable
class LadderStep {
  const LadderStep({
    required this.roundNumber,
    required this.step,
    required this.difficulty,
    required this.ready,
    this.modelName,
    this.secondModelName,
    this.fromPaper = false,
    this.fromLibrary = false,
    this.solves,
    this.recalculated = false,
    this.basisPapers = 0,
    this.basisWeb = false,
    this.paperLabel,
    this.stem,
    this.options = const [],
    this.timeTargetSeconds,
    this.format = 'single_correct',
    this.formatData,
    this.result,
  });

  factory LadderStep.fromJson(Map<String, dynamic> json) => LadderStep(
    roundNumber: json['round_number'] as int,
    step: json['step'] as int,
    difficulty: _difficulty(json['difficulty'] as String),
    ready: json['ready'] as bool,
    modelName: json['model_name'] as String?,
    secondModelName: json['second_model_name'] as String?,
    fromPaper: json['source'] == 'paper',
    fromLibrary: json['source'] == 'library',
    solves: (json['checks'] as Map<String, dynamic>?)?['solves'] as int?,
    recalculated: (json['checks'] as Map<String, dynamic>?)?['recalculated'] == true,
    basisPapers: json['basis_papers'] as int,
    basisWeb: json['basis_web'] as bool,
    paperLabel: json['paper_label'] as String?,
    stem: json['stem'] as String?,
    options: (json['options'] as List<dynamic>? ?? const []).cast<String>(),
    timeTargetSeconds: json['time_target_seconds'] as int?,
    format: json['format'] as String? ?? 'single_correct',
    formatData: (json['format_data'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(key, (value as List<dynamic>).cast<String>()),
    ),
    result: json['result'] == null
        ? null
        : LadderResult.fromJson(json['result'] as Map<String, dynamic>),
  );

  final int roundNumber;
  final int step;
  final LadderDifficulty difficulty;
  final bool ready;
  final String? modelName;
  final String? secondModelName;

  /// A real question from the learner's paper, not written by AI.
  final bool fromPaper;

  /// A reviewed library question took the step, because a generated one couldn't be checked.
  final bool fromLibrary;

  /// How a generated question was checked: solves that agreed, and a recalculated answer.
  final int? solves;
  final bool recalculated;
  final int basisPapers;
  final bool basisWeb;
  final String? paperLabel;
  final String? stem;
  final List<String> options;
  final int? timeTargetSeconds;

  /// How it is answered; see the server's question formats.
  final String format;

  /// A match question's lists.
  final Map<String, List<String>>? formatData;
  final LadderResult? result;

  bool get answered => result != null;

  /// Answered with a number instead of an option.
  bool get typed => format == 'numeric' || format == 'integer';

  /// Answered by more than one tap.
  bool get takesResponse => format == 'multiple_correct' || format == 'match';
}

@immutable
class LadderRound {
  const LadderRound({
    required this.sessionId,
    required this.roundNumber,
    required this.topicName,
    required this.subject,
    required this.sourceMix,
    required this.steps,
  });

  factory LadderRound.fromJson(Map<String, dynamic> json) => LadderRound(
    sessionId: json['session_id'] as String,
    roundNumber: json['round_number'] as int,
    topicName: json['topic_name'] as String,
    subject: json['subject'] as String,
    sourceMix: switch (json['source_mix']) {
      'web_only' => LadderSourceMix.webOnly,
      'web_main' => LadderSourceMix.webMain,
      _ => LadderSourceMix.papers,
    },
    steps: [
      for (final s in json['steps'] as List<dynamic>)
        LadderStep.fromJson(s as Map<String, dynamic>),
    ],
  );

  final String sessionId;
  final int roundNumber;
  final String topicName;
  final String subject;
  final LadderSourceMix sourceMix;
  final List<LadderStep> steps;

  LadderRound withStep(LadderStep updated) => LadderRound(
    sessionId: sessionId,
    roundNumber: roundNumber,
    topicName: topicName,
    subject: subject,
    sourceMix: sourceMix,
    steps: [for (final s in steps) s.step == updated.step ? updated : s],
  );

  bool get allReady => steps.every((s) => s.ready);
}

@immutable
class LadderTopic {
  const LadderTopic({
    required this.topicId,
    required this.name,
    required this.subject,
    this.papers = 0,
  });

  factory LadderTopic.fromJson(Map<String, dynamic> json) => LadderTopic(
    topicId: json['topic_id'] as String,
    name: json['name'] as String,
    subject: json['subject'] as String,
    papers: json['papers'] as int,
  );

  final String topicId;
  final String name;
  final String subject;

  /// Reviewed papers it appeared in.
  final int papers;
}

@immutable
class LadderBest {
  const LadderBest({required this.step, required this.topicName});

  final int step;
  final String topicName;
}

/// Topics of the exam, most repeated first, and the learner's own best climb.
@immutable
class LadderOverview {
  const LadderOverview({
    this.topics = const [],
    this.best,
    this.available = true,
    this.freePerDay = 0,
    this.freeLeftToday,
  });

  factory LadderOverview.fromJson(Map<String, dynamic> json) {
    final best = json['best'] as Map<String, dynamic>?;
    return LadderOverview(
      topics: [
        for (final t in json['topics'] as List<dynamic>)
          LadderTopic.fromJson(t as Map<String, dynamic>),
      ],
      best: best == null
          ? null
          : LadderBest(step: best['step'] as int, topicName: best['topic_name'] as String),
      available: json['available'] as bool? ?? true,
      freePerDay: json['free_per_day'] as int? ?? 0,
      freeLeftToday: json['free_left_today'] as int?,
    );
  }

  final List<LadderTopic> topics;
  final LadderBest? best;

  /// False for an exam with no multiple-choice paper.
  final bool available;

  /// Ladders a day a learner without Plus may start (one round each; the server's day is UTC).
  final int freePerDay;

  /// Free ladders left today; null when the account needs none (Plus is on).
  final int? freeLeftToday;

  /// Up to 3 topics seen in the learner's papers, for a one-tap start.
  List<LadderTopic> get repeated => topics.where((t) => t.papers > 0).take(3).toList();
}

/// A round's results: score, time and accuracy per question type.
@immutable
class LadderSummary {
  const LadderSummary({
    required this.correct,
    required this.total,
    required this.timeSpent,
    required this.byModel,
    this.marks,
    this.marksPossible,
  });

  factory LadderSummary.of(LadderRound round) {
    final byModel = <String, (int, int)>{};
    var correct = 0;
    var milliseconds = 0;
    double? marks;
    double? possible;
    for (final step in round.steps) {
      final result = step.result;
      if (result == null) continue;
      if (result.correct) correct++;
      milliseconds += result.timeSpentMs ?? 0;
      if (result.marks != null && result.marksPossible != null) {
        marks = (marks ?? 0) + result.marks!;
        possible = (possible ?? 0) + result.marksPossible!;
      }
      final name = step.modelName;
      if (name != null) {
        final (right, all) = byModel[name] ?? (0, 0);
        byModel[name] = (right + (result.correct ? 1 : 0), all + 1);
      }
    }
    return LadderSummary(
      correct: correct,
      total: round.steps.length,
      timeSpent: Duration(milliseconds: milliseconds),
      byModel: byModel,
      marks: marks,
      marksPossible: possible,
    );
  }

  final int correct;
  final int total;
  final Duration timeSpent;

  /// Question type → (right, answered).
  final Map<String, (int, int)> byModel;

  /// Null when the exam states no marks.
  final double? marks;
  final double? marksPossible;
}
