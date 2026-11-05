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
    required this.selectedIndex,
    required this.correct,
    required this.answerIndex,
    required this.solution,
    required this.shortcut,
    this.timeSpentMs,
  });

  factory LadderResult.fromJson(Map<String, dynamic> json) => LadderResult(
    selectedIndex: json['selected_index'] as int,
    correct: json['correct'] as bool,
    answerIndex: json['answer_index'] as int,
    solution: (json['solution'] as List<dynamic>).cast<String>(),
    shortcut: json['shortcut'] as String,
    timeSpentMs: json['time_spent_ms'] as int?,
  );

  final int selectedIndex;
  final bool correct;
  final int answerIndex;
  final List<String> solution;
  final String shortcut;
  final int? timeSpentMs;
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
    this.basisPapers = 0,
    this.basisWeb = false,
    this.paperLabel,
    this.stem,
    this.options = const [],
    this.timeTargetSeconds,
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
    basisPapers: json['basis_papers'] as int,
    basisWeb: json['basis_web'] as bool,
    paperLabel: json['paper_label'] as String?,
    stem: json['stem'] as String?,
    options: (json['options'] as List<dynamic>? ?? const []).cast<String>(),
    timeTargetSeconds: json['time_target_seconds'] as int?,
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
  final int basisPapers;
  final bool basisWeb;
  final String? paperLabel;
  final String? stem;
  final List<String> options;
  final int? timeTargetSeconds;
  final LadderResult? result;

  bool get answered => result != null;
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
  const LadderOverview({this.topics = const [], this.best});

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
    );
  }

  final List<LadderTopic> topics;
  final LadderBest? best;

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
  });

  factory LadderSummary.of(LadderRound round) {
    final byModel = <String, (int, int)>{};
    var correct = 0;
    var milliseconds = 0;
    for (final step in round.steps) {
      final result = step.result;
      if (result == null) continue;
      if (result.correct) correct++;
      milliseconds += result.timeSpentMs ?? 0;
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
    );
  }

  final int correct;
  final int total;
  final Duration timeSpent;

  /// Question type → (right, answered).
  final Map<String, (int, int)> byModel;
}
