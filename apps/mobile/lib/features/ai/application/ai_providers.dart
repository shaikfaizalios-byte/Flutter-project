import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/app_log.dart';
import '../data/ai_repository.dart';

final aiRepositoryProvider = Provider<AiRepository>(
  (ref) => RemoteAiRepository(ref.watch(dioProvider)),
);

/// AI availability. Offline or on error, AI actions are simply not offered.
final aiStatusProvider = FutureProvider.autoDispose<AiStatus>((ref) async {
  try {
    return await ref.watch(aiRepositoryProvider).status();
  } on Object catch (error, stack) {
    logError('Loading AI status failed', error, stack);
    return AiStatus.off;
  }
}, retry: (_, _) => null);
