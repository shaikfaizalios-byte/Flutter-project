import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_providers.dart';
import '../../ai/data/ai_repository.dart';
import '../../concepts/domain/concept.dart';

/// What a lesson or knowledge check is asked for.
typedef LearnRequest = ({String examCode, TopicChoice choice, ContentLanguage language});

/// A lesson on a topic. Made once per screen visit; nothing is stored.
final topicLessonProvider = FutureProvider.autoDispose.family<TopicLesson, LearnRequest>(
  (ref, request) => ref
      .watch(aiRepositoryProvider)
      .topicLesson(request.choice, examCode: request.examCode, language: request.language),
  retry: (_, _) => null,
);

/// Questions on a topic. Invalidate it for new questions; nothing is stored.
final topicQuizProvider = FutureProvider.autoDispose.family<TopicQuiz, LearnRequest>(
  (ref, request) => ref
      .watch(aiRepositoryProvider)
      .topicQuiz(request.choice, examCode: request.examCode, language: request.language),
  retry: (_, _) => null,
);
