import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_log.dart';
import '../data/local_concepts_repository.dart';
import '../domain/concept.dart';
import '../domain/concepts_repository.dart';

final conceptsRepositoryProvider = Provider<ConceptsRepository>(
  (ref) => LocalConceptsRepository(ref.watch(appDatabaseProvider)),
);

/// The text currently typed in the concept search box.
class ConceptSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final conceptSearchQueryProvider = NotifierProvider<ConceptSearchQuery, String>(
  ConceptSearchQuery.new,
);

final conceptListProvider = StreamProvider.autoDispose<List<Concept>>(
  (ref) => ref
      .watch(conceptsRepositoryProvider)
      .watch(query: ref.watch(conceptSearchQueryProvider))
      .handleError((Object error, StackTrace stack) {
        logError('Loading concepts failed', error, stack);
        Error.throwWithStackTrace(error, stack);
      }),
  // Local database errors are not transient; show them instead of retrying silently.
  retry: (retryCount, error) => null,
);
