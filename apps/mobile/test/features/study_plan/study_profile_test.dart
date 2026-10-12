import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preploop/core/database/app_database.dart';
import 'package:preploop/core/utils/calendar_date.dart';
import 'package:preploop/core/utils/clock.dart';
import 'package:preploop/features/study_plan/application/study_profile_controller.dart';
import 'package:preploop/features/study_plan/data/study_profile_repository.dart';
import 'package:preploop/features/study_plan/domain/study_profile.dart';

import '../../helpers/pump_app.dart';

void main() {
  test('a fresh install has an empty, not-onboarded profile', () async {
    final profile = await StudyProfileRepository(createTestDatabase()).load();

    expect(profile, const StudyProfile());
    expect(profile.onboardingCompleted, isFalse);
  });

  test('profile round-trips through the database', () async {
    final repo = StudyProfileRepository(createTestDatabase());
    final profile = StudyProfile(
      examCodes: const ['SSC_CGL', 'SSC_CHSL'],
      targetExamDate: CalendarDate(2027, 3, 9),
      dailyStudyMinutes: 90,
      reminderMinutes: 19 * 60 + 30,
      onboardingCompletedAt: DateTime.utc(2026, 10, 12, 4, 30),
    );

    await repo.save(profile);
    await repo.save(profile); // upsert, single row

    expect(await repo.load(), profile);
  });

  test('clearing optional fields persists nulls', () async {
    final repo = StudyProfileRepository(createTestDatabase());
    await repo.save(StudyProfile(targetExamDate: CalendarDate(2027, 1, 1), reminderMinutes: 60));

    await repo.save(const StudyProfile());

    final loaded = await repo.load();
    expect(loaded.targetExamDate, isNull);
    expect(loaded.reminderMinutes, isNull);
  });

  test('rejects out-of-range values instead of storing them', () async {
    final repo = StudyProfileRepository(createTestDatabase());

    expect(() => repo.save(const StudyProfile(dailyStudyMinutes: 0)), throwsArgumentError);
    expect(() => repo.save(const StudyProfile(reminderMinutes: 1440)), throwsArgumentError);
  });

  test('ignores unknown exam codes and corrupt values written elsewhere', () async {
    final db = createTestDatabase();
    await db
        .into(db.studyProfiles)
        .insert(
          StudyProfilesCompanion.insert(
            id: const Value(1),
            examCodes: const Value(['SSC_CGL', 'UPSC_CSE']),
            targetExamDate: const Value('not-a-date'),
            dailyStudyMinutes: const Value(-5),
            updatedAt: DateTime.utc(2026),
          ),
        );

    final profile = await StudyProfileRepository(db).load();

    expect(profile.examCodes, ['SSC_CGL']);
    expect(profile.targetExamDate, isNull);
    expect(profile.dailyStudyMinutes, isNull);
  });

  test('controller persists changes and onboarding completion is idempotent', () async {
    final db = createTestDatabase();
    var now = DateTime.utc(2026, 10, 12, 9);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(studyProfileProvider.notifier);

    await controller.setExamCodes(['SSC_CHSL']);
    await controller.setDailyStudyMinutes(45);
    await controller.completeOnboarding();
    final firstCompletion = container.read(studyProfileProvider).onboardingCompletedAt;
    now = now.add(const Duration(days: 1));
    await controller.completeOnboarding();

    final stored = await StudyProfileRepository(db).load();
    expect(stored.examCodes, ['SSC_CHSL']);
    expect(stored.dailyStudyMinutes, 45);
    expect(stored.onboardingCompletedAt, firstCompletion);
    expect(firstCompletion, DateTime.utc(2026, 10, 12, 9));
  });

  test('daysUntilExam', () {
    final today = CalendarDate(2026, 10, 12);

    expect(daysUntilExam(const StudyProfile(), today), isNull);
    expect(daysUntilExam(StudyProfile(targetExamDate: CalendarDate(2026, 10, 22)), today), 10);
    expect(daysUntilExam(StudyProfile(targetExamDate: CalendarDate(2026, 10, 1)), today), -11);
  });
}
