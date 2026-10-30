import 'package:flutter/scheduler.dart';

/// Completes once no animation is running (pages have finished opening or closing), or after
/// [max] at the latest, so a spinner that never stops can't hold it up.
///
/// Screens hidden under a page pause their providers and catch up when they come back into
/// view, during a build. Changing what they depend on (e.g. the exam) before that happens makes
/// Riverpod schedule a refresh mid-build, which it refuses; waiting for the animations avoids it.
Future<void> untilAnimationsSettle({Duration max = const Duration(milliseconds: 600)}) async {
  final binding = SchedulerBinding.instance;
  final stopwatch = Stopwatch()..start();
  await binding.endOfFrame;
  while (binding.transientCallbackCount > 0 && stopwatch.elapsed < max) {
    await binding.endOfFrame;
  }
}
