import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/clock.dart';
import '../data/study_profile_repository.dart';
import '../domain/study_profile.dart';

final studyProfileRepositoryProvider = Provider<StudyProfileRepository>(
  (ref) => StudyProfileRepository(ref.watch(appDatabaseProvider), clock: ref.watch(clockProvider)),
);

/// Profile loaded before the first frame (decides whether onboarding shows).
/// Overridden in `bootstrap()`.
final initialStudyProfileProvider = Provider<StudyProfile>((ref) => const StudyProfile());

class StudyProfileController extends Notifier<StudyProfile> {
  @override
  StudyProfile build() => ref.watch(initialStudyProfileProvider);

  Future<void> setExamCodes(List<String> codes) => _update(state.copyWith(examCodes: codes));

  Future<void> setTargetExamDate(CalendarDate? date) =>
      _update(state.copyWith(targetExamDate: () => date));

  Future<void> setDailyStudyMinutes(int? minutes) =>
      _update(state.copyWith(dailyStudyMinutes: () => minutes));

  Future<void> setReminderMinutes(int? minutes) =>
      _update(state.copyWith(reminderMinutes: () => minutes));

  /// Marks onboarding as done (also used by "Skip"). Idempotent.
  Future<void> completeOnboarding() async {
    if (state.onboardingCompleted) return;
    final now = ref.read(clockProvider)();
    await _update(state.copyWith(onboardingCompletedAt: () => now.toUtc()));
  }

  /// Re-reads the profile from the device database (after sync or an account change).
  Future<void> reload() async {
    try {
      state = await ref.read(studyProfileRepositoryProvider).load();
    } on Object catch (error, stack) {
      logError('Reloading study profile failed', error, stack);
    }
  }

  Future<void> _update(StudyProfile next) async {
    // Apply immediately; a storage failure must not block the learner.
    state = next;
    try {
      await ref.read(studyProfileRepositoryProvider).save(next);
    } on Object catch (error, stack) {
      logError('Saving study profile failed', error, stack);
    }
  }
}

final studyProfileProvider = NotifierProvider<StudyProfileController, StudyProfile>(
  StudyProfileController.new,
);
