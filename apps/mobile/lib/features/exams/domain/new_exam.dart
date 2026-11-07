import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_date.dart';

/// A section of a stage, as the learner enters it from their exam's notice.
@immutable
class NewSection {
  const NewSection({
    required this.name,
    required this.questionCount,
    this.durationMinutes,
    this.cutoff,
  });

  final String name;
  final int questionCount;
  final int? durationMinutes;
  final double? cutoff;

  Map<String, Object?> toJson() => {
    'name': name,
    'question_count': questionCount,
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
    if (cutoff != null) 'cutoff': cutoff,
  };
}

/// A stage of the learner's own exam. Never shown as official.
@immutable
class NewStage {
  const NewStage({
    required this.name,
    required this.durationMinutes,
    required this.sections,
    required this.marksCorrect,
    required this.marksWrong,
  });

  final String name;
  final int durationMinutes;
  final List<NewSection> sections;
  final double marksCorrect;
  final double marksWrong;

  Map<String, Object?> toJson() => {
    'name': name,
    'duration_minutes': durationMinutes,
    'sections': [for (final s in sections) s.toJson()],
    'marking_scheme': {'marks_correct': marksCorrect, 'marks_wrong': marksWrong},
  };
}

/// What the custom exam builder sends. Only [name] is needed; the server's defaults cover
/// anything left out. A null [optionsPerQuestion] means it differs from paper to paper.
@immutable
class NewExam {
  const NewExam({
    required this.name,
    required this.kind,
    required this.optionsPerQuestion,
    this.conductingBody,
    this.languages = const [],
    this.examDates = const [],
    this.stages = const [],
  });

  final String name;
  final String kind;
  final int? optionsPerQuestion;
  final String? conductingBody;
  final List<String> languages;
  final List<CalendarDate> examDates;
  final List<NewStage> stages;

  Map<String, Object?> toJson() => {
    'name': name,
    'kind': kind,
    'options_per_question': optionsPerQuestion,
    if (conductingBody != null) 'conducting_body': conductingBody,
    if (languages.isNotEmpty) 'languages': languages,
    if (examDates.isNotEmpty) 'exam_dates': [for (final d in examDates) d.toIsoString()],
    if (stages.isNotEmpty) 'stages': [for (final s in stages) s.toJson()],
  };
}
