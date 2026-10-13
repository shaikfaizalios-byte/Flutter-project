import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/clock.dart';
import '../data/revision_repository.dart';
import '../domain/revision_card.dart';
import '../domain/revision_schedule.dart';

final revisionRepositoryProvider = Provider<RevisionRepository>(
  (ref) => RevisionRepository(ref.watch(appDatabaseProvider), clock: ref.watch(clockProvider)),
);

Stream<T> _logged<T>(Stream<T> stream, String what) =>
    stream.handleError((Object error, StackTrace stack) {
      logError('Loading $what failed', error, stack);
      Error.throwWithStackTrace(error, stack);
    });

// Local database errors are not transient: show them instead of retrying silently.
Duration? _noRetry(int retryCount, Object error) => null;

/// All cards, soonest due first.
final revisionCardsProvider = StreamProvider.autoDispose<List<RevisionCard>>(
  (ref) => _logged(ref.watch(revisionRepositoryProvider).watchCards(), 'revision cards'),
  retry: _noRetry,
);

final revisionSettingsProvider = StreamProvider.autoDispose<RevisionSettings>(
  (ref) => _logged(ref.watch(revisionRepositoryProvider).watchSettings(), 'revision settings'),
  retry: _noRetry,
);

/// Today's local calendar date (from [clockProvider]).
final todayProvider = Provider.autoDispose<CalendarDate>(
  (ref) => CalendarDate.fromDateTime(ref.watch(clockProvider)()),
);

final revisionOverviewProvider = Provider.autoDispose<AsyncValue<RevisionOverview>>(
  (ref) => ref
      .watch(revisionCardsProvider)
      .whenData((cards) => RevisionOverview.of(cards, ref.watch(todayProvider))),
);

final conceptCardProvider = StreamProvider.autoDispose.family<RevisionCard?, String>(
  (ref, conceptId) => _logged(
    ref.watch(revisionRepositoryProvider).watchConceptCard(conceptId),
    'concept revision card',
  ),
  retry: _noRetry,
);
