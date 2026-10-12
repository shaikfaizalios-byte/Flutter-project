import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_log.dart';
import '../data/local_concepts_repository.dart';
import '../domain/concept.dart';
import '../domain/concepts_repository.dart';

final conceptsRepositoryProvider = Provider<ConceptsRepository>(
  (ref) => LocalConceptsRepository(ref.watch(appDatabaseProvider)),
);

/// Search text and filters for the concept list.
class ConceptQueryController extends Notifier<ConceptQuery> {
  @override
  ConceptQuery build() => const ConceptQuery();

  void setText(String text) => state = state.copyWith(text: text);

  void setExam(String? examCode) => state = state.copyWith(examCode: () => examCode);

  /// Changing the subject clears the topic (topics belong to a subject).
  void setSubject(String? subject) =>
      state = state.copyWith(subject: () => subject, topic: () => null);

  void setTopic(String? topic) => state = state.copyWith(topic: () => topic);

  void setArchived({required bool archived}) => state = state.copyWith(archived: archived);

  /// Clears filters but keeps the search text.
  void clearFilters() => state = ConceptQuery(text: state.text);
}

final conceptQueryProvider = NotifierProvider<ConceptQueryController, ConceptQuery>(
  ConceptQueryController.new,
);

Stream<T> _logged<T>(Stream<T> stream, String what) =>
    stream.handleError((Object error, StackTrace stack) {
      logError('Loading $what failed', error, stack);
      Error.throwWithStackTrace(error, stack);
    });

// Local database errors are not transient: show them instead of retrying silently.
Duration? _noRetry(int retryCount, Object error) => null;

final conceptListProvider = StreamProvider.autoDispose<List<Concept>>(
  (ref) => _logged(
    ref.watch(conceptsRepositoryProvider).watch(ref.watch(conceptQueryProvider)),
    'concepts',
  ),
  retry: _noRetry,
);

final conceptFacetsProvider = StreamProvider.autoDispose<ConceptFacets>(
  (ref) => _logged(ref.watch(conceptsRepositoryProvider).watchFacets(), 'concept filters'),
  retry: _noRetry,
);

final conceptByIdProvider = StreamProvider.autoDispose.family<Concept?, String>(
  (ref, id) => _logged(ref.watch(conceptsRepositoryProvider).watchById(id), 'concept'),
  retry: _noRetry,
);

final activeConceptCountProvider = StreamProvider.autoDispose<int>(
  (ref) => _logged(ref.watch(conceptsRepositoryProvider).watchActiveCount(), 'concept count'),
  retry: _noRetry,
);
