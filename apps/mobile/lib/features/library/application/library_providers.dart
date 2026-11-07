import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/clock.dart';
import '../data/library_repository.dart';
import '../domain/library_models.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    ref.watch(dioProvider),
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

Duration? _noRetry(int count, Object error) => null;

final librarySearchProvider = FutureProvider.autoDispose.family<LibraryPage, LibraryQuery>(
  (ref, query) => ref.watch(libraryRepositoryProvider).search(query),
  retry: _noRetry,
);

final libraryPacksProvider = FutureProvider.autoDispose.family<List<LibraryPack>, String>(
  (ref, exam) => ref.watch(libraryRepositoryProvider).packs(exam),
  retry: _noRetry,
);

final savedPacksProvider = FutureProvider.autoDispose.family<Map<String, int>, String>(
  (ref, exam) => ref.watch(libraryRepositoryProvider).savedPacks(exam),
  retry: _noRetry,
);
